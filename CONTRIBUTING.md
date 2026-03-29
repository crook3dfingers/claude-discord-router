# Contributing

Thanks for your interest in contributing to claude-discord-router.

## Getting Started

1. Fork the repo and clone your fork
2. Install dependencies: `cd server && bun install`
3. Make your changes to `server/server.ts`
4. Run the linter: `bunx biome check server/server.ts`
5. Test locally: `./scripts/install.sh`, restart Claude Code, verify in Discord

## Guidelines

- **Open an issue first** for anything beyond a small fix, so we can discuss the approach.
- Keep changes to `server.ts` minimal and clearly separated from upstream Discord server code — this makes future upstream merges easier.
- Shell scripts should use `set -euo pipefail`.
- No new runtime dependencies without discussion.

## Pull Requests

- One focused change per PR.
- Include a short description of what changed and why.
- Make sure `bunx biome check server/server.ts` passes.

## License

By contributing, you agree that your contributions will be licensed under the Apache-2.0 license.
