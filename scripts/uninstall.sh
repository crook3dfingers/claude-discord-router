#!/usr/bin/env bash
set -euo pipefail

# Remove the discord-router plugin. Does NOT delete your bot token or routing config.

PLUGIN_DIR="${HOME}/.claude/plugins/local/discord-router"
MARKETPLACE_PLUGIN="${HOME}/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/discord"

echo "Uninstalling discord-router plugin..."

if [[ -d "$PLUGIN_DIR" ]]; then
  rm -rf "$PLUGIN_DIR"
  echo "Removed ${PLUGIN_DIR}"
else
  echo "Plugin not found at ${PLUGIN_DIR} — nothing to remove."
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
