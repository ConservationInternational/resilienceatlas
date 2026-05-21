"""
Pipeline Lambda — triggered by S3 PUT events for new data file uploads.
Invokes the Bedrock Agent to automatically process the file and create a layer.
"""
import json
import logging
import os
import urllib.parse
import uuid
from typing import Any

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

BEDROCK_AGENT_ID = os.environ["BEDROCK_AGENT_ID"]
BEDROCK_AGENT_ALIAS_ID = os.environ["BEDROCK_AGENT_ALIAS_ID"]

bedrock_agent = boto3.client(
    "bedrock-agent-runtime", region_name=os.environ.get("AWS_REGION", "us-east-1")
)

# File extensions the agent knows how to process automatically
PROCESSABLE_EXTENSIONS = {
    ".tif", ".tiff",       # COG raster
    ".gpkg",               # GeoPackage → martin
    ".geojson", ".json",   # GeoJSON → martin
    ".zip",                # Shapefile zip → martin
    ".shp",                # Shapefile (uncommon in S3, but handled)
    ".kml",                # KML → martin
}


def get_s3_uri(bucket: str, key: str) -> str:
    return f"s3://{bucket}/{key}"


def sanitize_for_prompt(value: str) -> str:
    """Strip characters that could be used for prompt injection."""
    # Keep only printable ASCII that cannot break out of a data context
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./:@")
    return "".join(c for c in value if c in allowed)[:200]


def build_prompt(s3_uri: str, filename: str, extension: str) -> str:
    safe_uri = sanitize_for_prompt(s3_uri)
    safe_ext = sanitize_for_prompt(extension)
    # Do NOT include the raw filename — it is attacker-controlled via the S3 key
    return (
        "A new file has been uploaded to the Resilience Atlas data bucket.\n\n"
        f"S3 URI: {safe_uri}\n"
        f"File extension: {safe_ext}\n\n"
        "Task: process this file and create an appropriate layer. "
        "Start by calling retrieve_context to find the correct layer_config format. "
        "Import the file if it is a vector format (gpkg/geojson/zip/kml/shp). "
        "Create the layer with published=false. "
        "Report the created layer id and what still needs manual configuration."
    )


def stream_agent_response(response_stream) -> str:
    """Collect all chunks from the Bedrock agent response stream."""
    full_response = []
    for event in response_stream:
        chunk = event.get("chunk", {})
        if "bytes" in chunk:
            full_response.append(chunk["bytes"].decode("utf-8"))
    return "".join(full_response)


def handler(event: dict, context: Any) -> dict:
    # Handle both direct S3 events and EventBridge-wrapped S3 events
    s3_records = event.get("Records", [])
    if not s3_records and "detail" in event:
        # EventBridge format
        detail = event.get("detail", {})
        bucket = detail.get("bucket", {}).get("name")
        key = detail.get("object", {}).get("key")
        if bucket and key:
            s3_records = [{"s3": {"bucket": {"name": bucket}, "object": {"key": key}}}]

    processed = []
    skipped = []

    for record in s3_records:
        s3_info = record.get("s3", {})
        bucket = s3_info.get("bucket", {}).get("name", "")
        raw_key = s3_info.get("object", {}).get("key", "")
        key = urllib.parse.unquote_plus(raw_key)

        filename = key.split("/")[-1]
        extension = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

        if extension not in PROCESSABLE_EXTENSIONS:
            logger.info("Skipping file with unrecognised extension: %s", filename)
            skipped.append(key)
            continue

        s3_uri = get_s3_uri(bucket, key)
        prompt = build_prompt(s3_uri, filename, extension)
        session_id = str(uuid.uuid4())

        logger.info("Invoking Bedrock Agent for %s (session %s)", s3_uri, session_id)
        try:
            response = bedrock_agent.invoke_agent(
                agentId=BEDROCK_AGENT_ID,
                agentAliasId=BEDROCK_AGENT_ALIAS_ID,
                sessionId=session_id,
                inputText=prompt,
                sessionState={
                    # The pipeline is an automated process — grant superadmin scope
                    "sessionAttributes": {
                        "admin_role": "superadmin",
                        "allowed_site_scope_ids": "*",
                    }
                },
            )
            agent_response = stream_agent_response(response.get("completion", []))
            logger.info("Agent response for %s: %s", s3_uri, agent_response[:500])
            processed.append({"key": key, "session_id": session_id, "response": agent_response})
        except Exception as exc:
            logger.exception("Bedrock agent invocation failed for %s", s3_uri)
            processed.append({"key": key, "error": str(exc)})

    return {
        "statusCode": 200,
        "processed": processed,
        "skipped": skipped,
    }
