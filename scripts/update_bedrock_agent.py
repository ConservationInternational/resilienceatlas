"""Update Bedrock agent instructions + schema and promote a new version.

Designed for CI use (reads credentials from the environment / IAM role).
Requires env vars: BEDROCK_AGENT_ID, BEDROCK_AGENT_ALIAS_ID.
Optional:         BEDROCK_AGENT_ALIAS_NAME (default: 'live-staging')
                  AWS_REGION               (default: 'us-east-1')

Run locally with an AWS profile by setting AWS_PROFILE before calling.
"""
import boto3
import json
import os
import sys
import time
from pathlib import Path

AGENT_ID   = os.environ["BEDROCK_AGENT_ID"]
ALIAS_ID   = os.environ["BEDROCK_AGENT_ALIAS_ID"]
ALIAS_NAME = os.environ.get("BEDROCK_AGENT_ALIAS_NAME", "live-staging")
REGION     = os.environ.get("AWS_REGION", "us-east-1")

REPO_ROOT    = Path(__file__).resolve().parent.parent
SCHEMA_PATH  = REPO_ROOT / "cloud_functions/ai_agent/bedrock_agent/action_group_schema.yaml"
INSTR_PATH   = REPO_ROOT / "cloud_functions/ai_agent/bedrock_agent/agent_instructions.txt"

ba = boto3.client("bedrock-agent", region_name=REGION)

# ── 1. Find the custom action group (skip Amazon built-ins) ──────────────────
summaries = ba.list_agent_action_groups(
    agentId=AGENT_ID, agentVersion="DRAFT"
)["actionGroupSummaries"]
custom = [g for g in summaries if not g["actionGroupName"].startswith("AMAZON")]
if not custom:
    print("ERROR: no custom action groups found", file=sys.stderr)
    sys.exit(1)
AG_ID = custom[0]["actionGroupId"]
print(f"Action group: {custom[0]['actionGroupName']} ({AG_ID})")

# ── 2. Update action group schema ────────────────────────────────────────────
schema_yaml = SCHEMA_PATH.read_text(encoding="utf-8")
ag = ba.get_agent_action_group(
    agentId=AGENT_ID, agentVersion="DRAFT", actionGroupId=AG_ID
)["agentActionGroup"]
ba.update_agent_action_group(
    agentId=AGENT_ID,
    agentVersion="DRAFT",
    actionGroupId=AG_ID,
    actionGroupName=ag["actionGroupName"],
    actionGroupExecutor=ag["actionGroupExecutor"],
    apiSchema={"payload": schema_yaml},
    description=ag.get("description", ""),
    actionGroupState=ag["actionGroupState"],
)
print("OK action group schema updated")

# ── 3. Update agent instructions ─────────────────────────────────────────────
instructions = INSTR_PATH.read_text(encoding="utf-8")
agent_resp = ba.get_agent(agentId=AGENT_ID)["agent"]
ba.update_agent(
    agentId=AGENT_ID,
    agentName=agent_resp["agentName"],
    instruction=instructions,
    foundationModel=agent_resp["foundationModel"],
    agentResourceRoleArn=agent_resp["agentResourceRoleArn"],
    **{"description": d} if (d := agent_resp.get("description", "")) else {},
)
print("OK agent instructions updated")

# ── 4. Prepare agent (DRAFT → PREPARED) ─────────────────────────────────────
ba.prepare_agent(agentId=AGENT_ID)
print("Preparing agent...", end="", flush=True)
for _ in range(60):
    time.sleep(5)
    status = ba.get_agent(agentId=AGENT_ID)["agent"]["agentStatus"]
    print(f" {status}", end="", flush=True)
    if status == "PREPARED":
        break
    if status in ("FAILED", "UPDATE_UNSUCCESSFUL"):
        print(f"\nERROR: agent preparation failed with status {status}", file=sys.stderr)
        sys.exit(1)
print()

# ── 5. Create a new version by making a temporary alias ──────────────────────
# Use a unique alias name per run so CI does not need bedrock:ListAgentAliases
# permission to search for and clean up a fixed temp alias.
temp_name = f"temp-promote-{int(time.time())}"

resp = ba.create_agent_alias(agentId=AGENT_ID, agentAliasName=temp_name)
temp_alias_id = resp["agentAlias"]["agentAliasId"]
print(f"Temp alias created: {temp_alias_id}, waiting for version...", end="", flush=True)

# Poll until the alias finishes CREATING and has a version in its routing config
new_version = None
for _ in range(30):
    time.sleep(5)
    alias_info = ba.get_agent_alias(agentId=AGENT_ID, agentAliasId=temp_alias_id)["agentAlias"]
    status = alias_info.get("agentAliasStatus", "")
    routing = alias_info.get("routingConfiguration", [{}])
    new_version = routing[0].get("agentVersion") if routing else None
    print(f" {status}({new_version})", end="", flush=True)
    if status not in ("CREATING", "UPDATING") and new_version:
        break
print()

if not new_version:
    print("ERROR: could not determine new version from temp alias", file=sys.stderr)
    ba.delete_agent_alias(agentId=AGENT_ID, agentAliasId=temp_alias_id)
    sys.exit(1)

print(f"New agent version: {new_version}")
ba.delete_agent_alias(agentId=AGENT_ID, agentAliasId=temp_alias_id)
print("Temp alias deleted")

# ── 6. Route the live alias to the new version ───────────────────────────────
ba.update_agent_alias(
    agentId=AGENT_ID,
    agentAliasId=ALIAS_ID,
    agentAliasName=ALIAS_NAME,
    routingConfiguration=[{"agentVersion": new_version}],
)
print(f"OK alias {ALIAS_ID} ({ALIAS_NAME}) now routes to version {new_version}")
