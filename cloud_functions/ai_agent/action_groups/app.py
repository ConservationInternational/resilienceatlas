"""
Action Groups Lambda for Bedrock Agent
Handles all agent tool calls:
  - retrieve_context       RAG similarity search
  - list_layers            GET /api/admin/layers
  - list_layer_groups      (via layers site_scopes endpoint)
  - list_site_scopes       GET /api/admin/layers?collection=site_scopes
  - create_layer           POST /api/admin/layers
  - update_layer           PATCH /api/admin/layers/:id
  - import_vector_table    POST /api/admin/vector_tables/import

Embeddings are loaded from S3 at cold start for fast RAG lookups.
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

RAILS_API_URL = os.environ["RAILS_API_URL"]
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
TITAN_MODEL_ID = "amazon.titan-embed-text-v2:0"
EMBED_DIMENSION = 1024
TOP_K = int(os.environ.get("RAG_TOP_K", "5"))

s3 = boto3.client("s3")
bedrock_runtime = boto3.client("bedrock-runtime", region_name=os.environ.get("AWS_REGION", "us-east-1"))

# ── Cold-start cache ─────────────────────────────────────────────────────────
_embeddings_matrix: np.ndarray | None = None
_index_documents: list[dict] | None = None


def load_embeddings() -> tuple[np.ndarray, list[dict]]:
    global _embeddings_matrix, _index_documents
    if _embeddings_matrix is not None:
        return _embeddings_matrix, _index_documents  # type: ignore[return-value]

    logger.info("Loading embeddings from S3 (cold start)")
    index_body = s3.get_object(Bucket=EMBEDDINGS_BUCKET, Key=INDEX_KEY)["Body"].read()
    index_data = json.loads(index_body)
    shape = tuple(index_data["shape"])
    documents = index_data["documents"]

    npy_body = s3.get_object(Bucket=EMBEDDINGS_BUCKET, Key=EMBEDDINGS_KEY)["Body"].read()
    matrix = np.frombuffer(npy_body, dtype=np.float32).reshape(shape)

    _embeddings_matrix = matrix
    _index_documents = documents
    logger.info("Loaded %d embeddings, shape %s", len(documents), shape)
    return matrix, documents


def get_embedding(text: str) -> np.ndarray:
    body = json.dumps({"inputText": text[:8000], "dimensions": EMBED_DIMENSION, "normalize": True})
    resp = bedrock_runtime.invoke_model(
        modelId=TITAN_MODEL_ID, body=body, contentType="application/json"
    )
    return np.array(json.loads(resp["body"].read())["embedding"], dtype=np.float32)


# ── Rails API helpers ─────────────────────────────────────────────────────────

def rails_headers() -> dict:
    return {"Authorization": f"Bearer {RAILS_API_KEY}", "Content-Type": "application/json"}


def rails_get(path: str, params: dict | None = None) -> dict:
    resp = requests.get(
        f"{RAILS_API_URL}{path}", headers=rails_headers(), params=params, timeout=30
    )
    resp.raise_for_status()
    return resp.json()


def rails_post(path: str, body: dict) -> dict:
    resp = requests.post(
        f"{RAILS_API_URL}{path}", headers=rails_headers(), json=body, timeout=30
    )
    resp.raise_for_status()
    return resp.json()


def rails_patch(path: str, body: dict) -> dict:
    resp = requests.patch(
        f"{RAILS_API_URL}{path}", headers=rails_headers(), json=body, timeout=30
    )
    resp.raise_for_status()
    return resp.json()


# ── Authorization helpers ─────────────────────────────────────────────────────

class AuthContext:
    """Decoded from Bedrock sessionAttributes set by the Rails admin chat controller.
    The pipeline Lambda sets role="superadmin" and allowed_site_scope_ids="*".

    Valid roles: superadmin, admin, staff, contributor
    - superadmin: unrestricted (all site scopes, all actions)
    - admin:      full CRUD within assigned site scopes
    - staff/contributor: CRUD within assigned site scopes; may not set published=true
    """

    def __init__(self, session_attributes: dict):
        self.role = session_attributes.get("admin_role", "admin")
        raw = session_attributes.get("allowed_site_scope_ids", "*")
        if raw == "*":
            self.allowed_site_scope_ids: set[str] | None = None  # None = all
        else:
            self.allowed_site_scope_ids = set(raw.split(",")) if raw else set()

    @property
    def is_superadmin(self) -> bool:
        return self.role == "superadmin"

    @property
    def is_contributor(self) -> bool:
        """Contributors and staff can only create layers (always published=false)."""
        return self.role in ("contributor", "staff")

    def can_access_site_scope(self, site_scope_id: str | int | None) -> bool:
        if self.is_superadmin or self.allowed_site_scope_ids is None:
            return True
        if site_scope_id is None:
            return True  # unscoped operations are allowed
        return str(site_scope_id) in self.allowed_site_scope_ids

    def assert_can_mutate(self, site_scope_id: str | int | None = None) -> str | None:
        """Returns an error string if the operation is not permitted, else None."""
        if not self.can_access_site_scope(site_scope_id):
            return (
                f"Access denied: your account is not authorized for site scope {site_scope_id}. "
                "Ask a superadmin to grant access."
            )
        return None

    def assert_can_update(self, site_scope_id: str | int | None = None) -> str | None:
        """Returns an error string if the user cannot update a layer in the given scope."""
        return self.assert_can_mutate(site_scope_id)


# ── Action handlers ───────────────────────────────────────────────────────────

def handle_retrieve_context(params: dict, _auth: AuthContext) -> str:
    query = params.get("query", "")
    top_k = int(params.get("top_k", TOP_K))
    if not query:
        return "Query is required."
    matrix, documents = load_embeddings()
    query_emb = get_embedding(query)
    scores = matrix @ query_emb
    top_indices = np.argsort(scores)[::-1][:top_k]
    results = []
    for i in top_indices:
        doc = documents[i]
        results.append({
            "id": doc["id"],
            "score": float(scores[i]),
            "text": doc["text"][:500],
            "metadata": doc["metadata"],
        })
    return json.dumps(results, ensure_ascii=False)


def handle_list_layers(params: dict, _auth: AuthContext) -> str:
    site_scope_id = params.get("site_scope_id")
    keyword = params.get("keyword")
    p = {}
    if site_scope_id:
        p["site_scope_id"] = site_scope_id
    if keyword:
        p["keyword"] = keyword
    result = rails_get("/api/admin/layers", params=p)
    layers = result.get("data", [])
    condensed = [
        {
            "id": l.get("id"),
            "name": l.get("name"),
            "slug": l.get("slug"),
            "layer_provider": l.get("layer_provider"),
            "published": l.get("published"),
        }
        for l in layers
    ]
    return json.dumps(condensed, ensure_ascii=False)


def handle_list_site_scopes(_params: dict, auth: AuthContext) -> str:
    result = rails_get("/api/admin/layers", params={"collection": "site_scopes"})
    all_scopes = result.get("data", [])
    # Non-superadmins only see their allowed scopes
    if not auth.is_superadmin and auth.allowed_site_scope_ids is not None:
        all_scopes = [s for s in all_scopes if str(s.get("id")) in auth.allowed_site_scope_ids]
    return json.dumps(all_scopes, ensure_ascii=False)


def handle_create_layer(params: dict, auth: AuthContext) -> str:
    site_scope_id = params.get("site_scope_id")

    # Site-scope authorization
    if err := auth.assert_can_mutate(site_scope_id):
        return json.dumps({"success": False, "message": err})

    layer_fields = {k: v for k, v in params.items() if k != "site_scope_id"}

    # Contributors/staff may only create unpublished layers
    if auth.is_contributor:
        layer_fields["published"] = False

    # Parse JSON string fields
    for field in ("layer_config", "interaction_config", "analysis_body"):
        if field in layer_fields and isinstance(layer_fields[field], str):
            try:
                layer_fields[field] = json.loads(layer_fields[field])
            except json.JSONDecodeError:
                pass

    # Deduplication: check if a layer with this slug already exists
    slug = layer_fields.get("slug")
    if slug:
        existing = rails_get("/api/admin/layers", params={"keyword": slug}).get("data", [])
        duplicates = [l for l in existing if l.get("slug") == slug]
        if duplicates:
            dup = duplicates[0]
            return json.dumps({
                "success": False,
                "message": f"A layer with slug '{slug}' already exists (id={dup.get('id')}). "
                           "Use update_layer to modify it, or choose a different slug.",
                "existing_layer": {"id": dup.get("id"), "name": dup.get("name"), "slug": slug},
            })

    body: dict = {"layer": layer_fields}
    if site_scope_id:
        body["site_scope_id"] = site_scope_id
    result = rails_post("/api/admin/layers", body)
    logger.info(
        "AGENT_AUDIT create_layer slug=%s provider=%s site_scope_id=%s admin_role=%s result_id=%s",
        slug, layer_fields.get("layer_provider"), site_scope_id, auth.role,
        result.get("data", {}).get("id") if isinstance(result.get("data"), dict) else None,
    )
    return json.dumps(result, ensure_ascii=False)


def handle_update_layer(params: dict, auth: AuthContext) -> str:
    layer_id = params.pop("layer_id", None) or params.pop("id", None)
    if not layer_id:
        return json.dumps({"success": False, "message": "layer_id is required"})

    # Optional site_scope_id provides authorization context (not sent to the API)
    site_scope_id = params.pop("site_scope_id", None)
    if err := auth.assert_can_update(site_scope_id):
        return json.dumps({"success": False, "message": err})

    # Contributors/staff may not publish layers
    if auth.is_contributor and params.get("published") is True:
        params["published"] = False

    # Parse JSON string fields
    for field in ("layer_config", "interaction_config", "analysis_body"):
        if field in params and isinstance(params[field], str):
            try:
                params[field] = json.loads(params[field])
            except json.JSONDecodeError:
                pass
    result = rails_patch(f"/api/admin/layers/{layer_id}", {"layer": params})
    logger.info("AGENT_AUDIT update_layer layer_id=%s admin_role=%s fields=%s",
                layer_id, auth.role, list(params.keys()))
    return json.dumps(result, ensure_ascii=False)


def handle_import_vector_table(params: dict, auth: AuthContext) -> str:
    # Contributors can import (creates data) but the subsequent create_layer call will enforce published=false
    s3_uri = params.get("s3_uri")
    table_name = params.get("table_name")
    if not s3_uri:
        return json.dumps({"success": False, "message": "s3_uri is required"})
    body: dict = {"s3_uri": s3_uri}
    if table_name:
        body["table_name"] = table_name
    result = rails_post("/api/admin/vector_tables/import", body)
    logger.info("AGENT_AUDIT import_vector_table s3_uri=%s admin_role=%s", s3_uri, auth.role)
    return json.dumps(result, ensure_ascii=False)


# ── Bedrock action group dispatcher ──────────────────────────────────────────

ACTION_HANDLERS = {
    "retrieve_context": handle_retrieve_context,
    "list_layers": handle_list_layers,
    "list_site_scopes": handle_list_site_scopes,
    "create_layer": handle_create_layer,
    "update_layer": handle_update_layer,
    "import_vector_table": handle_import_vector_table,
}


def parse_parameters(raw_params: list[dict]) -> dict:
    """Convert Bedrock parameters array to a flat dict."""
    return {p["name"]: p["value"] for p in (raw_params or [])}


def make_response(event: dict, body_text: str) -> dict:
    action_group = event.get("actionGroup", "")
    function = event.get("function", "")
    return {
        "response": {
            "actionGroup": action_group,
            "function": function,
            "functionResponse": {
                "responseBody": {"TEXT": {"body": body_text}},
            },
        },
        "sessionAttributes": event.get("sessionAttributes", {}),
        "promptSessionAttributes": event.get("promptSessionAttributes", {}),
    }


def handler(event: dict, context: Any) -> dict:
    logger.info("Action group event: %s", json.dumps(event, default=str))
    function_name = event.get("function", "")
    raw_params = event.get("parameters", [])
    params = parse_parameters(raw_params)
    auth = AuthContext(event.get("sessionAttributes", {}))

    action_fn = ACTION_HANDLERS.get(function_name)
    if action_fn is None:
        return make_response(event, f"Unknown function: {function_name}")

    try:
        result_text = action_fn(params, auth)
        return make_response(event, result_text)
    except requests.HTTPError as exc:
        error_text = f"API error {exc.response.status_code}: {exc.response.text[:500]}"
        logger.error("Action %s failed: %s", function_name, error_text)
        return make_response(event, error_text)
    except Exception as exc:
        logger.exception("Unexpected error in action %s", function_name)
        return make_response(event, f"Error: {exc}")
