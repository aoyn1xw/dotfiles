#!/usr/bin/env bash
set -euo pipefail

if command -v antigravity >/dev/null 2>&1; then
  printf '[antigravity] Already installed: '
  antigravity --version || printf 'version unavailable\n'
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  printf '[antigravity] ERROR: curl is required by the official Antigravity CLI installer.\n' >&2
  exit 1
fi

printf '[antigravity] Installing with the official Antigravity CLI install script...\n'
curl -fsSL https://antigravity.google/cli/install.sh | bash

if ! command -v antigravity >/dev/null 2>&1; then
  printf '[antigravity] ERROR: installation completed but antigravity is not on PATH.\n' >&2
  exit 1
fi
printf '[antigravity] Installed: '
antigravity --version || printf 'version unavailable\n'
