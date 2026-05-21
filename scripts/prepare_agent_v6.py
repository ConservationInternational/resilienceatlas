"""Prepare Bedrock agent and promote to a new version, routing the main alias to it."""
import boto3
import time

session = boto3.Session(profile_name='resilienceatlas')
ba = session.client('bedrock-agent', region_name='us-east-1')
AGENT_ID = 'HVRFXWWYPV'
ALIAS_ID = 'U73SCJSG4W'
AG_ID    = 'DIODBQFLE0'

schema_path = r"c:\Users\azvol\Code\ResilienceAtlas\ResilienceAtlas\cloud_functions\ai_agent\bedrock_agent\action_group_schema.yaml"
instr_path  = r"c:\Users\azvol\Code\ResilienceAtlas\ResilienceAtlas\cloud_functions\ai_agent\bedrock_agent\agent_instructions.txt"
with open(schema_path, 'r', encoding='utf-8') as f:
    schema_yaml = f.read()
with open(instr_path, 'r', encoding='utf-8') as f:
    instructions = f.read()

# Update action group schema
ag = ba.get_agent_action_group(agentId=AGENT_ID, agentVersion='DRAFT', actionGroupId=AG_ID)['agentActionGroup']
ba.update_agent_action_group(
    agentId=AGENT_ID,
    agentVersion='DRAFT',
    actionGroupId=AG_ID,
    actionGroupName=ag['actionGroupName'],
    actionGroupExecutor=ag['actionGroupExecutor'],
    apiSchema={'payload': schema_yaml},
    description=ag.get('description', ''),
    actionGroupState=ag['actionGroupState'],
)
print("OK action group schema updated")

# Update agent instructions
agent_resp = ba.get_agent(agentId=AGENT_ID)['agent']
ba.update_agent(
    agentId=AGENT_ID,
    agentName=agent_resp['agentName'],
    instruction=instructions,
    foundationModel=agent_resp['foundationModel'],
    agentResourceRoleArn=agent_resp['agentResourceRoleArn'],
    **({'description': d} if (d := agent_resp.get('description', '')) else {}),
)
print("OK agent instructions updated")

# Prepare agent
ba.prepare_agent(agentId=AGENT_ID)
print("Preparing agent...", end='', flush=True)
for _ in range(30):
    time.sleep(5)
    status = ba.get_agent(agentId=AGENT_ID)['agent']['agentStatus']
    print(f" {status}", end='', flush=True)
    if status == 'PREPARED':
        break
print()

# Force version creation via temp alias
resp = ba.create_agent_alias(agentId=AGENT_ID, agentAliasName='temp-v6-create')
temp_alias_id = resp['agentAlias']['agentAliasId']
print(f"Temp alias: {temp_alias_id}")
time.sleep(8)

# Find the new version number
versions = ba.list_agent_versions(agentId=AGENT_ID)['agentVersionSummaries']
versioned = [v for v in versions if v['agentVersion'] != 'DRAFT']
versioned.sort(key=lambda v: int(v['agentVersion']))
new_version = versioned[-1]['agentVersion']
print(f"New version: {new_version}")

# Clean up temp alias
ba.delete_agent_alias(agentId=AGENT_ID, agentAliasId=temp_alias_id)
print("Temp alias deleted")

# Route main alias to new version
ba.update_agent_alias(
    agentId=AGENT_ID,
    agentAliasId=ALIAS_ID,
    agentAliasName='live-staging',
    routingConfiguration=[{'agentVersion': new_version}]
)
print(f"OK alias {ALIAS_ID} now routes to version {new_version}")
