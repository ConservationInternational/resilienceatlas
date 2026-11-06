import json
import os

import pytest

from titiler_cogs import app as app_module
from titiler_cogs.app import app, is_url_allowed


# ──────────────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────────────

@pytest.fixture(autouse=True)
def set_allowed_buckets(monkeypatch):
    """Set TITILER_ALLOWED_BUCKETS for all tests and reset the cached value."""
    monkeypatch.setenv("TITILER_ALLOWED_BUCKETS", "s3://resilienceatlas,s3://trends.earth-private,gs://my-gcs-bucket")
    # Reset the module-level cache so each test picks up the env var fresh
    app_module._allowed_buckets = None
    yield
    app_module._allowed_buckets = None


@pytest.fixture()
def apigw_event():
    """ Generates API GW Event"""

    return {
        "body": '{ "test": "body"}',
        "resource": "/{proxy+}",
        "requestContext": {
            "resourceId": "123456",
            "apiId": "1234567890",
            "resourcePath": "/{proxy+}",
            "httpMethod": "POST",
            "requestId": "c6af9ac6-7b61-11e6-9a41-93e8deadbeef",
            "accountId": "123456789012",
            "identity": {
                "apiKey": "",
                "userArn": "",
                "cognitoAuthenticationType": "",
                "caller": "",
                "userAgent": "Custom User Agent String",
                "user": "",
                "cognitoIdentityPoolId": "",
                "cognitoIdentityId": "",
                "cognitoAuthenticationProvider": "",
                "sourceIp": "127.0.0.1",
                "accountId": "",
            },
            "stage": "prod",
        },
        "queryStringParameters": {"foo": "bar"},
        "headers": {
            "Via": "1.1 08f323deadbeefa7af34d5feb414ce27.cloudfront.net (CloudFront)",
            "Accept-Language": "en-US,en;q=0.8",
            "CloudFront-Is-Desktop-Viewer": "true",
            "CloudFront-Is-SmartTV-Viewer": "false",
            "CloudFront-Is-Mobile-Viewer": "false",
            "X-Forwarded-For": "127.0.0.1, 127.0.0.2",
            "CloudFront-Viewer-Country": "US",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Upgrade-Insecure-Requests": "1",
            "X-Forwarded-Port": "443",
            "Host": "1234567890.execute-api.us-east-1.amazonaws.com",
            "X-Forwarded-Proto": "https",
            "X-Amz-Cf-Id": "aaaaaaaaaae3VYQb9jd-nvCd-de396Uhbp027Y2JvkCPNLmGJHqlaA==",
            "CloudFront-Is-Tablet-Viewer": "false",
            "Cache-Control": "max-age=0",
            "User-Agent": "Custom User Agent String",
            "CloudFront-Forwarded-Proto": "https",
            "Accept-Encoding": "gzip, deflate, sdch",
        },
        "pathParameters": {"proxy": "/examplepath"},
        "httpMethod": "POST",
        "stageVariables": {"baz": "qux"},
        "path": "/examplepath",
    }


# ──────────────────────────────────────────────────────────────────────────────
# is_url_allowed – S3 URL formats
# ──────────────────────────────────────────────────────────────────────────────

class TestIsUrlAllowedS3:
    """Test that all supported S3 URL formats are accepted or rejected correctly."""

    # --- Native s3:// scheme ---

    def test_s3_scheme_allowed(self):
        assert is_url_allowed("s3://resilienceatlas/cogs/layer.tif") is True

    def test_s3_scheme_denied(self):
        assert is_url_allowed("s3://other-bucket/file.tif") is False

    # --- Virtual-hosted style (standard) ---

    def test_virtual_hosted_no_region_allowed(self):
        assert is_url_allowed("https://resilienceatlas.s3.amazonaws.com/cogs/layer.tif") is True

    def test_virtual_hosted_with_region_allowed(self):
        assert is_url_allowed("https://resilienceatlas.s3.us-east-1.amazonaws.com/cogs/layer.tif") is True

    # --- Virtual-hosted dualstack (the production URL format) ---

    def test_virtual_hosted_dualstack_no_region_allowed(self):
        """s3.dualstack.amazonaws.com without explicit region should be allowed."""
        assert is_url_allowed("https://resilienceatlas.s3.dualstack.amazonaws.com/cogs/layer.tif") is True

    def test_virtual_hosted_dualstack_with_region_allowed(self):
        """Production URL: resilienceatlas.s3.dualstack.us-east-1.amazonaws.com"""
        assert is_url_allowed(
            "https://resilienceatlas.s3.dualstack.us-east-1.amazonaws.com/cogs/chirps_mon_trnd_dec_rainyseas1.tif"
        ) is True

    def test_virtual_hosted_dualstack_denied_wrong_bucket(self):
        assert is_url_allowed(
            "https://other-bucket.s3.dualstack.us-east-1.amazonaws.com/file.tif"
        ) is False

    # --- Path-style ---

    def test_path_style_allowed(self):
        assert is_url_allowed("https://s3.amazonaws.com/resilienceatlas/cogs/layer.tif") is True

    def test_path_style_with_region_allowed(self):
        assert is_url_allowed("https://s3.us-east-1.amazonaws.com/resilienceatlas/cogs/layer.tif") is True

    def test_path_style_denied_wrong_bucket(self):
        assert is_url_allowed("https://s3.amazonaws.com/other-bucket/file.tif") is False

    # --- Security: must not match crafted hostnames ---

    def test_rejects_subdomain_spoofing(self):
        """resilienceatlas.s3.amazonaws.com.evil.com must be rejected."""
        assert is_url_allowed("https://resilienceatlas.s3.amazonaws.com.evil.com/file.tif") is False

    def test_rejects_empty_url(self):
        assert is_url_allowed("") is False

    def test_rejects_none_like_empty(self):
        assert is_url_allowed("") is False


# ──────────────────────────────────────────────────────────────────────────────
# is_url_allowed – GCS URL formats
# ──────────────────────────────────────────────────────────────────────────────

class TestIsUrlAllowedGCS:

    def test_gs_scheme_allowed(self):
        assert is_url_allowed("gs://my-gcs-bucket/file.tif") is True

    def test_gs_scheme_denied(self):
        assert is_url_allowed("gs://other-gcs-bucket/file.tif") is False

    def test_https_storage_googleapis_allowed(self):
        assert is_url_allowed("https://storage.googleapis.com/my-gcs-bucket/file.tif") is True

    def test_https_storage_googleapis_denied(self):
        assert is_url_allowed("https://storage.googleapis.com/other-bucket/file.tif") is False

    def test_https_storage_cloud_google_allowed(self):
        assert is_url_allowed("https://storage.cloud.google.com/my-gcs-bucket/file.tif") is True


class TestNetChangeColormap:
    def test_versioned_colormap_is_registered(self):
        assert app_module.custom_cmap.get("ra_net_change_v2") == app_module._net_change_colormap

    def test_is_zero_centered_and_matches_legend_colors(self):
        opaque_intervals = [
            interval
            for interval in app_module._net_change_colormap
            if interval[1][3] == 255
        ]
        expected_colors = [
            "#9b2779", "#a84b87", "#b56f95", "#c1839e", "#c4939b",
            "#cda3a8", "#d4b3b5", "#dbc3c2", "#e0bbd5", "#e8cdd8",
            "#f7f7f7",
            "#edf3e5", "#e1efda", "#d3ecce", "#c0e4b5", "#a6d99b",
            "#8dcb82", "#73bc68", "#5aad4f", "#419e35", "#006500",
        ]

        assert len(opaque_intervals) == 21
        assert opaque_intervals[10] == ((-476, 476), (247, 247, 247, 255))
        assert [
            f"#{red:02x}{green:02x}{blue:02x}"
            for _, (red, green, blue, _) in opaque_intervals
        ] == expected_colors

        negative_intervals = opaque_intervals[:10]
        positive_intervals = opaque_intervals[11:]
        for (negative_range, _), (positive_range, _) in zip(
            negative_intervals, reversed(positive_intervals)
        ):
            assert negative_range == (-positive_range[1], -positive_range[0])


# ──────────────────────────────────────────────────────────────────────────────
# CORS headers on error responses
# ──────────────────────────────────────────────────────────────────────────────

class TestCorsOnErrorResponses:
    """Verify that CORS headers are present on error responses.

    Starlette routes Exception/500 handlers to ServerErrorMiddleware (outside
    CORSMiddleware).  The custom _exception_with_cors_handler must add the CORS
    headers manually so the browser can read the error body.
    """

    @pytest.fixture()
    def test_client(self):
        from starlette.testclient import TestClient
        # raise_server_exceptions=False so the client returns the error response
        # instead of re-raising the exception in the test process.
        return TestClient(app, raise_server_exceptions=False)

    def test_denied_bucket_returns_cors_header(self, test_client):
        """Requests for disallowed buckets return 403 with CORS headers."""
        resp = test_client.get(
            "/cog/info",
            params={"url": "https://not-allowed.s3.amazonaws.com/file.tif"},
            headers={"Origin": "https://staging.resilienceatlas.org"},
        )
        assert resp.status_code == 403
        assert "access-control-allow-origin" in resp.headers

    def test_preflight_returns_cors_headers(self, test_client):
        """OPTIONS preflight for a tile request includes CORS headers."""
        resp = test_client.options(
            "/cog/tiles/WebMercatorQuad/3/2/3",
            headers={
                "Origin": "https://staging.resilienceatlas.org",
                "Access-Control-Request-Method": "GET",
            },
        )
        assert resp.status_code == 200
        assert "access-control-allow-origin" in resp.headers

    def test_unknown_origin_gets_no_cors_header(self, test_client):
        """Requests from unknown origins must not receive CORS headers."""
        resp = test_client.get(
            "/cog/info",
            params={"url": "https://not-allowed.s3.amazonaws.com/file.tif"},
            headers={"Origin": "https://evil.example.com"},
        )
        assert "access-control-allow-origin" not in resp.headers
