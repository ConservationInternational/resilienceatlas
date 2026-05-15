"""Shared Earth Engine utilities for AWS Lambda functions.

Provides secure credential management via AWS Secrets Manager and
common initialization patterns for Google Earth Engine.
"""

import json
import logging
import os
from functools import lru_cache
from typing import Any

import boto3
import ee
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Cache for credentials to avoid repeated Secrets Manager calls
_ee_initialized = False


def get_gee_credentials() -> dict[str, Any]:
    """Retrieve GEE credentials from AWS Secrets Manager.
    
    Returns:
        dict: The parsed JSON credentials for the GEE service account.
        
    Raises:
        RuntimeError: If credentials cannot be retrieved.
    """
    secret_arn = os.environ.get("GEE_PRIVATE_KEY_SECRET_ARN")
    if not secret_arn:
        raise RuntimeError(
            "GEE_PRIVATE_KEY_SECRET_ARN environment variable is required"
        )
    
    try:
        client = boto3.client("secretsmanager")
        response = client.get_secret_value(SecretId=secret_arn)
        secret_string = response.get("SecretString")
        if not secret_string:
            raise RuntimeError("Secret value is empty")
        return json.loads(secret_string)
    except ClientError as e:
        logger.error(f"Failed to retrieve GEE credentials: {e}")
        raise RuntimeError(f"Failed to retrieve GEE credentials: {e}") from e
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse GEE credentials JSON: {e}")
        raise RuntimeError(f"Invalid GEE credentials format: {e}") from e


def initialize_earth_engine() -> None:
    """Initialize Earth Engine with credentials from Secrets Manager.
    
    This function is idempotent - subsequent calls will be no-ops if
    Earth Engine is already initialized.
    """
    global _ee_initialized
    
    if _ee_initialized:
        return
    
    try:
        credentials_json = get_gee_credentials()
        service_account = credentials_json.get("client_email")
        
        if not service_account:
            raise RuntimeError("Missing 'client_email' in GEE credentials")
        
        # Create credentials from the key data
        credentials = ee.ServiceAccountCredentials(
            service_account, 
            key_data=json.dumps(credentials_json)
        )
        
        ee.Initialize(credentials)
        _ee_initialized = True
        logger.info(f"Earth Engine initialized with service account: {service_account}")
        
    except Exception as e:
        logger.error(f"Failed to initialize Earth Engine: {e}")
        raise


def cors_headers(origin: str = "*") -> dict[str, str]:
    """Return standard CORS headers for API responses.
    
    Args:
        origin: The allowed origin (default: "*" for all origins).
        
    Returns:
        dict: CORS headers dictionary.
    """
    return {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
        "Access-Control-Max-Age": "3600",
        "Content-Type": "application/json",
    }


def options_response() -> dict[str, Any]:
    """Return a standard OPTIONS preflight response.
    
    Returns:
        dict: Lambda proxy response for OPTIONS requests.
    """
    return {
        "statusCode": 204,
        "headers": cors_headers(),
        "body": "",
    }


def error_response(
    status_code: int, 
    message: str, 
    details: str | None = None
) -> dict[str, Any]:
    """Return a standardized error response.
    
    Args:
        status_code: HTTP status code.
        message: Error message.
        details: Optional additional details.
        
    Returns:
        dict: Lambda proxy response with error information.
    """
    body = {"error": message}
    if details:
        body["details"] = details
    
    return {
        "statusCode": status_code,
        "headers": cors_headers(),
        "body": json.dumps(body),
    }


def success_response(data: Any, status_code: int = 200) -> dict[str, Any]:
    """Return a standardized success response.
    
    Args:
        data: Response data (will be JSON serialized).
        status_code: HTTP status code (default: 200).
        
    Returns:
        dict: Lambda proxy response with data.
    """
    return {
        "statusCode": status_code,
        "headers": cors_headers(),
        "body": json.dumps(data) if not isinstance(data, str) else data,
    }
