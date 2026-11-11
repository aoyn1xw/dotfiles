#!/usr/bin/env bash
set -euo pipefail

# The official installer links `agent` (and `cursor-agent`) into ~/.local/bin.
export PATH="${HOME}/.local/bin:${HOME}/bin:${PATH}"

if command -v agent >/dev/null 2>&1; then
  printf '[cursor] Already installed: '
  agent --version || printf 'version unavailable\n'
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  printf '[cursor] ERROR: curl is required by the official Cursor CLI installer.\n' >&2
  exit 1
fi

printf '[cursor] Installing with the official Cursor CLI install script...\n'
curl https://cursor.com/install -fsS | bash

if ! command -v agent >/dev/null 2>&1; then
  printf '[cursor] ERROR: installation completed but agent is not on PATH.\n' >&2
  exit 1
fi
printf '[cursor] Installed: '
agent --version || printf 'version unavailable\n'
