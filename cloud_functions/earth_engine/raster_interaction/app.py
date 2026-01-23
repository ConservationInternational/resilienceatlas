"""Earth Engine Raster Interaction Lambda Function.

Queries raster values at a specific point from Earth Engine assets.
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
        logger.info("Rollbar initialized for raster_interaction function")
except ImportError:
    pass


def serialize_result(data: dict | None) -> dict[str, Any]:
    """Serialize Earth Engine raster query result.
    
    Args:
        data: Dictionary of band values from EE reduceRegion result.
        
    Returns:
        dict: Serialized result with rows array.
    """
    return {"rows": [data] if data else []}


def query_raster_point(asset_id: str, point: list[float]) -> Any:
    """Query raster values at a specific point.
    
    Args:
        asset_id: Earth Engine asset ID.
        point: [longitude, latitude] coordinates.
        
    Returns:
        Earth Engine computation result.
    """
    # Clean asset ID (remove any quotes)
    clean_asset_id = asset_id.replace("'", "").replace('"', "")
    
    # Create point geometry
    geometry = ee.Geometry.Point(point, "EPSG:4326")
    
    # Load image and reduce at point
    image = ee.Image(clean_asset_id)
    result = image.reduceRegion(
        reducer=ee.Reducer.first(),
        geometry=geometry,
        bestEffort=True,
        maxPixels=10e8,
        tileScale=10,
    )
    
    return result


def handler(event: dict, context: Any) -> dict[str, Any]:
    """AWS Lambda handler for raster point query.
    
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
        # Parse query parameters (GET request)
        query_params = event.get("queryStringParameters") or {}
        
        asset_id = query_params.get("asset_id")
        point_str = query_params.get("point")
        
        if not asset_id:
            return error_response(400, "Missing required parameter: asset_id")
        
        if not point_str:
            return error_response(400, "Missing required parameter: point")
        
        # Parse point coordinates
        try:
            point = json.loads(point_str)
            if not isinstance(point, list) or len(point) != 2:
                raise ValueError("Point must be [longitude, latitude]")
        except (json.JSONDecodeError, ValueError) as e:
            return error_response(
                400, 
                "Invalid point format", 
                "Expected JSON array [longitude, latitude]"
            )
        
        # Initialize Earth Engine
        initialize_earth_engine()
        
        # Query raster
        result = query_raster_point(asset_id, point)
        
        try:
            result_data = result.getInfo()
        except ee.EEException as e:
            # Asset not found or other EE error
            logger.warning(f"Could not query raster: {e}")
            # Return 404 for asset not found instead of masking the error
            if "not found" in str(e).lower() or "does not exist" in str(e).lower():
                return error_response(404, "Asset not found", str(e))
            raise
        
        # Serialize and return
        response_data = serialize_result(result_data)
        return success_response(response_data)
        
    except ee.EEException as e:
        logger.error(f"Earth Engine error: {e}")
        if _rollbar_initialized:
            rollbar.report_exc_info()
        return error_response(500, "Earth Engine error", str(e))
    
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        if _rollbar_initialized:
            rollbar.report_exc_info()
        return error_response(500, "Internal server error", str(e))
