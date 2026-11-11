import hashlib
import hmac
import os
import time
import unittest
from unittest.mock import patch

from data_access import resource_authorized


class ResourceAuthorizationTests(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, {"DATA_GATEWAY_SECRET": "s" * 32, "EE_PUBLIC_ASSET_IDS": ""})
        self.env.start()
        self.addCleanup(self.env.stop)

    def token(self, resource, expires):
        digest = hmac.new(b"s" * 32, f"{expires}\n{resource}".encode(), hashlib.sha256).hexdigest()
        return {"X-Data-Authorization": f"{expires}:{digest}"}

    def test_no_implicit_service_account_access(self):
        self.assertFalse(resource_authorized("private/asset", {}))
        self.assertFalse(resource_authorized(None, {}))

    def test_signature_is_bound_to_the_exact_asset(self):
        headers = self.token("private/asset", int(time.time()) + 60)
        self.assertTrue(resource_authorized("private/asset", headers))
        self.assertFalse(resource_authorized("private/other", headers))

    def test_expired_long_lived_and_tampered_tokens_fail(self):
        for expiry in (int(time.time()) - 1, int(time.time()) + 3600):
            self.assertFalse(resource_authorized("private/asset", self.token("private/asset", expiry)))
        self.assertFalse(resource_authorized("private/asset", {"x-data-authorization": "invalid"}))
        self.assertFalse(resource_authorized("private/asset", {"x-data-authorization": f"{int(time.time()) + 60}:\N{SNOWMAN}"}))

    def test_only_exact_explicit_public_assets_bypass_signing(self):
        with patch.dict(os.environ, {"EE_PUBLIC_ASSET_IDS": "public/asset"}):
            self.assertTrue(resource_authorized("public/asset", {}))
            self.assertFalse(resource_authorized("public/asset/child", {}))

    def test_missing_or_short_signing_secret_fails_closed(self):
        for secret in ("", "short"):
            with patch.dict(os.environ, {"DATA_GATEWAY_SECRET": secret}):
                self.assertFalse(resource_authorized("private/asset", {}))


if __name__ == "__main__":
    unittest.main()
