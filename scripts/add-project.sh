#!/usr/bin/env bash
set -euo pipefail

# Add or update a project → channel mapping.
# Creates routing, access, and MCP server entries for a project.
# Usage: ./scripts/add-project.sh /path/to/project CHANNEL_ID [--dm]

STATE_DIR="${HOME}/.claude/channels/discord"
ROUTING_FILE="${STATE_DIR}/routing.json"
ACCESS_FILE="${STATE_DIR}/access.json"
CLAUDE_JSON="${HOME}/.claude.json"
PLUGIN_DIR="${HOME}/.claude/plugins/local/discord-router"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 PROJECT_DIR CHANNEL_ID [--dm]"
  echo ""
  echo "  PROJECT_DIR  Absolute path to the project directory"
  echo "  CHANNEL_ID   Discord channel ID (numeric snowflake)"
  echo "  --dm         This project should receive DMs (only one project should have this)"
  echo ""
  echo "Example:"
  echo "  $0 /home/user/github/my-project 1234567890123456789 --dm"
  echo ""
  echo "This creates:"
  echo "  - A routing entry in routing.json"
  echo "  - An access entry in access.json"
  echo "  - An MCP server entry in ~/.claude.json"
  echo ""
  echo "Launch with:"
  echo "  claude --dangerously-load-development-channels server:discord-<name>"
  exit 1
fi

PROJECT_PATH="${1%/}"  # remove trailing slash
CHANNEL_ID="$2"
DM_FLAG=false

if [[ "${3:-}" == "--dm" ]]; then
  DM_FLAG=true
fi

# Validate channel ID is numeric
if ! [[ "$CHANNEL_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: Channel ID must be numeric (Discord snowflake). Got: ${CHANNEL_ID}"
  exit 1
fi

# Derive server name from project directory basename
SERVER_NAME="discord-$(basename "$PROJECT_PATH")"

mkdir -p "$STATE_DIR"

# Initialize routing.json if missing
if [[ ! -f "$ROUTING_FILE" ]]; then
  echo '{}' > "$ROUTING_FILE"
fi

# Update routing.json
python3 -c "
import json, sys
path, project, channel, dm = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == 'true'
with open(path) as f:
    config = json.load(f)
existing = config.get(project, {})
channels = existing.get('channels', [])
if channel not in channels:
    channels.append(channel)
config[project] = {'channels': channels, 'dm': dm}
with open(path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
" "$ROUTING_FILE" "$PROJECT_PATH" "$CHANNEL_ID" "$DM_FLAG"

echo "Updated routing: ${PROJECT_PATH} → channel ${CHANNEL_ID} (dm=${DM_FLAG})"

# Add channel to access.json groups if not already there
if [[ -f "$ACCESS_FILE" ]]; then
  python3 -c "
import json, sys
path, channel_id = sys.argv[1], sys.argv[2]
with open(path) as f:
    config = json.load(f)
if channel_id not in config.get('groups', {}):
    config.setdefault('groups', {})[channel_id] = {
        'requireMention': False,
        'allowFrom': []
    }
    with open(path, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
    print(f'Added channel {channel_id} to access.json groups')
else:
    print(f'Channel {channel_id} already in access.json groups')
" "$ACCESS_FILE" "$CHANNEL_ID"
fi

# Add MCP server entry in ~/.claude.json
python3 -c "
import json, sys, os
claude_json = sys.argv[1]
server_name = sys.argv[2]
plugin_dir = sys.argv[3]
project_path = sys.argv[4]
config = {}
if os.path.exists(claude_json):
    with open(claude_json) as f:
        config = json.load(f)
servers = config.setdefault('mcpServers', {})
servers[server_name] = {
    'command': 'bun',
    'args': ['run', '--cwd', plugin_dir, '--shell=bun', '--silent', 'start'],
    'env': {'CLAUDE_PROJECT_DIR': project_path}
}
with open(claude_json, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
print(f'Added MCP server \"{server_name}\" to {claude_json}')
" "$CLAUDE_JSON" "$SERVER_NAME" "$PLUGIN_DIR" "$PROJECT_PATH"

echo ""
echo "Launch with:"
echo "  claude --dangerously-load-development-channels server:${SERVER_NAME}"
echo ""
echo "Routing takes effect immediately (no restart needed for existing sessions)."
echo "New sessions need the server flag above."
