"""Earth Engine Histogram Analysis Lambda Function.

Computes histogram statistics for Earth Engine assets within a given geometry.
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
        logger.info("Rollbar initialized for histogram function")
except ImportError:
    pass


def serialize_histogram(data: list[dict]) -> dict[str, Any]:
    """Serialize Earth Engine histogram result to API response format.
    
    Args:
        data: List of feature properties from EE reduceRegions result.
        
    Returns:
        dict: Serialized histogram data with rows, fields, and stats.
    """
    if not data or not data[0]:
        return {
            "rows": [],
            "fields": {},
            "total_rows": 0,
            "stats": {},
        }
    
    props = data[0].get("properties", {})
    histogram_data = props.get("histogram", {})
    
    bucket_width = histogram_data.get("bucketWidth", 1)
    bucket_min = histogram_data.get("bucketMin", 0)
    histogram_values = histogram_data.get("histogram", [])
    
    # Calculate total count for percentages
    count_sum = sum(histogram_values) if histogram_values else 1
    
    rows = [
        {
            "min": bucket_min + (bucket_width * i),
            "max": bucket_min + (bucket_width * (i + 1)),
            "count": count,
            "percent": count / count_sum if count_sum > 0 else 0,
        }
        for i, count in enumerate(histogram_values)
    ]
    
    return {
        "rows": rows,
        "fields": {
            "min": {"type": "number"},
            "max": {"type": "number"},
            "count": {"type": "number"},
            "percent": {"type": "number"},
        },
        "total_rows": len(rows),
        "stats": {
            "min": props.get("min"),
            "max": props.get("max"),
            "mean": props.get("mean"),
            "stdev": props.get("stdDev"),
            "sum": props.get("sum"),
        },
    }


def calculate_histogram(asset_id: str, geometry: dict, num_buckets: int = 20) -> Any:
    """Calculate histogram for an Earth Engine asset within a geometry.
    
    Args:
        asset_id: Earth Engine asset ID.
        geometry: GeoJSON geometry or FeatureCollection.
        num_buckets: Number of histogram buckets (default: 20).
        
    Returns:
        Earth Engine computation result.
    """
    image = ee.Image(asset_id)
    
    # Combine multiple reducers
    reducers = (
        ee.Reducer.histogram(num_buckets)
        .combine(ee.Reducer.minMax(), "", True)
        .combine(ee.Reducer.mean(), "", True)
        .combine(ee.Reducer.stdDev(), "", True)
        .combine(ee.Reducer.sum(), "", True)
    )
    
    # Create feature collection from geometry
    if "features" in geometry:
        feature_collection = ee.FeatureCollection(geometry["features"])
    else:
        feature_collection = ee.FeatureCollection([ee.Feature(ee.Geometry(geometry))])
    
    # Reduce regions
    result = image.reduceRegions(
        collection=feature_collection,
        reducer=reducers,
    ).toList(10000)
    
    return result


def handler(event: dict, context: Any) -> dict[str, Any]:
    """AWS Lambda handler for histogram analysis.
    
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
        geometry = body.get("geometry")
        num_buckets = body.get("numBuckets", 20)
        
        if not asset_id:
            return error_response(400, "Missing required parameter: assetId")
        
        if not geometry:
            return error_response(400, "Missing required parameter: geometry")
        
        # Initialize Earth Engine
        initialize_earth_engine()
        
        # Calculate histogram
        result = calculate_histogram(asset_id, geometry, num_buckets)
        result_data = result.getInfo()
        
        # Serialize and return
        response_data = serialize_histogram(result_data)
        return success_response(response_data)
        
    except ee.EEException as e:
        logger.error(f"Earth Engine error: {e}")
        if _rollbar_initialized:
            rollbar.report_exc_info()
        return error_response(500, "Earth Engine error", str(e))
    
    except json.JSONDecodeError as e:
        logger.error(f"JSON parse error: {e}")
        return error_response(400, "Invalid JSON in request body", str(e))
    
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        if _rollbar_initialized:
            rollbar.report_exc_info()
        return error_response(500, "Internal server error", str(e))
