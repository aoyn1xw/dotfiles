#!/usr/bin/env bash
set -euo pipefail

if command -v agy >/dev/null 2>&1; then
  printf '[antigravity] Already installed: '
  agy --version || printf 'version unavailable\n'
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  printf '[antigravity] ERROR: curl is required by the official Antigravity CLI installer.\n' >&2
  exit 1
fi

printf '[antigravity] Installing with the official Antigravity CLI install script...\n'
curl -fsSL https://antigravity.google/cli/install.sh | bash

if ! command -v agy >/dev/null 2>&1; then
  printf '[antigravity] ERROR: installation completed but agy is not on PATH.\n' >&2
  exit 1
fi
printf '[antigravity] Installed: '
agy --version || printf 'version unavailable\n'
