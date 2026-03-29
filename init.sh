#!/usr/bin/env bash
set -euo pipefail

# claude-discord-router — Interactive setup script
# Creates a Discord bot, installs the routing-aware server, and configures
# per-project channel routing for Claude Code.

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="${HOME}/.claude/channels/discord"
PLUGIN_DIR="${HOME}/.claude/plugins/local/discord-router"
ROUTING_FILE="${STATE_DIR}/routing.json"
ENV_FILE="${STATE_DIR}/.env"

# Colors
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${CYAN}${BOLD}==>${NC} $1"; }
ok()    { echo -e "${GREEN}${BOLD} ✓${NC} $1"; }
warn()  { echo -e "${YELLOW}${BOLD} !${NC} $1"; }
err()   { echo -e "${RED}${BOLD} ✗${NC} $1"; }

echo ""
echo -e "${BOLD}claude-discord-router${NC} — Per-project Discord channels for Claude Code"
echo -e "${DIM}Each Claude Code session gets its own Discord channel. One bot, many projects.${NC}"
echo ""

# ─── Prerequisites ───────────────────────────────────────────────────────────

info "Checking prerequisites..."

if ! command -v claude &>/dev/null; then
  err "Claude Code not found. Install it first: https://docs.anthropic.com/en/docs/claude-code/overview"
  exit 1
fi
ok "Claude Code installed"

if ! command -v bun &>/dev/null; then
  err "Bun not found. Install it: https://bun.sh"
  exit 1
fi
ok "Bun installed"

echo ""

# ─── Discord Bot Setup ──────────────────────────────────────────────────────

if [[ -f "$ENV_FILE" ]] && grep -q 'DISCORD_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null; then
  TOKEN_PREVIEW=$(grep 'DISCORD_BOT_TOKEN=' "$ENV_FILE" | cut -d= -f2 | head -c6)
  ok "Bot token already configured (${TOKEN_PREVIEW}...)"
  echo ""
  read -rp "   Use existing token? [Y/n] " use_existing
  if [[ "${use_existing,,}" == "n" ]]; then
    NEED_TOKEN=true
  else
    NEED_TOKEN=false
  fi
else
  NEED_TOKEN=true
fi

if [[ "$NEED_TOKEN" == "true" ]]; then
  echo ""
  info "Let's set up your Discord bot. Follow these steps:"
  echo ""
  echo -e "   ${BOLD}1.${NC} Go to ${CYAN}https://discord.com/developers/applications${NC}"
  echo -e "   ${BOLD}2.${NC} Click ${BOLD}New Application${NC} → give it a name → Create"
  echo -e "   ${BOLD}3.${NC} Go to the ${BOLD}Bot${NC} tab (left sidebar)"
  echo -e "   ${BOLD}4.${NC} Click ${BOLD}Reset Token${NC} → copy the token (only shown once!)"
  echo -e "   ${BOLD}5.${NC} Scroll down and enable ${BOLD}MESSAGE CONTENT INTENT${NC} → Save"
  echo -e "   ${BOLD}6.${NC} Go to ${BOLD}Installation${NC} tab (left sidebar)"
  echo -e "   ${BOLD}7.${NC} Under Install Link, select ${BOLD}Discord Provided Link${NC}"
  echo -e "   ${BOLD}8.${NC} Under Default Install Settings → Guild Install → Scopes: select ${BOLD}bot${NC}"
  echo -e "   ${BOLD}9.${NC} Under Permissions, select:"
  echo -e "      - Send Messages"
  echo -e "      - Read Message History"
  echo -e "      - Add Reactions"
  echo -e "      - Attach Files"
  echo -e "      - Use Slash Commands"
  echo -e "  ${BOLD}10.${NC} Save Changes, then copy the ${BOLD}Install Link${NC} and open it in your browser"
  echo -e "  ${BOLD}11.${NC} Select your Discord server and authorize the bot"
  echo ""
  echo -e "   ${DIM}Tip: Keep the Developer Portal open — you'll need the Install Link.${NC}"
  echo ""
  read -rp "   Paste your bot token here: " BOT_TOKEN

  if [[ -z "$BOT_TOKEN" ]]; then
    err "No token provided. Run this script again when you have one."
    exit 1
  fi

  # Validate token format (rough check: Discord tokens are base64-ish, 59+ chars)
  if [[ ${#BOT_TOKEN} -lt 50 ]]; then
    warn "That looks short for a bot token. Discord tokens are usually 70+ characters."
    read -rp "   Continue anyway? [y/N] " confirm
    if [[ "${confirm,,}" != "y" ]]; then
      exit 1
    fi
  fi

  mkdir -p "$STATE_DIR"

  # Preserve other env vars if the file exists
  if [[ -f "$ENV_FILE" ]]; then
    grep -v '^DISCORD_BOT_TOKEN=' "$ENV_FILE" > "${ENV_FILE}.tmp" || true
    mv "${ENV_FILE}.tmp" "$ENV_FILE"
  fi
  echo "DISCORD_BOT_TOKEN=${BOT_TOKEN}" >> "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  ok "Token saved to ${ENV_FILE}"
fi

echo ""

# ─── Install Server ─────────────────────────────────────────────────────────

info "Installing discord-router server..."

mkdir -p "$PLUGIN_DIR"

# Copy server files
cp -r "$REPO_DIR/server/"* "$PLUGIN_DIR/"
cp "$REPO_DIR/server/.mcp.json" "$PLUGIN_DIR/"
cp "$REPO_DIR/server/.npmrc" "$PLUGIN_DIR/" 2>/dev/null || true
mkdir -p "$PLUGIN_DIR/.claude-plugin"
cp "$REPO_DIR/server/.claude-plugin/plugin.json" "$PLUGIN_DIR/.claude-plugin/"

# Copy skills
rm -rf "$PLUGIN_DIR/skills" 2>/dev/null || true
cp -r "$REPO_DIR/skills" "$PLUGIN_DIR/"

# Install dependencies
(cd "$PLUGIN_DIR" && bun install --no-summary 2>/dev/null)

ok "Server installed to ${PLUGIN_DIR}"

echo ""

# ─── Disable marketplace Discord plugin if present ──────────────────────────

MARKETPLACE_PLUGIN="${HOME}/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/discord"
if [[ -d "$MARKETPLACE_PLUGIN" ]]; then
  warn "Marketplace Discord plugin detected at ${MARKETPLACE_PLUGIN}"
  echo -e "   discord-router replaces it. You should disable the marketplace"
  echo -e "   version to avoid duplicate bot connections."
  echo ""
  read -rp "   Disable marketplace Discord plugin? [Y/n] " disable_marketplace
  if [[ "${disable_marketplace,,}" != "n" ]]; then
    # Rename the .mcp.json so Claude Code won't launch it
    if [[ -f "${MARKETPLACE_PLUGIN}/.mcp.json" ]]; then
      mv "${MARKETPLACE_PLUGIN}/.mcp.json" "${MARKETPLACE_PLUGIN}/.mcp.json.disabled"
      ok "Marketplace plugin disabled (renamed .mcp.json → .mcp.json.disabled)"
    fi
  fi
  echo ""
fi

# ─── Configure First Project ────────────────────────────────────────────────

info "Let's configure your first project."
echo ""

# Initialize routing.json if it doesn't exist
if [[ ! -f "$ROUTING_FILE" ]]; then
  echo '{}' > "$ROUTING_FILE"
fi

CLAUDE_JSON="${HOME}/.claude.json"

read -rp "   Project directory (absolute path, e.g. /home/you/myproject): " PROJECT_PATH

if [[ -z "$PROJECT_PATH" ]]; then
  warn "No project path provided. You can add one later with: ./scripts/add-project.sh"
else
  # Normalize: remove trailing slash
  PROJECT_PATH="${PROJECT_PATH%/}"

  if [[ ! -d "$PROJECT_PATH" ]]; then
    warn "Directory ${PROJECT_PATH} doesn't exist yet. Adding anyway."
  fi

  # Derive server name from directory basename
  SERVER_NAME="discord-$(basename "$PROJECT_PATH")"

  echo ""
  echo -e "   Now I need the Discord channel ID for this project."
  echo -e "   ${DIM}In Discord: Settings → Advanced → Developer Mode (on)${NC}"
  echo -e "   ${DIM}Then right-click the channel → Copy Channel ID${NC}"
  echo ""
  read -rp "   Channel ID: " CHANNEL_ID

  if [[ -z "$CHANNEL_ID" ]]; then
    warn "No channel ID provided. You can add one later with: ./scripts/add-project.sh"
  else
    echo ""
    read -rp "   Should this project receive DMs? [Y/n] " handle_dm
    DM_FLAG=true
    if [[ "${handle_dm,,}" == "n" ]]; then
      DM_FLAG=false
    fi

    # Update routing.json
    python3 -c "
import json, sys
path = sys.argv[1]
with open(path) as f:
    config = json.load(f)
config['${PROJECT_PATH}'] = {
    'channels': ['${CHANNEL_ID}'],
    'dm': ${DM_FLAG}
}
with open(path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
" "$ROUTING_FILE"

    ok "Added ${PROJECT_PATH} → channel ${CHANNEL_ID} (dm=${DM_FLAG})"

    # Register MCP server in ~/.claude.json
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
" "$CLAUDE_JSON" "$SERVER_NAME" "$PLUGIN_DIR" "$PROJECT_PATH"

    ok "Registered MCP server \"${SERVER_NAME}\" in ~/.claude.json"
  fi
fi

echo ""

# ─── Configure access.json ──────────────────────────────────────────────────

ACCESS_FILE="${STATE_DIR}/access.json"
if [[ ! -f "$ACCESS_FILE" ]]; then
  info "Creating default access policy..."
  cat > "$ACCESS_FILE" << 'ACCESSEOF'
{
  "dmPolicy": "pairing",
  "allowFrom": [],
  "groups": {},
  "pending": {}
}
ACCESSEOF
  ok "Created ${ACCESS_FILE} with pairing mode"
  echo ""
  echo -e "   ${BOLD}Next step:${NC} DM your bot on Discord. It will reply with a pairing code."
  echo -e "   Then run: ${CYAN}claude${NC} and use ${CYAN}/discord:access pair <code>${NC} to approve yourself."
else
  ok "Access policy already exists at ${ACCESS_FILE}"
fi

# ─── Make sure the channel is in access.json groups ─────────────────────────

if [[ -n "${CHANNEL_ID:-}" ]]; then
  python3 -c "
import json, sys
path = sys.argv[1]
channel_id = sys.argv[2]
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

echo ""

# ─── Done ────────────────────────────────────────────────────────────────────

echo -e "${GREEN}${BOLD}Setup complete!${NC}"
echo ""
echo -e "   ${BOLD}What to do next:${NC}"
echo ""
if [[ -n "${SERVER_NAME:-}" ]]; then
echo -e "   1. Start Claude Code with the Discord channel:"
echo -e "      ${CYAN}claude --dangerously-load-development-channels server:${SERVER_NAME}${NC}"
else
echo -e "   1. Add a project, then start Claude Code:"
echo -e "      ${CYAN}./scripts/add-project.sh /path/to/project CHANNEL_ID${NC}"
fi
echo -e "   2. If you haven't paired yet, DM your bot and approve with"
echo -e "      ${CYAN}/discord:access pair <code>${NC}"
echo -e "   3. Send a message in your project's Discord channel"
echo ""
echo -e "   ${BOLD}Add more projects:${NC}"
echo -e "   ${CYAN}./scripts/add-project.sh /path/to/project CHANNEL_ID${NC}"
echo ""
echo -e "   ${BOLD}Useful commands:${NC}"
echo -e "   ${CYAN}/discord:access${NC}        — manage who can talk to your bot"
echo -e "   ${CYAN}/discord:configure${NC}     — check bot status"
echo ""
