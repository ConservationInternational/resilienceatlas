"""Exact-resource authorization for service-account-backed data reads."""

import hashlib
import hmac
import os
import re
import time


def resource_authorized(resource: str, headers: dict | None) -> bool:
    if not isinstance(resource, str) or not resource:
        return False
    public = {value.strip() for value in os.environ.get("EE_PUBLIC_ASSET_IDS", "").split(",") if value.strip()}
    if resource in public:
        return True
    secret = os.environ.get("DATA_GATEWAY_SECRET", "")
    if len(secret.encode()) < 32:
        return False
    normalized = {key.lower(): value for key, value in (headers or {}).items()}
    token = normalized.get("x-data-authorization", "")
    try:
        expires_text, digest = token.split(":", 1)
        expires = int(expires_text)
    except (ValueError, AttributeError):
        return False
    now = int(time.time())
    if not now < expires <= now + 90 or not re.fullmatch(r"[a-f0-9]{64}", digest):
        return False
    expected = hmac.new(secret.encode(), f"{expires}\n{resource}".encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, digest)
