# claude-discord-router

Per-project Discord channels for Claude Code. One bot, many projects — each Claude Code session gets its own Discord channel.

## What This Does

When you run Claude Code in multiple project directories, each session connects to Discord through the same bot. Without routing, every session sees every message. This plugin adds **per-session channel filtering**: messages in `#project-a` only go to the Claude Code session running in `/home/you/project-a`.

```
Discord                          Your Machine
┌──────────────┐                ┌─────────────────────────────────────┐
│ #project-a   │ ──────────────▶│ Claude Code (~/github/project-a)    │
│ #project-b   │ ──────────────▶│ Claude Code (~/github/project-b)    │
│ DMs          │ ──────────────▶│ (one session owns DMs)              │
└──────────────┘                └─────────────────────────────────────┘
        │                                    │
        └──── single Discord bot ────────────┘
```

## Quick Start

```bash
git clone https://github.com/YOUR_USER/claude-discord-router.git
cd claude-discord-router
./init.sh
```

The setup script walks you through creating a Discord bot, saving your token, installing the server, and configuring your first project.

Then launch Claude Code with the Discord channel:

```bash
claude --dangerously-load-development-channels server:discord-myproject
```

The server name is `discord-` followed by the project directory basename. For example, a project at `~/github/tarmo` gets the server name `discord-tarmo`.

## Usage

Each project gets a dedicated MCP server entry in `~/.claude.json`. Launch Claude Code with the matching server name:

```bash
claude --dangerously-load-development-channels server:discord-myproject
```

| Flag | Purpose |
|------|---------|
| `--dangerously-load-development-channels server:discord-<name>` | **Required.** Launches the Discord MCP server as a channel for this project |
| `--dangerously-skip-permissions` | Skip tool permission prompts (optional, for unattended use) |
| `--remote-control "Label"` | Enable remote control with a display label (optional) |

**Example — headless session:**

```bash
cd ~/github/my-project
claude --dangerously-load-development-channels server:discord-my-project --dangerously-skip-permissions --remote-control "My Project"
```

## How It Works

Each project gets three config entries:

1. **MCP server in `~/.claude.json`** — launches the Discord bot with `CLAUDE_PROJECT_DIR` set to the project path
2. **Routing entry in `routing.json`** — maps the project path to a Discord channel ID
3. **Access entry in `access.json`** — allows the bot to read/write in that channel

When Claude Code starts, the MCP server connects to Discord, reads `CLAUDE_PROJECT_DIR`, looks it up in `routing.json`, and delivers only messages from matching channels. Non-matching messages are dropped.

### routing.json

Lives at `~/.claude/channels/discord/routing.json`:

```json
{
  "/home/you/github/project-a": {
    "channels": ["111111111111111111"],
    "dm": true
  },
  "/home/you/github/project-b": {
    "channels": ["1234567890123456789"]
  }
}
```

- **`channels`** — Array of Discord channel IDs this project listens to
- **`dm`** — Set to `true` on exactly one project to receive DMs. If omitted or `false`, DMs are not delivered to that session

### Graceful Fallback

If `routing.json` doesn't exist, or a project has no entry, the server delivers all messages — matching standard Discord plugin behavior.

## Adding More Projects

```bash
./scripts/add-project.sh /home/you/github/new-project 1234567890123456789
```

Add `--dm` if this project should receive DMs:

```bash
./scripts/add-project.sh /home/you/github/main-project 1234567890123456789 --dm
```

This creates the routing entry, access entry, and MCP server entry in one command. It prints the `--dangerously-load-development-channels server:discord-<name>` flag to use when launching.

## Manual Setup

If you prefer to set things up without `init.sh`:

### 1. Create a Discord Bot

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application** — give it a name — Create
3. Go to **Bot** tab → **Reset Token** → copy the token
4. Enable **MESSAGE CONTENT INTENT** (scroll down on Bot page) → Save
5. Go to **Installation** tab
6. Set Install Link to **Discord Provided Link**
7. Under Default Install Settings → Guild Install:
   - Scopes: `bot`
   - Permissions: Send Messages, Read Message History, Add Reactions, Attach Files
8. Save, copy the **Install Link**, open it in your browser, add the bot to your server

### 2. Save the Token

```bash
mkdir -p ~/.claude/channels/discord
echo "DISCORD_BOT_TOKEN=your_token_here" > ~/.claude/channels/discord/.env
chmod 600 ~/.claude/channels/discord/.env
```

### 3. Install the Server

```bash
./scripts/install.sh
```

### 4. Add a Project

```bash
./scripts/add-project.sh /home/you/github/my-project 1234567890123456789 --dm
```

This creates routing, access, and MCP server entries. If you prefer to do it manually, see [Manual MCP Server Registration](#manual-mcp-server-registration).

### 5. Launch Claude Code

```bash
claude --dangerously-load-development-channels server:discord-my-project
```

### 6. Set Up Access Control

The bot uses an allowlist to control who can talk to it. On first run:

1. Start Claude Code in one of your project directories
2. DM your bot on Discord — it replies with a pairing code
3. Run `/discord:access pair <code>` in Claude Code to approve yourself
4. Run `/discord:access policy allowlist` to lock it down

### 7. Get Channel IDs

In Discord: **Settings → Advanced → Developer Mode** (on). Then right-click any channel → **Copy Channel ID**.

## Configuration Reference

### ~/.claude.json (MCP servers)

Each project gets a named MCP server entry. The server name is `discord-` followed by the project directory basename:

```json
{
  "mcpServers": {
    "discord-my-project": {
      "command": "bun",
      "args": ["run", "--cwd", "/home/you/.claude/plugins/local/discord-router", "--shell=bun", "--silent", "start"],
      "env": {
        "CLAUDE_PROJECT_DIR": "/home/you/github/my-project"
      }
    }
  }
}
```

### routing.json

Lives at `~/.claude/channels/discord/routing.json`. Maps absolute project directory paths to channel routing:

| Field | Type | Description |
|-------|------|-------------|
| `channels` | `string[]` | Discord channel IDs (snowflakes) this project listens to |
| `dm` | `boolean` | Whether this project receives DMs. Only one project should set this to `true` |

### access.json

Lives at `~/.claude/channels/discord/access.json`. Controls who can talk to the bot. Managed via `/discord:access` and `/discord:configure` in Claude Code. See `skills/access/SKILL.md` for details.

## Manual MCP Server Registration

The `add-project.sh` script handles this automatically. If you need to register manually, add a named server entry to `~/.claude.json`:

```json
{
  "mcpServers": {
    "discord-my-project": {
      "command": "bun",
      "args": ["run", "--cwd", "/home/you/.claude/plugins/local/discord-router", "--shell=bun", "--silent", "start"],
      "env": {
        "CLAUDE_PROJECT_DIR": "/home/you/github/my-project"
      }
    }
  }
}
```

The `CLAUDE_PROJECT_DIR` env var must match the project path in `routing.json` exactly. Without this entry, `--dangerously-load-development-channels server:discord-my-project` will fail with "no MCP server configured with that name".

## Security

- **Bot token stays local.** Stored in `~/.claude/channels/discord/.env` with `chmod 600`. Never committed, never shared.
- **Each user needs their own bot.** The plugin runs a local Discord gateway connection using the bot token. Sharing a token across users would give everyone access to all messages.
- **No changes to project repos.** All config lives in `~/.claude/` and `~/.claude.json`. No files are added to any project directory.
- **Channel IDs are not sensitive.** They are public snowflakes visible to anyone in the server.
- **Public Bot toggle** — In the Developer Portal under Installation, you can control whether others can invite your bot. For a personal bot, leave it off.

## Uninstalling

```bash
./scripts/uninstall.sh
```

This removes the server and all `discord-*` MCP entries from `~/.claude.json`, but preserves your bot token and routing config. To delete those as well:

```bash
rm ~/.claude/channels/discord/.env
rm ~/.claude/channels/discord/routing.json
```

## Troubleshooting

**Bot doesn't respond in a channel**
- Check that the channel ID is in `routing.json` for the correct project path
- Check that the channel ID is also in `access.json` under `groups`
- Run `/discord:configure` in Claude Code to check bot status

**Getting messages in every session**
- Verify `routing.json` exists at `~/.claude/channels/discord/routing.json`
- Check that `CLAUDE_PROJECT_DIR` is set correctly in the MCP server entry in `~/.claude.json`
- Look for the `discord channel: routing →` log line in stderr when Claude Code starts

**DMs showing up everywhere**
- Make sure exactly one project has `"dm": true` in `routing.json`

**"channel not allowlisted" error when replying**
- The channel needs to be in both `routing.json` AND `access.json` groups
- Run `./scripts/add-project.sh` to update both files

**"no MCP server configured with that name" error**
- The server is not registered in `~/.claude.json`. Run `./scripts/add-project.sh` or add the entry manually — see [Manual MCP Server Registration](#manual-mcp-server-registration)

**Marketplace plugin conflict**
- If you have the marketplace Discord plugin installed, disable it to avoid duplicate bot connections:
  ```bash
  mv ~/.claude/plugins/marketplaces/.../discord/.mcp.json \
     ~/.claude/plugins/marketplaces/.../discord/.mcp.json.disabled
  ```

## License

Apache-2.0 — see [LICENSE](LICENSE).
