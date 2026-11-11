import importlib.util
import hashlib
import hmac
import json
import os
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import Mock, patch


def load_actions():
    numpy = types.ModuleType("numpy")
    numpy.ndarray = type("ndarray", (), {})
    boto3 = types.ModuleType("boto3")
    boto3.client = Mock()
    requests = types.ModuleType("requests")
    requests.HTTPError = type("HTTPError", (Exception,), {})
    spec = importlib.util.spec_from_file_location(
        "security_actions", Path(__file__).resolve().parents[1] / "action_groups/app.py"
    )
    module = importlib.util.module_from_spec(spec)
    with patch.dict(sys.modules, {"numpy": numpy, "boto3": boto3, "requests": requests}):
        with patch.dict(os.environ, {
            "RAILS_API_URL": "https://rails.example.invalid",
            "RESILIENCE_API_KEY": "test-key",
            "EMBEDDINGS_BUCKET": "test-bucket",
        }):
            spec.loader.exec_module(module)
    return module


actions = load_actions()


class AuthorizationTests(unittest.TestCase):
    def test_missing_and_wildcard_scopes_do_not_expand_admin_access(self):
        for raw in (None, "*", ""):
            auth = actions.AuthContext({"admin_role": "admin", "allowed_site_scope_ids": raw})
            self.assertFalse(auth.can_access_site_scope("1"))
            self.assertFalse(auth.can_access_site_scope(None))

    def test_contributors_never_patch_even_when_published_is_a_string(self):
        for role in ("contributor", "staff"):
            auth = actions.AuthContext({"admin_role": role, "allowed_site_scope_ids": "1"})
            for value in (True, "true", "1", False):
                with patch.object(actions, "rails_patch") as request:
                    result = json.loads(actions.handle_update_layer({"layer_id": "1", "published": value}, auth))
                    self.assertFalse(result["success"])
                    request.assert_not_called()

    def test_contributors_create_only_unpublished_layers(self):
        auth = actions.AuthContext({"admin_role": "contributor", "allowed_site_scope_ids": "1"})
        with patch.object(actions, "rails_post", return_value={"data": {"id": 5}}) as request:
            with patch.object(actions, "rails_get", return_value={"data": []}):
                actions.handle_create_layer({"name": "Test", "site_scope_id": "1", "published": "true"}, auth)
        self.assertIs(request.call_args.args[1]["layer"]["published"], False)

    def test_raw_data_tools_require_superadmin(self):
        auth = actions.AuthContext({"admin_role": "contributor", "allowed_site_scope_ids": "1"})
        with patch.object(actions, "rails_get") as request:
            self.assertFalse(json.loads(actions.handle_get_tables({}, auth))["success"])
            self.assertFalse(json.loads(actions.handle_get_statistics({"table_name": "secret", "column": "email"}, auth))["success"])
            request.assert_not_called()

    def test_shared_layer_requires_all_scope_permissions(self):
        auth = actions.AuthContext({"admin_role": "admin", "allowed_site_scope_ids": "1"})
        with patch.object(actions, "rails_get", return_value={"data": {"site_scope_ids": ["1", "2"]}}):
            with patch.object(actions, "rails_patch") as request:
                self.assertFalse(json.loads(actions.handle_update_layer({"layer_id": "1"}, auth))["success"])
                request.assert_not_called()

    def test_actor_context_is_forwarded_and_cleared_between_requests(self):
        event = {"function": "test", "sessionAttributes": {"admin_user_id": "7", "admin_role": "admin", "allowed_site_scope_ids": "1"}}
        with patch.dict(actions.ACTION_HANDLERS, {"test": lambda params, auth: json.dumps(actions.rails_headers())}):
            response = actions.handler(event, None)
            body = json.loads(response["response"]["functionResponse"]["responseBody"]["TEXT"]["body"])
        self.assertEqual(body["X-Admin-User-Id"], "7")
        with self.assertRaises(PermissionError):
            actions.rails_headers()

    def test_missing_actor_is_denied_before_dispatch(self):
        with patch.dict(actions.ACTION_HANDLERS, {"test": Mock()}) as handlers:
            actions.handler({"function": "test", "sessionAttributes": {"admin_role": "superadmin"}}, None)
            handlers["test"].assert_not_called()

    def test_superadmin_cog_statistics_sign_exact_source(self):
        auth = actions.AuthContext({"admin_role": "superadmin"})
        response = Mock()
        response.json.return_value = {"b1": {"min": 0}}
        source = "s3://resilienceatlas/private.tif"
        with patch.dict(os.environ, {"DATA_GATEWAY_SECRET": "s" * 32}):
            with patch.object(actions.requests, "get", create=True, return_value=response) as request:
                actions.handle_get_statistics({"s3_uri": source}, auth)
        expires, digest = request.call_args.kwargs["headers"]["X-Data-Authorization"].split(":")
        self.assertEqual(digest, hmac.new(b"s" * 32, f"{expires}\n{source}".encode(), hashlib.sha256).hexdigest())
        self.assertEqual(request.call_args.args[0], f"{actions.TITILER_URL}/statistics")


if __name__ == "__main__":
    unittest.main()
