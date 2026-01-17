import logging
import os
import re
from urllib.parse import urlparse
from mangum import Mangum
from titiler.core.factory import TilerFactory
from titiler.core.errors import DEFAULT_STATUS_CODES, add_exception_handlers
from titiler.core.middleware import CacheControlMiddleware
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, HTTPException, Query, Request
from starlette.middleware.base import BaseHTTPMiddleware

logging.getLogger("mangum.lifespan").setLevel(logging.ERROR)
logging.getLogger("mangum.http").setLevel(logging.ERROR)
logging.getLogger("rio-tiler").setLevel(logging.ERROR)

# Whitelisted cloud storage buckets (AWS S3 and Google Cloud Storage)
# Format: comma-separated URIs with scheme prefix, e.g. "s3://bucket1,gs://bucket2"
# Set via ALLOWED_BUCKETS environment variable
# This is required - deployment will fail if not configured via TITILER_ALLOWED_BUCKETS GitHub variable
_allowed_buckets_raw = os.environ.get("ALLOWED_BUCKETS", "").split(",")
_allowed_buckets_raw = [b.strip() for b in _allowed_buckets_raw if b.strip()]

if not _allowed_buckets_raw:
    raise ValueError(
        "ALLOWED_BUCKETS environment variable is required. "
        "Set the TITILER_ALLOWED_BUCKETS GitHub variable with comma-separated bucket URIs "
        "(e.g., 's3://my-bucket,gs://my-gcs-bucket')."
    )

# Parse bucket URIs into (provider, bucket_name) tuples
# Supported formats: s3://bucket-name, gs://bucket-name
ALLOWED_BUCKETS: dict[str, set[str]] = {"s3": set(), "gs": set()}

for bucket_uri in _allowed_buckets_raw:
    if bucket_uri.startswith("s3://"):
        bucket_name = bucket_uri[5:].strip("/")
        if bucket_name:
            ALLOWED_BUCKETS["s3"].add(bucket_name)
    elif bucket_uri.startswith("gs://"):
        bucket_name = bucket_uri[5:].strip("/")
        if bucket_name:
            ALLOWED_BUCKETS["gs"].add(bucket_name)
    else:
        raise ValueError(
            f"Invalid bucket URI format: '{bucket_uri}'. "
            "Must start with 's3://' or 'gs://' (e.g., 's3://my-bucket' or 'gs://my-gcs-bucket')."
        )

if not ALLOWED_BUCKETS["s3"] and not ALLOWED_BUCKETS["gs"]:
    raise ValueError(
        "No valid buckets configured. "
        "Set TITILER_ALLOWED_BUCKETS with URIs like 's3://my-bucket,gs://my-gcs-bucket'."
    )


def _format_allowed_buckets() -> str:
    """Format allowed buckets for display in error messages."""
    buckets = []
    for bucket in ALLOWED_BUCKETS["s3"]:
        buckets.append(f"s3://{bucket}")
    for bucket in ALLOWED_BUCKETS["gs"]:
        buckets.append(f"gs://{bucket}")
    return ", ".join(sorted(buckets))


def is_url_allowed(url: str) -> bool:
    """Check if the URL is from an allowed cloud storage bucket.
    
    Validates against strict URL patterns for AWS S3 and Google Cloud Storage
    to prevent spoofing. Checks both the provider and bucket name.
    """
    if not url:
        return False
    
    parsed = urlparse(url)
    
    # AWS S3 URL formats:
    # - s3://bucket-name/key
    # - https://bucket-name.s3.amazonaws.com/key
    # - https://bucket-name.s3.region.amazonaws.com/key
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
        return bucket in ALLOWED_BUCKETS["s3"]
    
    # Native GCS scheme
    if parsed.scheme == "gs":
        bucket = parsed.netloc
        return bucket in ALLOWED_BUCKETS["gs"]
    
    if parsed.scheme in ("http", "https"):
        host = parsed.netloc.lower()
        
        # Remove port if present
        if ":" in host:
            host = host.split(":")[0]
        
        # === AWS S3 URL patterns ===
        
        # Virtual-hosted style: bucket-name.s3.amazonaws.com or bucket-name.s3.region.amazonaws.com
        # Pattern ensures host ENDS with .amazonaws.com (no suffix allowed)
        s3_virtual_hosted_pattern = re.compile(
            r'^(?P<bucket>[a-z0-9][a-z0-9.-]+[a-z0-9])\.s3(\.(?P<region>[a-z0-9-]+))?\.amazonaws\.com$'
        )
        match = s3_virtual_hosted_pattern.match(host)
        if match:
            bucket = match.group('bucket')
            return bucket in ALLOWED_BUCKETS["s3"]
        
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
                return bucket in ALLOWED_BUCKETS["s3"]
        
        # === Google Cloud Storage URL patterns ===
        
        # GCS path-style: storage.googleapis.com/bucket-name/key
        # Pattern ensures host is EXACTLY storage.googleapis.com
        if host == "storage.googleapis.com":
            path_parts = parsed.path.strip("/").split("/")
            if path_parts and path_parts[0]:
                bucket = path_parts[0]
                return bucket in ALLOWED_BUCKETS["gs"]
        
        # GCS authenticated URL style: storage.cloud.google.com/bucket-name/key
        # Pattern ensures host is EXACTLY storage.cloud.google.com
        if host == "storage.cloud.google.com":
            path_parts = parsed.path.strip("/").split("/")
            if path_parts and path_parts[0]:
                bucket = path_parts[0]
                return bucket in ALLOWED_BUCKETS["gs"]
    
    # Reject all other URL formats
    return False


class BucketWhitelistMiddleware(BaseHTTPMiddleware):
    """Middleware to restrict access to whitelisted cloud storage buckets only.
    
    Supports AWS S3 and Google Cloud Storage buckets.
    """
    
    async def dispatch(self, request: Request, call_next):
        # Skip health check
        if request.url.path == "/healthz":
            return await call_next(request)
        
        # Check the 'url' query parameter
        url_param = request.query_params.get("url")
        if url_param and not is_url_allowed(url_param):
            raise HTTPException(
                status_code=403,
                detail=f"Access denied. Only whitelisted cloud storage buckets are allowed. "
                       f"Allowed buckets: {_format_allowed_buckets()}"
            )
        
        return await call_next(request)


# Create cog tiler
cog = TilerFactory()

# Create FastAPI app
app = FastAPI(title="Resilience COG tiler", description="Cloud Optimized GeoTIFF")

app.include_router(cog.router, tags=["Cloud Optimized GeoTIFF"])

# Add bucket whitelist middleware (must be added before other middlewares)
# Supports both AWS S3 and Google Cloud Storage buckets
app.add_middleware(BucketWhitelistMiddleware)

app.add_middleware(
	CacheControlMiddleware,
	cachecontrol="public, max-age=3600",
	cachecontrol_max_http_code=400,
	exclude_path={r"/healthz"},
)
app.add_middleware(
	CORSMiddleware,
	allow_credentials=True,
	allow_origin_regex='https?://(((\w*)\.)*vitalsigns.org|((\w*)\.)*resilienceatlas.org|localhost(:(\d)*)?)',
	allow_methods=["GET", "POST"],
	allow_headers=["*"],
	max_age=3600,
)

add_exception_handlers(app, DEFAULT_STATUS_CODES)


# Add health check


@app.get("/healthz", description="Health Check", tags=["Health Check"])
def ping():
	"""Health check."""
	return {"ping": "pong!"}


# Create Mangum handler that can be used by AWS Lambda
handler = Mangum(app, lifespan="off")
