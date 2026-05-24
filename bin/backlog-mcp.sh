#!/bin/bash
# backlog-mcp.sh — auto-install backlog-md if missing, then exec the MCP server.
#
# Claude Code launches this as the MCP server entry point (see .mcp.json).
# MCP talks JSON-RPC over stdio, so this wrapper must keep stdout pristine.
# All install noise goes to stderr.
#
# Install priority: bun > npm > brew. We try the fastest first.
#   - bun:  ~5s    (preferred — Backlog.md is built with Bun)
#   - npm:  ~15s
#   - brew: ~30s   (works on macOS without any JS runtime)
#
# Once installed, `backlog mcp start` runs and stays attached for the session.

set -eu

log() { printf '[backlog-mcp] %s\n' "$*" >&2; }

if command -v backlog >/dev/null 2>&1; then
  exec backlog mcp start
fi

log "backlog CLI not found — attempting one-time install..."

if command -v bun >/dev/null 2>&1; then
  log "Installing via bun..."
  bun add -g backlog.md >&2 || { log "bun install failed"; exit 1; }
elif command -v npm >/dev/null 2>&1; then
  log "Installing via npm..."
  npm install -g backlog.md >&2 || { log "npm install failed"; exit 1; }
elif command -v brew >/dev/null 2>&1; then
  log "Installing via Homebrew..."
  brew install backlog-md >&2 || { log "brew install failed"; exit 1; }
else
  log "No installer found (bun / npm / brew). Install one and reload."
  log "  Recommended: curl -fsSL https://bun.sh/install | bash"
  exit 1
fi

if ! command -v backlog >/dev/null 2>&1; then
  log "Install reported success but 'backlog' is still not on PATH."
  log "Open a new shell so the global bin dir is picked up, or set PATH manually."
  exit 1
fi

log "Install OK — starting MCP server."
exec backlog mcp start
