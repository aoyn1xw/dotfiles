#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${HOME}/bin:${PATH}"

if command -v opencode >/dev/null 2>&1; then
  printf '[opencode] Already installed: '
  opencode --version || printf 'version unavailable\n'
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  printf '[opencode] ERROR: curl is required by the official OpenCode installer.\n' >&2
  exit 1
fi

printf '[opencode] Installing with the official OpenCode install script...\n'
curl --proto '=https' --tlsv1.2 -fsSL https://opencode.ai/install | bash

if ! command -v opencode >/dev/null 2>&1; then
  printf '[opencode] ERROR: installation completed but opencode is not on PATH.\n' >&2
  exit 1
fi
printf '[opencode] Installed: '
opencode --version || printf 'version unavailable\n'
