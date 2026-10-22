"""Offline regression tests for the standalone deployment CLI."""
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
from datetime import datetime, timedelta, timezone
from email.utils import format_datetime
from http.client import IncompleteRead
from types import SimpleNamespace
import unittest
from unittest.mock import mock_open, patch
from urllib.error import HTTPError


spec = importlib.util.spec_from_file_location("foundry_agent", Path(__file__).with_name("foundry-agent.py"))
agent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agent)


class FoundryAgentTests(unittest.TestCase):
    def setUp(self):
        self.image = "test.azurecr.io/agent@sha256:" + "a" * 64
        env = {"FOUNDRY_PROJECT_ENDPOINT": "https://test.services.ai.azure.com/api/projects/qa",
               "FOUNDRY_AGENT_NAME": "test-agent", "ACR_LOGIN_SERVER": "test.azurecr.io",
               "AGENT_IMAGE": self.image, "AGENT_CPU": "0.25", "AGENT_MEMORY": "0.5Gi",
               "AZURE_AI_MODEL_DEPLOYMENT_NAME": "model", "DEPLOYED_AGENT_VERSION": "4"}
        env_patch = patch.dict(os.environ, env, clear=True)
        env_patch.start()
        self.addCleanup(env_patch.stop)
        self.info = {"status": "active", "definition": {"container_configuration": {"image": self.image}}}
        self.latest = {"versions": {"latest": {"version": "4"}}}

    def test_deploy_outputs_version_and_sets_latest(self):
        os.environ["GITHUB_OUTPUT"] = "output"
        with patch.object(agent, "request", side_effect=[{}, {"version": "4"}, self.info, {}]) as request, patch("builtins.open", mock_open()) as output:
            agent.deploy_agent()
        output().write.assert_called_once_with("agent_version=4\n")
        self.assertEqual(request.call_args.args[1], "PATCH")
        self.assertIn("@latest", json.dumps(request.call_args.args[2]))

    def test_missing_agent_is_created(self):
        missing = HTTPError("https://test", 404, "missing", {}, None)
        with patch.object(agent, "request", side_effect=[missing, {"version": "4"}, self.info, {}]) as request:
            agent.deploy_agent()
        self.assertEqual(request.call_args_list[1].args[2]["name"], "test-agent")

    def test_ambiguous_write_not_retried(self):
        with patch.object(agent, "request", side_effect=[{}, TimeoutError()]) as request:
            with self.assertRaises(TimeoutError):
                agent.deploy_agent()
        self.assertEqual(request.call_count, 2)

    def test_bad_image_rejected_before_network(self):
        os.environ["AGENT_IMAGE"] = "test.azurecr.io/agent:latest"
        with patch.object(agent, "request") as request:
            with self.assertRaises(ValueError):
                agent.deploy_agent()
        request.assert_not_called()

    def test_output_injection_rejected(self):
        with patch.object(agent, "request", side_effect=[{}, {"version": "4\nattack=yes"}]), patch("builtins.open", mock_open()) as output:
            with self.assertRaises(RuntimeError):
                agent.deploy_agent()
        output.assert_not_called()

    def test_provisioning_deadline(self):
        with patch.object(agent, "request", side_effect=[{}, {"version": "4"}]), patch.object(agent.time, "monotonic", side_effect=[0, 1201]):
            with self.assertRaises(TimeoutError):
                agent.deploy_agent()

    def test_active_response_after_deadline_does_not_change_routing(self):
        clock = [0]

        def response(url, method="GET", body=None, **kwargs):
            if method == "POST":
                return {"version": "4"}
            if "/versions/4?" in url:
                clock[0] = 1300
                return {"status": "active"}
            return {}

        with patch.object(agent, "request", side_effect=response) as request, patch.object(agent.time, "monotonic", side_effect=lambda: clock[0]):
            with self.assertRaises(TimeoutError):
                agent.deploy_agent()
        self.assertFalse(any(len(call.args) > 1 and call.args[1] == "PATCH" for call in request.call_args_list))

    def test_deleted_versions_fail_without_sleep(self):
        for status in ("deleting", "deleted"):
            with self.subTest(status=status), patch.object(agent, "request", side_effect=[{}, {"version": "4"}, {"status": status}]), patch.object(agent.time, "sleep") as sleep:
                with self.assertRaisesRegex(RuntimeError, status):
                    agent.deploy_agent()
                sleep.assert_not_called()

    def test_retry_after_seconds_honored_for_reads(self):
        error = HTTPError("https://test", 429, "throttled", {"Retry-After": "60"}, None)
        with patch.object(agent, "request", side_effect=[error, {}]), patch.object(agent.time, "sleep") as sleep:
            agent.read_request("https://test")
        sleep.assert_called_once_with(60)

    def test_retry_after_date_and_invalid_header(self):
        future = format_datetime(datetime.now(timezone.utc) + timedelta(seconds=60), usegmt=True)
        delay = agent.retry_delay(HTTPError("https://test", 503, "busy", {"Retry-After": future}, None), 5)
        self.assertGreater(delay, 58)
        self.assertLessEqual(delay, 60)
        self.assertEqual(agent.retry_delay(HTTPError("https://test", 503, "busy", {"Retry-After": "invalid"}, None), 5), 5)

    def test_retry_delay_cannot_exceed_deadline(self):
        error = HTTPError("https://test", 429, "busy", {"Retry-After": "60"}, None)
        with patch.object(agent, "request", side_effect=error) as request, patch.object(agent.time, "monotonic", return_value=0), patch.object(agent.time, "sleep") as sleep:
            with self.assertRaises(TimeoutError):
                agent.read_request("https://test", deadline=30)
        self.assertEqual(request.call_count, 1)
        sleep.assert_not_called()

    def test_request_timeouts_use_remaining_budget(self):
        with patch.object(agent.time, "monotonic", return_value=95), patch.object(agent.subprocess, "check_output", return_value="token") as token, patch.object(agent, "urlopen", return_value=io.BytesIO(b"{}")) as http:
            agent.request("https://test", deadline=100)
        self.assertEqual(token.call_args.kwargs["timeout"], 5)
        self.assertEqual(http.call_args.kwargs["timeout"], 5)

    def test_retry_after_honored_for_probe(self):
        os.environ["HEALTH_CHECK_URL"] = "https://test.services.ai.azure.com/api/projects/qa/health"
        error = HTTPError("https://test", 429, "busy", {"Retry-After": "60"}, None)
        with patch.object(agent, "request", side_effect=[self.info, self.latest, error, {}]), patch.object(agent.time, "sleep") as sleep:
            agent.verify_agent()
        sleep.assert_called_once_with(60)

    def test_excessive_retry_delay_fails_without_early_retry(self):
        with patch.object(agent.time, "sleep") as sleep:
            with self.assertRaises(TimeoutError):
                agent.wait_for_retry(3600)
        sleep.assert_not_called()

    def test_failed_provisioning(self):
        with patch.object(agent, "request", side_effect=[{}, {"version": "4"}, {"status": "failed"}]):
            with self.assertRaisesRegex(RuntimeError, "provisioning failed"):
                agent.deploy_agent()

    def test_default_verification_does_not_invoke_agent(self):
        with patch.object(agent, "request", side_effect=[self.info, self.latest]) as request:
            agent.verify_agent()
        self.assertEqual(request.call_count, 2)
        self.assertTrue(all(len(call.args) == 1 for call in request.call_args_list))

    def test_configurable_health_url(self):
        url = "https://test.services.ai.azure.com/api/projects/qa/health"
        os.environ["HEALTH_CHECK_URL"] = url
        with patch.object(agent, "request", side_effect=[self.info, self.latest, {}]) as request:
            agent.verify_agent()
        self.assertEqual(request.call_args.args, (url,))
        self.assertTrue(request.call_args.kwargs["health_check"])

    def test_health_url_rejects_external_token_destination(self):
        for url in ("https://evil.example/health", "http://test.services.ai.azure.com/api/projects/qa/health",
                    "https://test.services.ai.azure.com/api/projects/other/health"):
            with self.subTest(url=url), patch.dict(os.environ, HEALTH_CHECK_URL=url), patch.object(agent, "request", return_value=self.info) as request:
                with self.assertRaises(ValueError):
                    agent.verify_agent()
                self.assertEqual(request.call_count, 1)

    def test_verify_wrong_image_and_newer_latest(self):
        cases = [({"status": "active", "definition": {}}, self.latest),
                 (self.info, {"versions": {"latest": {"version": "5"}}})]
        for info, latest in cases:
            with self.subTest(info=info), patch.object(agent, "request", side_effect=[info, latest]) as request:
                with self.assertRaises(RuntimeError):
                    agent.verify_agent()
                self.assertLessEqual(request.call_count, 2)

    def test_reads_retry_only_transient_errors(self):
        for code, count in ((503, 3), (403, 1)):
            with patch.object(agent, "request", side_effect=HTTPError("https://test", code, "error", {}, None)) as request, patch.object(agent.time, "sleep"):
                with self.assertRaises(HTTPError):
                    agent.read_request("https://test")
                self.assertEqual(request.call_count, count)

    def test_token_timeout_and_invalid_response(self):
        with patch.object(agent.subprocess, "check_output", return_value="token") as token, patch.object(agent, "urlopen", return_value=io.BytesIO(b"[]")):
            with self.assertRaises(ValueError):
                agent.request("https://test")
        self.assertEqual(token.call_args.kwargs["timeout"], 60)

    def test_cli_failure_does_not_log_credentials(self):
        error = subprocess.CalledProcessError(1, ["az"], stderr="SECRET")
        with patch.object(agent, "deploy_agent", side_effect=error), self.assertLogs(agent.LOGGER, level="ERROR") as logs:
            self.assertEqual(agent.main(["deploy"]), 1)
        self.assertNotIn("SECRET", str(logs.output))
        self.assertIn("Inspect Foundry", str(logs.output))

    def test_token_timeout_returns_failure(self):
        with patch.object(agent, "verify_agent", side_effect=subprocess.TimeoutExpired("az", 60)):
            self.assertEqual(agent.main(["verify"]), 1)

    def test_summary_without_azure_and_malformed_results(self):
        os.environ["STAGE_RESULTS"] = "invalid"
        with patch.object(agent, "request") as request, patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(agent.main(["summary"]), 0)
        request.assert_not_called()
        self.assertNotIn("Model inference and PostgreSQL connectivity are not tested", output.getvalue())

    def test_summary_omits_stage_table_and_preserves_job_status(self):
        text = agent.render_summary({"JOB_STATUS": "failure", "STAGE_RESULTS": '{"post_check":{"outcome":"failure"}}'})
        self.assertIn("Foundry Docker deployment - failure", text)
        self.assertNotIn("Pipeline stage", text)
        self.assertNotIn("Deployed endpoint / version check", text)

    def test_malformed_nested_deployment_response_is_actionable(self):
        with patch.object(agent, "request", side_effect=[{}, {"versions": None}]):
            with self.assertRaisesRegex(RuntimeError, "versions must be an object"):
                agent.deploy_agent()

    def test_missing_status_stops_polling(self):
        with patch.object(agent, "request", side_effect=[{}, {"version": "4"}, {}]), patch.object(agent.time, "sleep") as sleep:
            with self.assertRaisesRegex(RuntimeError, "provisioning status"):
                agent.deploy_agent()
        sleep.assert_not_called()

    def test_malformed_route_rules_do_not_send_probe(self):
        for rules in ("unexpected", [None], {"type": "FixedRatio"}):
            latest = {**self.latest, "agent_endpoint": {"version_selector": {"version_selection_rules": rules}}}
            with self.subTest(rules=rules), patch.object(agent, "request", side_effect=[self.info, latest]) as request:
                with self.assertRaisesRegex(RuntimeError, "version selection rules"):
                    agent.verify_agent()
                self.assertEqual(request.call_count, 2)

    def test_health_response_accepts_any_body_only_on_200(self):
        for status in (200, 202, 204):
            response = SimpleNamespace(status=status, __enter__=None)
            from unittest.mock import MagicMock
            context = MagicMock()
            context.__enter__.return_value = response
            with self.subTest(status=status), patch.object(agent.subprocess, "check_output", return_value="token"), patch.object(agent, "urlopen", return_value=context):
                if status == 200:
                    self.assertEqual(agent.request("https://test", health_check=True), {})
                else:
                    with self.assertRaisesRegex(RuntimeError, "HTTP 200"):
                        agent.request("https://test", health_check=True)

    def test_health_auth_failure_is_not_retried(self):
        os.environ["HEALTH_CHECK_URL"] = "https://test.services.ai.azure.com/api/projects/qa/health"
        error = HTTPError("https://test", 403, "denied", {}, None)
        with patch.object(agent, "request", side_effect=[self.info, self.latest, error]) as request, patch.object(agent.time, "sleep") as sleep:
            with self.assertRaises(HTTPError):
                agent.verify_agent()
        self.assertEqual(request.call_count, 3)
        sleep.assert_not_called()

    def test_interrupted_read_is_retried(self):
        with patch.object(agent, "request", side_effect=[IncompleteRead(b"partial"), {}]) as request, patch.object(agent.time, "sleep"):
            self.assertEqual(agent.read_request("https://test"), {})
        self.assertEqual(request.call_count, 2)

    def test_all_expected_cli_failures_return_one_without_sensitive_data(self):
        errors = [HTTPError("https://secret", 403, "SECRET", {}, None),
                  FileNotFoundError("SECRET"), PermissionError("SECRET"),
                  UnicodeDecodeError("utf8", b"SECRET", 0, 1, "bad"),
                  json.JSONDecodeError("bad", "SECRET", 0),
                  IncompleteRead(b"SECRET"), ConnectionResetError("SECRET")]
        for error in errors:
            with self.subTest(error=type(error).__name__), patch.object(agent, "verify_agent", side_effect=error), self.assertLogs(agent.LOGGER, level="ERROR") as logs:
                self.assertEqual(agent.main(["verify"]), 1)
            self.assertNotIn("SECRET", str(logs.output))

    def test_summary_file_permission_failure_returns_one(self):
        os.environ["GITHUB_STEP_SUMMARY"] = "summary"
        with patch("builtins.open", side_effect=PermissionError()):
            self.assertEqual(agent.main(["summary"]), 1)

    def test_empty_token_does_not_send_http_request(self):
        with patch.object(agent.subprocess, "check_output", return_value=""), patch.object(agent, "urlopen") as http:
            with self.assertRaisesRegex(RuntimeError, "empty access token"):
                agent.request("https://test")
        http.assert_not_called()

    def test_huge_retry_header_is_bounded(self):
        error = HTTPError("https://test", 429, "busy", {"Retry-After": "9" * 5000}, None)
        with patch.object(agent.time, "sleep") as sleep:
            with self.assertRaises(TimeoutError):
                agent.wait_for_retry(agent.retry_delay(error, 5))
        sleep.assert_not_called()

    def test_redirect_handler_rejects_redirects(self):
        self.assertIsNone(agent.NoRedirect().redirect_request(None, None, 302, "redirect", {}, "https://other"))

    def test_interrupt_returns_130(self):
        with patch.object(agent, "verify_agent", side_effect=KeyboardInterrupt()):
            self.assertEqual(agent.main(["verify"]), 130)

    def test_invalid_command_returns_argparse_exit_two(self):
        with patch("sys.stderr", new_callable=io.StringIO), self.assertRaises(SystemExit) as error:
            agent.main(["unknown"])
        self.assertEqual(error.exception.code, 2)

    def test_configuration_errors_do_not_send_requests(self):
        cases = [{"FOUNDRY_PROJECT_ENDPOINT": "https://test.services.ai.azure.com:SECRET/api/projects/qa"},
                 {"FOUNDRY_AGENT_NAME": "../other"}, {"AGENT_CPU": ""}]
        for overrides in cases:
            with self.subTest(overrides=overrides), patch.dict(os.environ, overrides), patch.object(agent, "request") as request, self.assertLogs(agent.LOGGER, level="ERROR") as logs:
                self.assertEqual(agent.main(["deploy"]), 1)
            request.assert_not_called()
            self.assertNotIn("SECRET", str(logs.output))

    def test_auth_failure_does_not_create_version(self):
        with patch.object(agent, "request", side_effect=HTTPError("https://test", 403, "forbidden", {}, None)) as request:
            self.assertEqual(agent.main(["deploy"]), 1)
        self.assertEqual(request.call_count, 1)

    def test_output_file_failure_stops_after_version_creation(self):
        os.environ["GITHUB_OUTPUT"] = "output"
        with patch.object(agent, "request", side_effect=[{}, {"version": "4"}]) as request, patch("builtins.open", side_effect=PermissionError()):
            self.assertEqual(agent.main(["deploy"]), 1)
        self.assertEqual(request.call_count, 2)

    def test_routing_write_failure_is_not_retried(self):
        with patch.object(agent, "request", side_effect=[{}, {"version": "4"}, self.info, TimeoutError()]) as request:
            self.assertEqual(agent.main(["deploy"]), 1)
        self.assertEqual(request.call_count, 4)


if __name__ == "__main__":
    unittest.main(verbosity=2)
