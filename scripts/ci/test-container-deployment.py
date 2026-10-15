"""Offline checks for image deployment payloads and failure handling."""
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import mock_open, patch
from urllib.error import HTTPError


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("deploy_container", ROOT / "scripts/ci/deploy-container-agent.py")
deploy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(deploy)


class ContainerDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.summary = mock_open()
        summary_patch = patch("builtins.open", self.summary)
        summary_patch.start()
        self.addCleanup(summary_patch.stop)
        self.env = {
            "FOUNDRY_PROJECT_ENDPOINT": "https://test.services.ai.azure.com/api/projects/qa",
            "FOUNDRY_AGENT_NAME": "test-agent", "ACR_LOGIN_SERVER": "test.azurecr.io",
            "AGENT_IMAGE": "test.azurecr.io/agent@sha256:" + "a" * 64,
            "AGENT_CPU": "0.25", "AGENT_MEMORY": "0.5Gi",
            "AZURE_AI_MODEL_DEPLOYMENT_NAME": "model", "POSTGRES_HOST": "unused",
            "POSTGRES_DATABASE": "unused", "POSTGRES_AAD_USER": "unused",
            "GITHUB_STEP_SUMMARY": "summary.md",
        }
        self.patch = patch.dict(os.environ, self.env, clear=True)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        prior = Path.cwd()
        os.chdir(ROOT)
        self.addCleanup(os.chdir, prior)

    def test_payload_uses_image_only(self):
        definition = deploy.definition()
        self.assertNotIn("code_configuration", definition)
        self.assertEqual(definition["container_configuration"], {"image": self.env["AGENT_IMAGE"]})
        self.assertNotIn("FOUNDRY_PROJECT_ENDPOINT", definition["environment_variables"])

    def test_mutable_tag_rejected_before_network(self):
        os.environ["AGENT_IMAGE"] = "test.azurecr.io/agent:latest"
        with patch.object(deploy, "request") as request:
            with self.assertRaises(ValueError):
                deploy.main()
            request.assert_not_called()

    def test_other_registry_rejected(self):
        os.environ["AGENT_IMAGE"] = "other.azurecr.io/agent@sha256:" + "a" * 64
        with self.assertRaises(ValueError):
            deploy.definition()

    def test_existing_agent_creates_version_and_reports_digest(self):
        with patch.object(deploy, "request", side_effect=[{}, {"version": "3"}, {"status": "active"}]) as request:
            deploy.main()
        self.assertIn("/versions?api-version=v1", request.call_args_list[1].args[0])
        self.assertNotIn("name", request.call_args_list[1].args[2])
        self.assertIn(self.env["AGENT_IMAGE"], self.summary().write.call_args.args[0])

    def test_missing_agent_creates_named_resource(self):
        missing = HTTPError("https://test", 404, "not found", {}, None)
        with patch.object(deploy, "request", side_effect=[missing, {"version": "1"}, {"status": "active"}]) as request:
            deploy.main()
        self.assertTrue(request.call_args_list[1].args[0].endswith("/agents?api-version=v1"))
        self.assertEqual(request.call_args_list[1].args[2]["name"], "test-agent")

    def test_auth_failure_does_not_create_version(self):
        with patch.object(deploy, "request", side_effect=HTTPError("https://test", 403, "forbidden", {}, None)) as request:
            with self.assertRaises(HTTPError):
                deploy.main()
        self.assertEqual(request.call_count, 1)

    def test_image_pull_failure_fails_deployment(self):
        with patch.object(deploy, "request", side_effect=[{}, {"version": "3"}, {"status": "failed", "error": "image_pull_failed"}]):
            with self.assertRaisesRegex(RuntimeError, "image_pull_failed"):
                deploy.main()

    def test_ambiguous_post_not_retried(self):
        with patch.object(deploy, "request", side_effect=[{}, TimeoutError("ambiguous")]) as request:
            with self.assertRaises(TimeoutError):
                deploy.main()
        self.assertEqual(request.call_count, 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
