# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it privately by emailing **dev@crook3d.com**. Do not open a public issue.

You should receive a response within 72 hours. Please include:

- A description of the vulnerability
- Steps to reproduce
- Any potential impact

## Scope

This project handles Discord bot tokens and message routing. Security-relevant areas include:

- **Bot token storage and access** (`~/.claude/channels/discord/.env`)
- **Access control logic** in `server.ts` (the `gate()` function and allowlist enforcement)
- **Routing filter** — ensuring messages are delivered only to the intended session
- **Pairing flow** — the mechanism that grants Discord users access to the bot

## Out of Scope

- Vulnerabilities in Discord itself, discord.js, or the MCP SDK
- Issues requiring physical access to the machine running the bot
- Social engineering attacks against Discord server members
