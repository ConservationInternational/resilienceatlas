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

    If session_attributes are absent or carry an unknown role, all mutations are denied.
    """

    _VALID_ROLES = frozenset({"superadmin", "admin", "staff", "contributor"})

    def __init__(self, session_attributes: dict):
        role = session_attributes.get("admin_role", "")
        self.role = role if role in self._VALID_ROLES else ""
        raw = session_attributes.get("allowed_site_scope_ids")
        if not self.role:
            # No valid session — deny all mutations
            self.allowed_site_scope_ids: set[str] | None = set()
        elif raw is None or raw == "*":
            self.allowed_site_scope_ids = None  # None = all scopes
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
        if not self.role:
            return "Access denied: no valid session. Use the admin chat interface."
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
    try:
        matrix, documents = load_embeddings()
    except Exception as exc:
        # Embeddings index not yet built — return a helpful message so the agent
        # can continue without RAG context instead of crashing.
        logger.warning("retrieve_context: embeddings unavailable (%s)", exc)
        return json.dumps({
            "available": False,
            "message": (
                "The knowledge base is not yet available (embeddings not built). "
                "Skip retrieve_context and proceed directly: use list_layers to search for "
                "existing layers, get_layer to inspect a specific layer's configuration."
            ),
        })
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


def _condense_layers(layers: list[dict]) -> list[dict]:
    return [
        {
            "id": l.get("id"),
            "name": l.get("name"),
            "slug": l.get("slug"),
            "layer_provider": l.get("layer_provider"),
            "published": l.get("published"),
            "description": l.get("description") or "",
            "dataset_shortname": l.get("dataset_shortname") or "",
            "dataset_source_url": l.get("dataset_source_url") or "",
        }
        for l in layers
    ]


def handle_list_layers(params: dict, auth: AuthContext) -> str:
    site_scope_id = params.get("site_scope_id")
    keyword = params.get("keyword")

    # Authorization: validate the requested scope is in the user's allowed set.
    if site_scope_id is not None:
        if not auth.can_access_site_scope(site_scope_id):
            return json.dumps({"success": False, "message": f"Access denied: not authorized for site scope {site_scope_id}."})

        p: dict = {"per_page": 200, "site_scope_id": site_scope_id}
        if keyword:
            p["keyword"] = keyword
        result = rails_get("/api/admin/layers", params=p)
        return json.dumps(_condense_layers(result.get("data", [])), ensure_ascii=False)

    # No scope specified — restrict non-superadmins to their allowed scopes.
    if not auth.is_superadmin and auth.allowed_site_scope_ids is not None:
        if not auth.allowed_site_scope_ids:
            return json.dumps({"success": False, "message": "Access denied: no site scopes assigned to your account."})
        # Fetch each allowed scope and merge deduplicated results.
        all_layers: list[dict] = []
        seen_ids: set = set()
        for sid in auth.allowed_site_scope_ids:
            p = {"per_page": 200, "site_scope_id": sid}
            if keyword:
                p["keyword"] = keyword
            for layer in rails_get("/api/admin/layers", params=p).get("data", []):
                lid = layer.get("id")
                if lid not in seen_ids:
                    seen_ids.add(lid)
                    all_layers.append(layer)
        return json.dumps(_condense_layers(all_layers), ensure_ascii=False)

    # Superadmin (or allowed_site_scope_ids is None = all scopes): pass through.
    p = {"per_page": 200}
    if keyword:
        p["keyword"] = keyword
    result = rails_get("/api/admin/layers", params=p)
    return json.dumps(_condense_layers(result.get("data", [])), ensure_ascii=False)


def handle_get_layer(params: dict, auth: AuthContext) -> str:
    layer_id = params.get("layer_id")
    slug = params.get("slug")

    # Resolve slug → id if only slug is provided
    if not layer_id and slug:
        matches = rails_get("/api/admin/layers", params={"keyword": slug}).get("data", [])
        exact = [l for l in matches if l.get("slug") == slug]
        if not exact:
            return json.dumps({"success": False, "message": f"No layer found with slug '{slug}'."})
        layer_id = exact[0]["id"]

    if not layer_id:
        return json.dumps({"success": False, "message": "Provide either layer_id or slug."})

    result = rails_get(f"/api/admin/layers/{layer_id}")
    layer = result.get("data", {})

    # Authorization: non-superadmins may only read layers in their allowed scopes.
    # site_scope_ids is included by the Rails show action (many-to-many via layer_groups).
    if not auth.is_superadmin:
        scope_ids = layer.get("site_scope_ids") or []
        if scope_ids and not any(auth.can_access_site_scope(sid) for sid in scope_ids):
            return json.dumps({"success": False, "message": "Access denied: not authorized for this layer's site scope."})
    # Return the most useful fields for the agent to reason about
    summary = {
        "id": layer.get("id"),
        "name": layer.get("name"),
        "slug": layer.get("slug"),
        "layer_provider": layer.get("layer_provider"),
        "published": layer.get("published"),
        "description": layer.get("description"),
        "dataset_shortname": layer.get("dataset_shortname"),
        "dataset_source_url": layer.get("dataset_source_url"),
        "layer_config": layer.get("layer_config"),
        "interaction_config": layer.get("interaction_config"),
        "zoom_min": layer.get("zoom_min"),
        "zoom_max": layer.get("zoom_max"),
        "opacity": layer.get("opacity"),
        "analysis_suitable": layer.get("analysis_suitable"),
        "color": layer.get("color"),
    }
    return json.dumps(summary, ensure_ascii=False)


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

    # Discard any caller-supplied site_scope_id — not trusted for authorization.
    params.pop("site_scope_id", None)

    # Fast-path: reject entirely if no valid role (avoids an unnecessary API fetch).
    if not auth.role:
        return json.dumps({"success": False, "message": "Access denied: no valid session. Use the admin chat interface."})

    # For non-superadmins: fetch the layer's real site scopes and verify access.
    # Layer has a many-to-many relationship with site_scopes (no direct site_scope_id
    # column). The Rails show action returns site_scope_ids as an array.
    # We do NOT trust any caller-supplied site_scope_id.
    if not auth.is_superadmin:
        try:
            layer_resp = rails_get(f"/api/admin/layers/{layer_id}")
        except requests.HTTPError as exc:
            if exc.response is not None and exc.response.status_code == 404:
                return json.dumps({"success": False, "message": f"Layer {layer_id} not found."})
            raise
        scope_ids = (layer_resp.get("data") or {}).get("site_scope_ids") or []
        if scope_ids:
            if not any(auth.can_access_site_scope(sid) for sid in scope_ids):
                return json.dumps({
                    "success": False,
                    "message": f"Access denied: your account is not authorized for any site scope of layer {layer_id}.",
                })
        else:
            # Layer has no site scopes assigned — only superadmins may update it.
            return json.dumps({
                "success": False,
                "message": f"Access denied: layer {layer_id} has no site scope assigned. Ask a superadmin to assign it first.",
            })

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
    if not auth.role:
        return json.dumps({"success": False, "message": "Access denied: no valid session. Use the admin chat interface."})
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
    "get_layer": handle_get_layer,
    "list_site_scopes": handle_list_site_scopes,
    "create_layer": handle_create_layer,
    "update_layer": handle_update_layer,
    "import_vector_table": handle_import_vector_table,
}


def parse_parameters(raw_params: list[dict]) -> dict:
    """Convert Bedrock parameters array to a flat dict."""
    return {p["name"]: p["value"] for p in (raw_params or [])}


def parse_api_body_params(event: dict) -> dict:
    """Extract parameters from API-schema action group requestBody."""
    try:
        props = (
            event.get("requestBody", {})
            .get("content", {})
            .get("application/json", {})
            .get("properties", [])
        )
        return {p["name"]: p["value"] for p in (props or [])}
    except (AttributeError, TypeError):
        return {}


def make_response(event: dict, body_text: str) -> dict:
    action_group = event.get("actionGroup", "")
    api_path = event.get("apiPath", "")
    http_method = event.get("httpMethod", "POST")
    function = event.get("function", "")

    if api_path:
        # API-schema-based action group response format
        return {
            "messageVersion": "1.0",
            "response": {
                "actionGroup": action_group,
                "apiPath": api_path,
                "httpMethod": http_method,
                "httpStatusCode": 200,
                "responseBody": {
                    "application/json": {"body": body_text},
                },
            },
            "sessionAttributes": event.get("sessionAttributes", {}),
            "promptSessionAttributes": event.get("promptSessionAttributes", {}),
        }
    else:
        # Function-based action group response format
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

    # API-schema groups send apiPath; function-based groups send function name
    api_path = event.get("apiPath", "")
    function_name = event.get("function", "")

    # Derive the handler key from whichever is present
    if api_path:
        # Strip leading slash: "/list_layers" -> "list_layers"
        handler_key = api_path.lstrip("/")
        # Parameters come from requestBody for API-schema groups
        params = parse_api_body_params(event)
        # Also merge any top-level parameters array
        params.update(parse_parameters(event.get("parameters", [])))
    else:
        handler_key = function_name
        params = parse_parameters(event.get("parameters", []))

    auth = AuthContext(event.get("sessionAttributes", {}))

    action_fn = ACTION_HANDLERS.get(handler_key)
    if action_fn is None:
        return make_response(event, f"Unknown action: {handler_key}")

    try:
        result_text = action_fn(params, auth)
        return make_response(event, result_text)
    except requests.HTTPError as exc:
        error_text = f"API error {exc.response.status_code}: {exc.response.text[:500]}"
        logger.error("Action %s failed: %s", handler_key, error_text)
        return make_response(event, error_text)
    except Exception as exc:
        logger.exception("Unexpected error in action %s", handler_key)
        return make_response(event, f"Error: {exc}")
