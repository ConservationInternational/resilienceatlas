import logging
import os
import re
from urllib.parse import urlparse
from mangum import Mangum
from rio_tiler.colormap import cmap as default_cmap
from titiler.core.factory import TilerFactory
from titiler.core.dependencies import create_colormap_dependency
from titiler.core.errors import DEFAULT_STATUS_CODES, add_exception_handlers
from titiler.core.middleware import CacheControlMiddleware
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, HTTPException, Query, Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
import rollbar
from rollbar.contrib.fastapi import ReporterMiddleware as RollbarMiddleware

logging.getLogger("mangum.lifespan").setLevel(logging.ERROR)
logging.getLogger("mangum.http").setLevel(logging.ERROR)
logging.getLogger("rio-tiler").setLevel(logging.ERROR)

# Initialize Rollbar for error tracking
# Distinguishes TiTiler errors from frontend/backend via 'component' tag
_rollbar_token = os.environ.get("ROLLBAR_ACCESS_TOKEN", "")
_rollbar_environment = os.environ.get("ROLLBAR_ENVIRONMENT", "development")

if _rollbar_token:
    rollbar.init(
        access_token=_rollbar_token,
        environment=_rollbar_environment,
        code_version=os.environ.get("AWS_LAMBDA_FUNCTION_VERSION", "unknown"),
        handler="async",
        # Include custom payload data matching frontend/backend pattern for consistency
        payload_handler=lambda payload: {
            **payload,
            "data": {
                **payload.get("data", {}),
                "context": "titiler",
                "custom": {
                    **payload.get("data", {}).get("custom", {}),
                    "application": "ResilienceAtlas TiTiler",
                },
            },
        },
    )
    logging.info("Rollbar initialized for TiTiler")
else:
    logging.warning("ROLLBAR_ACCESS_TOKEN not set, error tracking disabled")

# Whitelisted cloud storage buckets (AWS S3 and Google Cloud Storage)
# Format: comma-separated URIs with scheme prefix, e.g. "s3://bucket1,gs://bucket2"
# Set via TITILER_ALLOWED_BUCKETS environment variable
# Validation is deferred to runtime to allow Docker build without env vars

_allowed_buckets: dict[str, set[str]] | None = None


def _get_allowed_buckets() -> dict[str, set[str]]:
    """Lazily parse and validate allowed buckets from environment variable.
    
    This is deferred to runtime so Docker builds succeed without the env var.
    """
    global _allowed_buckets
    
    if _allowed_buckets is not None:
        return _allowed_buckets
    
    raw = os.environ.get("TITILER_ALLOWED_BUCKETS", "").split(",")
    raw = [b.strip() for b in raw if b.strip()]
    
    if not raw:
        raise ValueError(
            "TITILER_ALLOWED_BUCKETS environment variable is required. "
            "Set it with comma-separated bucket URIs (e.g., 's3://my-bucket,gs://my-gcs-bucket')."
        )
    
    # Parse bucket URIs into (provider, bucket_name) sets
    buckets: dict[str, set[str]] = {"s3": set(), "gs": set()}
    
    for bucket_uri in raw:
        if bucket_uri.startswith("s3://"):
            bucket_name = bucket_uri[5:].strip("/")
            if bucket_name:
                buckets["s3"].add(bucket_name)
        elif bucket_uri.startswith("gs://"):
            bucket_name = bucket_uri[5:].strip("/")
            if bucket_name:
                buckets["gs"].add(bucket_name)
        else:
            raise ValueError(
                f"Invalid bucket URI format: '{bucket_uri}'. "
                "Must start with 's3://' or 'gs://' (e.g., 's3://my-bucket' or 'gs://my-gcs-bucket')."
            )
    
    if not buckets["s3"] and not buckets["gs"]:
        raise ValueError(
            "No valid buckets configured. "
            "Set TITILER_ALLOWED_BUCKETS with URIs like 's3://my-bucket,gs://my-gcs-bucket'."
        )
    
    _allowed_buckets = buckets
    return _allowed_buckets


def _format_allowed_buckets() -> str:
    """Format allowed buckets for display in error messages."""
    buckets_dict = _get_allowed_buckets()
    buckets = []
    for bucket in buckets_dict["s3"]:
        buckets.append(f"s3://{bucket}")
    for bucket in buckets_dict["gs"]:
        buckets.append(f"gs://{bucket}")
    return ", ".join(sorted(buckets))


def is_url_allowed(url: str) -> bool:
    """Check if the URL is from an allowed cloud storage bucket.
    
    Validates against strict URL patterns for AWS S3 and Google Cloud Storage
    to prevent spoofing. Checks both the provider and bucket name.
    """
    if not url:
        return False
    
    allowed = _get_allowed_buckets()
    parsed = urlparse(url)
    
    # AWS S3 URL formats:
    # - s3://bucket-name/key
    # - https://bucket-name.s3.amazonaws.com/key
    # - https://bucket-name.s3.region.amazonaws.com/key
    # - https://bucket-name.s3.dualstack.amazonaws.com/key          (dual-stack: IPv4+IPv6)
    # - https://bucket-name.s3.dualstack.region.amazonaws.com/key   (dual-stack with region)
    # - https://s3.amazonaws.com/bucket-name/key
    # - https://s3.region.amazonaws.com/bucket-name/key
    #
    # Google Cloud Storage URL formats:
    # - gs://bucket-name/key
    # - https://storage.googleapis.com/bucket-name/key
    # - https://storage.cloud.google.com/bucket-name/key
    
    # Native S3 scheme
    if parsed.scheme == "s3":
        bucket = parsed.netloc
        return bucket in allowed["s3"]
    
    # Native GCS scheme
    if parsed.scheme == "gs":
        bucket = parsed.netloc
        return bucket in allowed["gs"]
    
    if parsed.scheme in ("http", "https"):
        host = parsed.netloc.lower()
        
        # Remove port if present
        if ":" in host:
            host = host.split(":")[0]
        
        # === AWS S3 URL patterns ===
        
        # Virtual-hosted style: bucket-name.s3.amazonaws.com, bucket-name.s3.region.amazonaws.com,
        # or bucket-name.s3.dualstack.region.amazonaws.com (IPv4+IPv6 dual-stack endpoint)
        # Pattern ensures host ENDS with .amazonaws.com (no suffix allowed)
        s3_virtual_hosted_pattern = re.compile(
            r'^(?P<bucket>[a-z0-9][a-z0-9.-]+[a-z0-9])\.s3(\.dualstack)?(\.(?P<region>[a-z0-9-]+))?\.amazonaws\.com$'
        )
        match = s3_virtual_hosted_pattern.match(host)
        if match:
            bucket = match.group('bucket')
            return bucket in allowed["s3"]
        
        # Path-style: s3.amazonaws.com/bucket-name or s3.region.amazonaws.com/bucket-name
        # Pattern ensures host is EXACTLY s3.amazonaws.com or s3.region.amazonaws.com
        s3_path_style_pattern = re.compile(
            r'^s3(\.(?P<region>[a-z0-9-]+))?\.amazonaws\.com$'
        )
        match = s3_path_style_pattern.match(host)
        if match:
            path_parts = parsed.path.strip("/").split("/")
            if path_parts and path_parts[0]:
                bucket = path_parts[0]
                return bucket in allowed["s3"]
        
        # === Google Cloud Storage URL patterns ===
        
        # GCS path-style: storage.googleapis.com/bucket-name/key
        # Pattern ensures host is EXACTLY storage.googleapis.com
        if host == "storage.googleapis.com":
            path_parts = parsed.path.strip("/").split("/")
            if path_parts and path_parts[0]:
                bucket = path_parts[0]
                return bucket in allowed["gs"]
        
        # GCS authenticated URL style: storage.cloud.google.com/bucket-name/key
        # Pattern ensures host is EXACTLY storage.cloud.google.com
        if host == "storage.cloud.google.com":
            path_parts = parsed.path.strip("/").split("/")
            if path_parts and path_parts[0]:
                bucket = path_parts[0]
                return bucket in allowed["gs"]
    
    # Reject all other URL formats
    return False


class BucketWhitelistMiddleware(BaseHTTPMiddleware):
    """Middleware to restrict access to whitelisted cloud storage buckets only.
    
    Supports AWS S3 and Google Cloud Storage buckets.
    
    Returns JSONResponse objects rather than raising exceptions so that the
    CORSMiddleware (outermost) can intercept the response and add CORS headers.
    Raising exceptions from BaseHTTPMiddleware bypasses all inner middleware
    and lands directly in ServerErrorMiddleware without CORS headers.
    """
    
    async def dispatch(self, request: Request, call_next):
        # Skip health check
        if request.url.path == "/healthz":
            return await call_next(request)
        
        # Check the 'url' query parameter
        url_param = request.query_params.get("url")
        if url_param:
            try:
                if not is_url_allowed(url_param):
                    return JSONResponse(
                        content={
                            "detail": (
                                "Access denied. Only whitelisted cloud storage buckets are allowed. "
                                f"Allowed buckets: {_format_allowed_buckets()}"
                            )
                        },
                        status_code=403,
                    )
            except ValueError as exc:
                return JSONResponse(
                    content={"detail": str(exc)},
                    status_code=500,
                )
        
        return await call_next(request)


# ──────────────────────────────────────────────────────────────
# Register custom named colormaps for Resilience Atlas layers
# These can be referenced via ?colormap_name=<name> in tile URLs,
# avoiding the need to pass large colormap JSON in query strings.
# ──────────────────────────────────────────────────────────────

def _interpolate_colormap(stops, steps_per_segment=5):
    """Build an interval colormap by interpolating between color stops.
    
    Args:
        stops: list of (value, (r, g, b, a)) tuples, ordered by value
        steps_per_segment: interpolation steps between each pair of stops
    
    Returns:
        list of ((min, max), (r, g, b, a)) intervals
    """
    intervals = []
    # Transparent below data range
    intervals.append(((- 32768, stops[0][0] - 1), (0, 0, 0, 0)))
    
    for i in range(len(stops) - 1):
        v0, c0 = stops[i]
        v1, c1 = stops[i + 1]
        
        for j in range(steps_per_segment):
            t0 = j / steps_per_segment
            t1 = (j + 1) / steps_per_segment
            
            seg_start = round(v0 + (v1 - v0) * t0)
            seg_end = round(v0 + (v1 - v0) * t1)
            
            t_mid = (t0 + t1) / 2.0
            r = round(c0[0] + (c1[0] - c0[0]) * t_mid)
            g = round(c0[1] + (c1[1] - c0[1]) * t_mid)
            b = round(c0[2] + (c1[2] - c0[2]) * t_mid)
            a = round(c0[3] + (c1[3] - c0[3]) * t_mid)
            
            intervals.append(((seg_start, seg_end), (r, g, b, a)))
    
    # Transparent above data range
    intervals.append(((stops[-1][0] + 1, 32767), (0, 0, 0, 0)))
    return intervals


def _centered_diverging_colormap(
    negative_colors, neutral_color, positive_colors, neutral_radius, positive_breaks
):
    """Build mirrored integer intervals with a neutral class centered on zero."""
    if len(negative_colors) != len(positive_colors):
        raise ValueError("Diverging colormap sides must contain the same number of colors")
    if len(positive_breaks) != len(positive_colors):
        raise ValueError("Positive breaks must bound every positive color")
    if neutral_radius < 0 or positive_breaks[0] <= neutral_radius:
        raise ValueError("Positive breaks must start above the neutral interval")

    data_max = positive_breaks[-1]
    intervals = [((-32768, -data_max - 1), (0, 0, 0, 0))]

    positive_ranges = []
    range_start = neutral_radius + 1
    for range_end in positive_breaks:
        positive_ranges.append((range_start, range_end))
        range_start = range_end + 1

    for color, positive_range in zip(negative_colors, reversed(positive_ranges)):
        intervals.append(((-positive_range[1], -positive_range[0]), color))

    intervals.append(((-neutral_radius, neutral_radius), neutral_color))

    for positive_range, color in zip(positive_ranges, positive_colors):
        intervals.append((positive_range, color))

    intervals.append(((data_max + 1, 32767), (0, 0, 0, 0)))
    return intervals


# SOC change: percentage change in soil organic carbon (-100% to +100%)
_soc_stops = [
    (-100, (155, 39, 121, 255)),
    (-50,  (196, 131, 155, 255)),
    (-10,  (224, 187, 213, 255)),
    (0,    (247, 247, 247, 255)),
    (10,   (211, 236, 207, 255)),
    (50,   (127, 191, 123, 255)),
    (100,  (0, 101, 0, 255)),
]

# LDN net change by unit: percentage × 100 (-10000 to +10000). These colors
# match LDN_LEGENDS[:net_change_by_unit] in backend/db/data/ldn/seed.rb.
_net_change_negative_colors = [
    (155, 39, 121, 255),
    (168, 75, 135, 255),
    (181, 111, 149, 255),
    (193, 131, 158, 255),
    (196, 147, 155, 255),
    (205, 163, 168, 255),
    (212, 179, 181, 255),
    (219, 195, 194, 255),
    (224, 187, 213, 255),
    (232, 205, 216, 255),
]
_net_change_neutral_color = (247, 247, 247, 255)
_net_change_positive_colors = [
    (237, 243, 229, 255),
    (225, 239, 218, 255),
    (211, 236, 206, 255),
    (192, 228, 181, 255),
    (166, 217, 155, 255),
    (141, 203, 130, 255),
    (115, 188, 104, 255),
    (90, 173, 79, 255),
    (65, 158, 53, 255),
    (0, 101, 0, 255),
]
# Divide -10000..10000 into 21 approximately equal-width classes. The center
# class spans -4.76%..+4.76%, with ten mirrored classes on either side.
_net_change_neutral_radius = 476
_net_change_positive_breaks = [1428, 2380, 3333, 4285, 5238, 6190, 7143, 8095, 9047, 10000]
_net_change_colormap = _centered_diverging_colormap(
    _net_change_negative_colors,
    _net_change_neutral_color,
    _net_change_positive_colors,
    _net_change_neutral_radius,
    _net_change_positive_breaks,
)

# Register all custom colormaps
custom_cmap = default_cmap.register({
    # Continuous: SOC change (interpolated)
    "ra_soc_change": _interpolate_colormap(_soc_stops, steps_per_segment=5),
    # Diverging LDN net change by unit with a neutral interval centered on zero
    "ra_net_change": _net_change_colormap,
    # Versioned alias prevents stale browser and CDN tiles after style updates
    "ra_net_change_v2": _net_change_colormap,
})


# Create cog tiler with custom colormap dependency so registered
# colormaps are available via ?colormap_name=<name>
ColorMapParams = create_colormap_dependency(custom_cmap)
cog = TilerFactory(colormap_dependency=ColorMapParams)

# Create FastAPI app
app = FastAPI(title="Resilience COG tiler", description="Cloud Optimized GeoTIFF")

app.include_router(cog.router, tags=["Cloud Optimized GeoTIFF"])

# Middleware ordering note (Starlette applies add_middleware in reverse):
# The LAST add_middleware call becomes the OUTERMOST user middleware.
# To ensure CORS headers appear on ALL responses (including error responses
# from inner middleware), CORSMiddleware must be the outermost user middleware.
# Therefore CORSMiddleware is added LAST here.
#
# Execution order (outer → inner):
#   ServerErrorMiddleware → CORSMiddleware → CacheControlMiddleware
#     → BucketWhitelistMiddleware → [RollbarMiddleware →] ExceptionMiddleware → Router

# Add Rollbar middleware innermost so it captures application-level errors
if _rollbar_token:
    app.add_middleware(RollbarMiddleware)

# Add bucket whitelist middleware
# Returns JSONResponse on denial (never raises) so the outer CORSMiddleware
# can add CORS headers to the error response.
app.add_middleware(BucketWhitelistMiddleware)

app.add_middleware(
	CacheControlMiddleware,
	cachecontrol="public, max-age=3600",
	cachecontrol_max_http_code=400,
	exclude_path={r"/healthz"},
)
# CORSMiddleware added LAST → outermost user middleware → wraps all responses
app.add_middleware(
	CORSMiddleware,
	allow_credentials=True,
	allow_origin_regex=r'https?://((([\w]*)\.)*resilienceatlas\.org|localhost(:([\d])*)?)',
	allow_methods=["GET", "POST"],
	allow_headers=["*"],
	max_age=3600,
)

add_exception_handlers(app, DEFAULT_STATUS_CODES)

# In Starlette, handlers registered for the `Exception` class (including the one
# in DEFAULT_STATUS_CODES) are routed to ServerErrorMiddleware, which sits OUTSIDE
# CORSMiddleware.  As a result, any unhandled exception that reaches
# ServerErrorMiddleware would produce a 500 response without CORS headers, causing
# the browser to report a CORS error instead of the real status code.
#
# Fix: replace the generic Exception handler (set by add_exception_handlers above)
# with one that manually adds the CORS headers before the response is emitted.
_CORS_ORIGIN_RE = re.compile(
    r'https?://((([\w]*)\.)*resilienceatlas\.org|localhost(:([\d])*)?)'
)


@app.exception_handler(Exception)
async def _exception_with_cors_handler(request: Request, exc: Exception) -> JSONResponse:
    """Catch-all handler registered with ServerErrorMiddleware.

    Because Starlette routes Exception/500 handlers to ServerErrorMiddleware (outside
    CORSMiddleware), we must add CORS headers manually here so the browser receives
    them on 500 responses and can read the error detail.
    """
    origin = request.headers.get("origin", "")
    cors_headers: dict[str, str] = {}
    if _CORS_ORIGIN_RE.fullmatch(origin):
        cors_headers["Access-Control-Allow-Origin"] = origin
        cors_headers["Access-Control-Allow-Credentials"] = "true"
        cors_headers["Vary"] = "Origin"
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error"},
        headers=cors_headers if cors_headers else None,
    )


# Add health check


@app.get("/healthz", description="Health Check", tags=["Health Check"])
def ping():
	"""Health check."""
	return {"ping": "pong!"}


# Create Mangum handler that can be used by AWS Lambda
handler = Mangum(app, lifespan="off")
