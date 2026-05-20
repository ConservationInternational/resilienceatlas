"""
Embedding Sync Lambda
Fetches all layer records from the Rails admin API + loads knowledge base JSON docs,
generates embeddings with Titan Embeddings V2, and saves the index to S3.

Invoke: EventBridge schedule (daily) or manual.
"""
import json
import logging
import os
from typing import Any

import boto3
import numpy as np
import requests

logger = logging.getLogger()
logger.setLevel(logging.INFO)

RAILS_API_URL = os.environ["RAILS_API_URL"]        # e.g. https://api.resilienceatlas.org
_sm = boto3.client("secretsmanager", region_name=os.environ.get("AWS_REGION", "us-east-1"))


def _load_api_key() -> str:
    secret_arn = os.environ.get("RESILIENCE_API_KEY_SECRET_ARN")
    if secret_arn:
        return _sm.get_secret_value(SecretId=secret_arn)["SecretString"]
    return os.environ["RESILIENCE_API_KEY"]


RAILS_API_KEY = _load_api_key()
EMBEDDINGS_BUCKET = os.environ["EMBEDDINGS_BUCKET"]
EMBEDDINGS_KEY = os.environ.get("EMBEDDINGS_KEY", "ai_agent/embeddings.npy")
INDEX_KEY = os.environ.get("INDEX_KEY", "ai_agent/layer_index.json")
KB_BUCKET = os.environ.get("KB_BUCKET", EMBEDDINGS_BUCKET)
KB_PREFIX = os.environ.get("KB_PREFIX", "ai_agent/knowledge_base/")
TITAN_MODEL_ID = "amazon.titan-embed-text-v2:0"
EMBED_DIMENSION = 1024

s3 = boto3.client("s3")
bedrock = boto3.client("bedrock-runtime", region_name=os.environ.get("AWS_REGION", "us-east-1"))


def get_embedding(text: str) -> list[float]:
    body = json.dumps({"inputText": text[:8000], "dimensions": EMBED_DIMENSION, "normalize": True})
    resp = bedrock.invoke_model(modelId=TITAN_MODEL_ID, body=body, contentType="application/json")
    return json.loads(resp["body"].read())["embedding"]


def fetch_all_layers() -> list[dict]:
    headers = {"Authorization": f"Bearer {RAILS_API_KEY}"}
    all_layers = []
    page = 1
    while True:
        resp = requests.get(
            f"{RAILS_API_URL}/api/admin/layers",
            headers=headers,
            params={"page": page, "per_page": 100},
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
        batch = data.get("data", [])
        all_layers.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    logger.info("Fetched %d layers from Rails API", len(all_layers))
    return all_layers


def layer_to_text(layer: dict) -> str:
    """Summarise a layer record as a string for embedding."""
    parts = [
        f"Layer: {layer.get('name', '')}",
        f"Slug: {layer.get('slug', '')}",
        f"Provider: {layer.get('layer_provider', '')}",
        f"Description: {layer.get('description') or ''}",
        f"Published: {layer.get('published', True)}",
        f"ZoomMin: {layer.get('zoom_min', 0)} ZoomMax: {layer.get('zoom_max', 100)}",
    ]
    legend = layer.get("legend") or ""
    if legend:
        parts.append(f"Legend: {legend[:200]}")
    return " | ".join(p for p in parts if p.split(": ", 1)[1])


def load_kb_docs() -> list[dict]:
    """Load all knowledge base JSON files from S3."""
    docs = []
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=KB_BUCKET, Prefix=KB_PREFIX):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if not key.endswith(".json"):
                continue
            body = s3.get_object(Bucket=KB_BUCKET, Key=key)["Body"].read()
            doc = json.loads(body)
            docs.append(doc)
    logger.info("Loaded %d knowledge base docs", len(docs))
    return docs


def doc_to_text(doc: dict) -> str:
    """Convert a KB doc to a searchable string."""
    parts = [doc.get("title", ""), doc.get("description", "")]
    if "notes" in doc:
        parts.extend(doc["notes"])
    if "usage_notes" in doc:
        parts.extend(doc["usage_notes"])
    return " ".join(str(p) for p in parts if p)[:4000]


def handler(event: dict, context: Any) -> dict:
    logger.info("Starting embedding sync")

    # Build document list
    documents = []

    # 1. Layer records
    layers = fetch_all_layers()
    for layer in layers:
        documents.append({
            "id": f"layer::{layer['id']}",
            "text": layer_to_text(layer),
            "metadata": {
                "type": "layer",
                "layer_id": layer["id"],
                "name": layer.get("name", ""),
                "slug": layer.get("slug", ""),
                "provider": layer.get("layer_provider", ""),
                "published": layer.get("published", True),
            },
        })

    # 2. Knowledge base docs
    kb_docs = load_kb_docs()
    for doc in kb_docs:
        documents.append({
            "id": doc.get("id", f"doc::{doc.get('title','')}"),
            "text": doc_to_text(doc),
            "metadata": {
                "type": "doc",
                "doc_id": doc.get("id", ""),
                "title": doc.get("title", ""),
            },
        })

    logger.info("Generating embeddings for %d documents", len(documents))

    # Generate embeddings
    embeddings = []
    for i, doc in enumerate(documents):
        try:
            emb = get_embedding(doc["text"])
            embeddings.append(emb)
        except Exception as exc:
            logger.warning("Embedding failed for %s: %s", doc["id"], exc)
            embeddings.append([0.0] * EMBED_DIMENSION)
        if (i + 1) % 50 == 0:
            logger.info("Processed %d/%d embeddings", i + 1, len(documents))

    # Save to S3
    matrix = np.array(embeddings, dtype=np.float32)
    npy_bytes = matrix.tobytes()
    # Include shape in a header comment inside the JSON index
    index_with_meta = {
        "shape": list(matrix.shape),
        "documents": documents,
    }

    s3.put_object(Bucket=EMBEDDINGS_BUCKET, Key=EMBEDDINGS_KEY, Body=npy_bytes)
    s3.put_object(
        Bucket=EMBEDDINGS_BUCKET,
        Key=INDEX_KEY,
        Body=json.dumps(index_with_meta).encode(),
        ContentType="application/json",
    )

    logger.info(
        "Saved %d embeddings (%s, shape %s) to s3://%s/%s",
        len(documents), matrix.dtype, matrix.shape, EMBEDDINGS_BUCKET, EMBEDDINGS_KEY,
    )
    return {"statusCode": 200, "body": f"Synced {len(documents)} documents"}
