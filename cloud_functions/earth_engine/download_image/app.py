"""Earth Engine Download Image Lambda Function.

Generates download URLs for Earth Engine assets, optionally clipped to a geometry.
"""

import json
import logging
import os
from typing import Any

import ee

# Import shared utilities (copied into function directory during build)
from shared.ee_utils import (
    error_response,
    initialize_earth_engine,
    options_response,
    success_response,
)

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Optional Rollbar integration
_rollbar_initialized = False
try:
    import rollbar
    rollbar_token = os.environ.get("ROLLBAR_ACCESS_TOKEN")
    if rollbar_token:
        rollbar.init(
            access_token=rollbar_token,
            environment=os.environ.get("ROLLBAR_ENVIRONMENT", "development"),
            handler="blocking",
        )
        _rollbar_initialized = True
        logger.info("Rollbar initialized for download_image function")
except ImportError:
    pass


def serialize_response(url: str) -> dict[str, str]:
    """Serialize download URL response.
    
    Args:
        url: The download URL from Earth Engine.
        
    Returns:
        dict: Response with download_url key.
    """
    return {"download_url": url}


def get_geometry_from_geojson(geojson: dict) -> ee.Geometry:
    """Extract Earth Engine geometry from GeoJSON.
    
    Args:
        geojson: GeoJSON object (Geometry, Feature, or FeatureCollection).
        
    Returns:
        ee.Geometry: Earth Engine geometry object.
    """
    # Handle FeatureCollection
    if geojson.get("features"):
        first_feature = geojson["features"][0]
        coords = first_feature.get("geometry", {}).get("coordinates", [])
        return ee.Geometry.Polygon(coords)
    
    # Handle Feature
    if geojson.get("geometry"):
        return ee.Geometry(geojson["geometry"])
    
    # Handle raw Geometry
    if geojson.get("type") and geojson.get("coordinates"):
        return ee.Geometry(geojson)
    
    raise ValueError("Invalid GeoJSON format")


def generate_download_url(
    asset_id: str, 
    geometry: dict | None = None,
    scale: int | None = None,
    crs: str | None = None,
    format: str = "GEO_TIFF",
) -> str:
    """Generate a download URL for an Earth Engine image.
    
    Args:
        asset_id: Earth Engine asset ID.
        geometry: Optional GeoJSON geometry to clip the image.
        scale: Optional scale in meters per pixel.
        crs: Optional coordinate reference system (e.g., 'EPSG:4326').
        format: Download format (default: 'GEO_TIFF').
        
    Returns:
        str: Download URL.
    """
    image = ee.Image(asset_id)
    
    # Clip to geometry if provided
    if geometry:
        ee_geometry = get_geometry_from_geojson(geometry)
        image = image.clip(ee_geometry)
    
    # Build download parameters
    params = {"format": format}
    
    if scale:
        params["scale"] = scale
    
    if crs:
        params["crs"] = crs
    
    if geometry:
        params["region"] = get_geometry_from_geojson(geometry)
    
    # Get download URL
    url = image.getDownloadUrl(params)
    return url


def handler(event: dict, context: Any) -> dict[str, Any]:
    """AWS Lambda handler for image download URL generation.
    
    Args:
        event: Lambda event (API Gateway proxy format).
        context: Lambda context.
        
    Returns:
        dict: API Gateway proxy response.
    """
    # Handle OPTIONS preflight
    if event.get("httpMethod") == "OPTIONS":
        return options_response()
    
    try:
        # Parse request body
        body = event.get("body", "{}")
        if isinstance(body, str):
            body = json.loads(body)
        
        asset_id = body.get("assetId")
        geometry = body.get("geometry")  # Optional
        scale = body.get("scale")  # Optional
        crs = body.get("crs")  # Optional
        download_format = body.get("format", "GEO_TIFF")  # Optional
        
        if not asset_id:
            return error_response(400, "Missing required parameter: assetId")
        
        # Initialize Earth Engine
        initialize_earth_engine()
        
        # Generate download URL
        url = generate_download_url(
            asset_id=asset_id,
            geometry=geometry,
            scale=scale,
            crs=crs,
            format=download_format,
        )
        
        # Return response
        response_data = serialize_response(url)
        return success_response(response_data)
        
    except ee.EEException as e:
        logger.error(f"Earth Engine error: {e}")
        if _rollbar_initialized:
            rollbar.report_exc_info()
        return error_response(500, "Earth Engine error", str(e))
    
    except json.JSONDecodeError as e:
        logger.error(f"JSON parse error: {e}")
        return error_response(400, "Invalid JSON in request body", str(e))
    
    except ValueError as e:
        logger.error(f"Validation error: {e}")
        return error_response(400, "Invalid request", str(e))
    
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        if _rollbar_initialized:
            rollbar.report_exc_info()
        return error_response(500, "Internal server error", str(e))
