#!/usr/bin/env bash
set -euo pipefail

# Remove the discord-router server and its MCP server entries.
# Does NOT delete your bot token or routing config.

PLUGIN_DIR="${HOME}/.claude/plugins/local/discord-router"
MARKETPLACE_PLUGIN="${HOME}/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/discord"
CLAUDE_JSON="${HOME}/.claude.json"

echo "Uninstalling discord-router..."

if [[ -d "$PLUGIN_DIR" ]]; then
  rm -rf "$PLUGIN_DIR"
  echo "Removed ${PLUGIN_DIR}"
else
  echo "Server not found at ${PLUGIN_DIR} — nothing to remove."
fi

# Remove all discord-* MCP server entries from ~/.claude.json
if [[ -f "$CLAUDE_JSON" ]]; then
  python3 -c "
import json, sys
path = sys.argv[1]
with open(path) as f:
    config = json.load(f)
servers = config.get('mcpServers', {})
removed = [k for k in servers if k.startswith('discord-')]
for k in removed:
    del servers[k]
if not servers and 'mcpServers' in config:
    del config['mcpServers']
with open(path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
if removed:
    print(f'Removed MCP servers from {path}: {', '.join(removed)}')
else:
    print('No discord-* MCP servers found in ' + path)
" "$CLAUDE_JSON" 2>/dev/null
fi

# Re-enable marketplace plugin if it was disabled
if [[ -f "${MARKETPLACE_PLUGIN}/.mcp.json.disabled" ]]; then
  echo ""
  read -rp "Re-enable the marketplace Discord plugin? [Y/n] " re_enable
  if [[ "${re_enable,,}" != "n" ]]; then
    mv "${MARKETPLACE_PLUGIN}/.mcp.json.disabled" "${MARKETPLACE_PLUGIN}/.mcp.json"
    echo "Marketplace plugin re-enabled."
  fi
fi

echo ""
echo "Your bot token and routing config are preserved in:"
echo "  ~/.claude/channels/discord/.env"
echo "  ~/.claude/channels/discord/routing.json"
echo ""
echo "Delete them manually if you no longer need them."
echo "Restart Claude Code to apply changes."
