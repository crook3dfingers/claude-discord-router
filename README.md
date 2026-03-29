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

The setup script walks you through:
1. Creating a Discord bot
2. Saving your bot token
3. Installing the plugin
4. Configuring your first project and channel

## How It Works

A routing config at `~/.claude/channels/discord/routing.json` maps project directories to channel IDs:

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

When Claude Code starts in a project directory, the plugin reads `CLAUDE_PROJECT_DIR`, looks it up in `routing.json`, and delivers only messages from matching channels. Non-matching messages are dropped.

- **`channels`** — Array of Discord channel IDs this project listens to
- **`dm`** — Set to `true` on exactly one project to receive DMs. If omitted or `false`, DMs are not delivered to that session

### Graceful Fallback

If `routing.json` doesn't exist, or a project has no entry, the plugin delivers all messages — matching standard Discord plugin behavior.

## Adding More Projects

```bash
./scripts/add-project.sh /home/you/github/new-project 1234567890123456789
```

Add `--dm` if this project should receive DMs:

```bash
./scripts/add-project.sh /home/you/github/main-project 1234567890123456789 --dm
```

Or edit `~/.claude/channels/discord/routing.json` directly. Changes take effect on the next inbound message — no restart needed.

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

### 3. Install the Plugin

```bash
./scripts/install.sh
```

If you were previously using the marketplace Discord plugin, disable it to avoid duplicate connections:

```bash
mv ~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/discord/.mcp.json \
   ~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/discord/.mcp.json.disabled
```

### 4. Create Routing Config

```bash
cp templates/routing.json.example ~/.claude/channels/discord/routing.json
# Edit with your project paths and channel IDs
```

### 5. Set Up Access Control

The bot uses an allowlist to control who can talk to it. On first run:

1. Start Claude Code in one of your project directories
2. DM your bot on Discord — it replies with a pairing code
3. Run `/discord:access pair <code>` in Claude Code to approve yourself
4. Run `/discord:access policy allowlist` to lock it down

### 6. Get Channel IDs

In Discord: **Settings → Advanced → Developer Mode** (on). Then right-click any channel → **Copy Channel ID**.

## Configuration Reference

### routing.json

Lives at `~/.claude/channels/discord/routing.json`. Maps absolute project directory paths to channel routing:

| Field | Type | Description |
|-------|------|-------------|
| `channels` | `string[]` | Discord channel IDs (snowflakes) this project listens to |
| `dm` | `boolean` | Whether this project receives DMs. Only one project should set this to `true` |

### access.json

Lives at `~/.claude/channels/discord/access.json`. Controls who can talk to the bot. Managed via `/discord:access` and `/discord:configure` in Claude Code. See `skills/access/SKILL.md` for details.

## Security

- **Bot token stays local.** Stored in `~/.claude/channels/discord/.env` with `chmod 600`. Never committed, never shared.
- **Each user needs their own bot.** The plugin runs a local Discord gateway connection using the bot token. Sharing a token across users would give everyone access to all messages.
- **No changes to project repos.** All config lives in `~/.claude/`. No files are added to any project directory.
- **Channel IDs are not sensitive.** They are public snowflakes visible to anyone in the server.
- **Public Bot toggle** — In the Developer Portal under Installation, you can control whether others can invite your bot. For a personal bot, leave it off.

## Uninstalling

```bash
./scripts/uninstall.sh
```

This removes the plugin but preserves your bot token and routing config. To delete those as well:

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
- Check that the project directory path matches exactly (use `pwd` to confirm)
- Look for the `discord channel: routing →` log line in stderr when Claude Code starts

**DMs showing up everywhere**
- Make sure exactly one project has `"dm": true` in `routing.json`

**"channel not allowlisted" error when replying**
- The channel needs to be in both `routing.json` AND `access.json` groups
- Run `./scripts/add-project.sh` to update both files

**Marketplace plugin conflict**
- If you have the marketplace Discord plugin installed, disable it:
  ```bash
  mv ~/.claude/plugins/marketplaces/.../discord/.mcp.json \
     ~/.claude/plugins/marketplaces/.../discord/.mcp.json.disabled
  ```

## License

Apache-2.0 — see [LICENSE](LICENSE).
