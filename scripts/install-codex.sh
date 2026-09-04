#!/usr/bin/env bash
set -euo pipefail

if command -v codex >/dev/null 2>&1; then
  printf '[codex] Already installed: '
  codex --version || printf 'version unavailable\n'
  exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
  printf '[codex] ERROR: npm is required by the official Codex installer.\n' >&2
  exit 1
fi

printf '[codex] Installing the official @openai/codex npm package...\n'
npm install --global @openai/codex

if ! command -v codex >/dev/null 2>&1; then
  printf '[codex] ERROR: installation completed but codex is not on PATH.\n' >&2
  exit 1
fi
printf '[codex] Installed: '
codex --version || printf 'version unavailable\n'
