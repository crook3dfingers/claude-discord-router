#!/usr/bin/env bash
set -euo pipefail

# Install the discord-router plugin to ~/.claude/plugins/local/discord-router

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="${HOME}/.claude/plugins/local/discord-router"

echo "Installing discord-router plugin..."

mkdir -p "$PLUGIN_DIR/.claude-plugin"

cp -r "$REPO_DIR/server/"* "$PLUGIN_DIR/"
cp "$REPO_DIR/server/.mcp.json" "$PLUGIN_DIR/"
cp "$REPO_DIR/server/.npmrc" "$PLUGIN_DIR/" 2>/dev/null || true
cp "$REPO_DIR/server/.claude-plugin/plugin.json" "$PLUGIN_DIR/.claude-plugin/"

rm -rf "$PLUGIN_DIR/skills" 2>/dev/null || true
cp -r "$REPO_DIR/skills" "$PLUGIN_DIR/"

(cd "$PLUGIN_DIR" && bun install --no-summary 2>/dev/null)

echo "Installed to ${PLUGIN_DIR}"
echo "Restart Claude Code to load the updated plugin."
