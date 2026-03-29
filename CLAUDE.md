# claude-discord-router — Claude Code Development Guide

## Project Overview

`claude-discord-router` is a modified Claude Code Discord plugin that adds per-session channel routing. One Discord bot, multiple Claude Code sessions — each session only sees messages from its assigned channels.

**Core value proposition**: developers running Claude Code across multiple projects get organized Discord channels with a single bot and no per-repo configuration.

## Tech Stack

| Component | Library | Rationale |
|---|---|---|
| Runtime | **Bun** | TypeScript runtime, used by upstream Discord plugin |
| MCP SDK | **@modelcontextprotocol/sdk** | Standard MCP server protocol |
| Discord | **discord.js 14** | Stable Discord API client |
| Setup scripts | **Bash** | No additional dependencies |

## Repository Structure

```
claude-discord-router/
├── server/                    # MCP server (modified Discord plugin)
│   ├── server.ts              # Main server with routing support
│   ├── .mcp.json              # MCP launch config (passes CLAUDE_PROJECT_DIR)
│   ├── package.json           # Dependencies
│   └── .claude-plugin/        # Plugin metadata
├── skills/                    # Claude Code skills (access, configure)
├── scripts/
│   ├── install.sh             # Install plugin to ~/.claude/plugins/local/
│   ├── add-project.sh         # Add project→channel mapping
│   └── uninstall.sh           # Remove plugin
├── templates/
│   └── routing.json.example   # Example routing config
├── init.sh                    # Interactive first-time setup
├── CLAUDE.md                  # This file
├── README.md                  # User-facing documentation
└── LICENSE                    # Apache-2.0
```

## Key Files

- **`server/server.ts`** — The MCP server. Routing additions are near the top (`loadRouting()`) and in `handleInbound()`. The rest is the upstream Discord plugin unchanged.
- **`~/.claude/channels/discord/routing.json`** — Per-user routing config (not in this repo). Maps project directories to channel IDs.
- **`~/.claude/channels/discord/access.json`** — Per-user access control (not in this repo). Managed via `/discord:access`.

## Development Workflow

### Setup

```bash
cd server && bun install
```

### Testing Changes

After modifying `server/server.ts`:

```bash
./scripts/install.sh   # copies to ~/.claude/plugins/local/discord-router/
```

Then restart Claude Code to reload the plugin.

### Lint / Format

```bash
bunx biome check server/server.ts
```

### Pre-Push Checklist (MANDATORY)

1. Verify `server.ts` has no syntax errors: `bun check server/server.ts`
2. Test the plugin: install, restart Claude Code, send a message in Discord
3. Verify routing: check stderr for `discord channel: routing →` log line
4. Verify DM filtering: DMs only reach the session with `"dm": true`
5. Verify backward compat: remove `routing.json`, confirm all messages still delivered

## Code Style

- TypeScript, matching the upstream Discord plugin conventions.
- Minimal changes to `server.ts` — keep routing additions clearly separated from upstream code.
- Comments on routing additions to make them easy to find during upstream merges.
- Shell scripts: `set -euo pipefail`, use functions for reusable logic, colored output for user-facing scripts.

## Claude Code Workflow

### Agent Patterns
- Use `subagent_type=Explore` for broad codebase searches.
- Use Haiku model for background tasks (CI watching).
- Run independent searches in parallel to maximize throughput.

### Skills (`.claude/skills/`)

| Skill | Model | When to use |
|---|---|---|
| `ci-watcher.md` | Haiku, background | After every `git push` — **mandatory** |
| `doc-editor/SKILL.md` | Haiku, **foreground** | Review draft markdown for accuracy and prose quality before writing |
| `release/SKILL.md` | default, **foreground** | Tag and push a new release |

### Doc-Editor Workflow (MANDATORY for all prose)

When writing or editing README.md, CLAUDE.md, or any user-facing documentation:

1. Draft the text.
2. Call `/doc-editor` with the draft as the argument.
3. Use the cleaned prose returned by the skill in your Edit or Write.
4. Do **not** skip step 2. Do **not** stop after step 2 — continue with the write.

## Architecture Notes

### How Routing Works

1. Claude Code sets `CLAUDE_PROJECT_DIR` when launching MCP servers.
2. `.mcp.json` passes this to the server via the `env` block.
3. `loadRouting()` reads `~/.claude/channels/discord/routing.json` and returns the channel set for the current project (or `null` for no filtering).
4. At the top of `handleInbound()`, before `gate()`, the routing filter drops messages for channels this session doesn't own.
5. DMs are routed to the session with `"dm": true` in its routing entry.
6. If no routing config exists, all messages are delivered (backward compatible).

### Why the Filter Goes Before gate()

`gate()` has side effects — it creates pairing entries and writes to `access.json`. Messages destined for another session should never trigger those side effects.

### Relationship to Upstream Plugin

This repo contains a full copy of the Discord MCP plugin with routing additions. The upstream plugin lives in the Claude Code marketplace. When upstream updates, diff `server.ts` against the marketplace version and merge changes, preserving the routing additions.

## Out of Scope (Do Not Implement Unless Asked)

- Centralized server architecture (single shared MCP server for multiple sessions).
- Exclusive channel locking (two sessions claiming the same channel both receive messages — this is by design).
- Web UI for managing routing.
- Automatic channel creation in Discord.
