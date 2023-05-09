import logging
from mangum import Mangum
from titiler.core.factory import TilerFactory
from titiler.core.middleware import CacheControlMiddleware
from titiler.core.errors import DEFAULT_STATUS_CODES, add_exception_handlers

from fastapi import FastAPI, HTTPException, Query

logging.getLogger("mangum.lifespan").setLevel(logging.ERROR)
logging.getLogger("mangum.http").setLevel(logging.ERROR)


# def MosaicPathParams(
#     mosaic: str = Query(..., description="mosaic name")
# ) -> str:
#     """Create dataset path from args"""
#     # mosaic name should be in form of `{user}.{layername}`
#     if not re.match(self.mosaic, r"^[a-zA-Z0-9-_]{1,32}\.[a-zA-Z0-9-_]{1,32}$"):
#         raise HTTPException(
#             status_code=400,
#             detail=f"Invalid mosaic name {self.input}.",
#         )

#         return f"{MOSAIC_BACKEND}{MOSAIC_HOST}/{self.input}.json.gz"


# Create FastAPI app
app = FastAPI(title="Resilience COG tiler", description="Cloud Optimized GeoTIFF")

cog = TilerFactory()
app.include_router(cog.router, tags=["Cloud Optimized GeoTIFF"])
app.add_middleware(
        CacheControlMiddleware,
        cachecontrol="public",
        cachecontrol_max_http_code=400, # https://github.com/developmentseed/titiler/pull/444
        exclude_path={r"/healthz"},
    )

add_exception_handlers(app, DEFAULT_STATUS_CODES)

# Add health check


@app.get("/healthz", description="Health Check", tags=["Health Check"])
def ping():
    """Health check."""
    return {"ping": "pong!"}


# Create Mangum handler that can be used by AWS Lambda
handler = Mangum(app, lifespan="off")
