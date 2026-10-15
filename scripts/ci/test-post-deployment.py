"""Offline tests for deployed-version verification and failure summaries."""
import importlib.util
import json
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from urllib.error import HTTPError


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


probe = load("probe", "check-deployed-agent.py")
summary = load("summary", "write-agent-summary.py")


class PostDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.image = "test.azurecr.io/agent@sha256:" + "a" * 64
        self.env = {"FOUNDRY_PROJECT_ENDPOINT": "https://test.services.ai.azure.com/api/projects/qa",
                    "FOUNDRY_AGENT_NAME": "test-agent", "DEPLOYED_AGENT_VERSION": "4", "AGENT_IMAGE": self.image}
        env_patch = patch.dict(os.environ, self.env, clear=True)
        env_patch.start()
        self.addCleanup(env_patch.stop)
        nonce_patch = patch.object(probe.uuid, "uuid4", return_value=SimpleNamespace(hex="a" * 32))
        nonce_patch.start()
        self.addCleanup(nonce_patch.stop)
        self.info = {"status": "active", "definition": {"container_configuration": {"image": self.image}}}
        self.agent = {"versions": {"latest": {"version": "4"}}}

    def response(self, version="4"):
        return {"status": "completed", "output": [{"type": "message", "content": [
            {"type": "output_text", "text": f"DEPLOYMENT_OK:{'a' * 32}:{version}"}]}]}

    def test_probe_is_stateless_and_checks_running_version(self):
        with patch.object(probe.deploy, "request", side_effect=[self.info, self.agent, self.response()]) as request:
            probe.check()
        payload = request.call_args_list[2].args[2]
        self.assertFalse(payload["store"])
        self.assertFalse(payload["stream"])
        self.assertEqual(payload["input"], "__deployment_healthcheck__:" + "a" * 32)

    def test_wrong_running_version_fails(self):
        with patch.object(probe.deploy, "request", side_effect=[self.info, self.agent, self.response("3")]):
            with self.assertRaisesRegex(RuntimeError, "nonce and deployed version"):
                probe.check()

    def test_wrong_image_fails_before_invocation(self):
        self.info["definition"]["container_configuration"]["image"] = "other-image"
        with patch.object(probe.deploy, "request", return_value=self.info) as request:
            with self.assertRaisesRegex(RuntimeError, "expected image"):
                probe.check()
        self.assertEqual(request.call_count, 1)

    def test_retry_only_transient_probe_failure(self):
        with patch.object(probe.deploy, "request", side_effect=[self.info, self.agent, HTTPError("https://test", 424, "starting", {}, None), self.response()]) as request, patch.object(probe.time, "sleep"):
            probe.check()
        self.assertEqual(request.call_count, 4)

    def test_auth_failure_not_retried(self):
        with patch.object(probe.deploy, "request", side_effect=[self.info, self.agent, HTTPError("https://test", 403, "forbidden", {}, None)]) as request:
            with self.assertRaises(HTTPError):
                probe.check()
        self.assertEqual(request.call_count, 3)

    def test_old_pinned_route_fails_before_invocation(self):
        self.agent["agent_endpoint"] = {"version_selector": {"version_selection_rules": [
            {"type": "FixedRatio", "agent_version": "3", "traffic_percentage": 100}]}}
        with patch.object(probe.deploy, "request", side_effect=[self.info, self.agent]) as request:
            with self.assertRaisesRegex(RuntimeError, "probe was not sent"):
                probe.check()
        self.assertEqual(request.call_count, 2)

    def test_explicit_promotion_targets_verified_version(self):
        with patch.object(probe.deploy, "request", side_effect=[self.info, {}]) as request:
            probe.promote()
        self.assertEqual(request.call_args.args[1], "PATCH")
        rule = request.call_args.args[2]["agent_endpoint"]["version_selector"]["version_selection_rules"][0]
        self.assertEqual(rule["agent_version"], "4")
        self.assertEqual(rule["traffic_percentage"], 100)

    def test_failure_summary_shows_skipped_stages(self):
        text = summary.render({"JOB_STATUS": "failure", "STAGE_RESULTS": json.dumps({
            "build": {"outcome": "failure"}, "post_check": {"outcome": "skipped"}})})
        self.assertIn("Docker build | failure", text)
        self.assertIn("Deployed endpoint / version check | skipped", text)
        self.assertIn("Model inference and PostgreSQL connectivity are not tested", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
