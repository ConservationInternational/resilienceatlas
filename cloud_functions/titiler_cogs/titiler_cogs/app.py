import logging
from mangum import Mangum
from titiler.core.factory import TilerFactory
from titiler.core.errors import DEFAULT_STATUS_CODES, add_exception_handlers
from titiler.core.middleware import CacheControlMiddleware
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, HTTPException, Query

logging.getLogger("mangum.lifespan").setLevel(logging.ERROR)
logging.getLogger("mangum.http").setLevel(logging.ERROR)
logging.getLogger("rio-tiler").setLevel(logging.ERROR)

# Create cog tiler
cog = TilerFactory()

# Create FastAPI app
app = FastAPI(title="Resilience COG tiler", description="Cloud Optimized GeoTIFF")

app.include_router(cog.router, tags=["Cloud Optimized GeoTIFF"])
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
