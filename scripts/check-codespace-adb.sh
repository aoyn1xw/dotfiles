#!/usr/bin/env bash
# Run inside a Codespace after starting scripts/start-codespace-adb-tunnel.ps1 on Windows.
set -euo pipefail
port="${1:-15037}"
if ! command -v adb >/dev/null 2>&1; then
  echo 'ADB is missing. On Debian-based Codespaces: sudo apt-get update && sudo apt-get install -y adb' >&2
  exit 1
fi
echo "Checking ADB through Codespace localhost:${port} ..."
ADB_SERVER_SOCKET="tcp:127.0.0.1:${port}" adb devices -l
echo 'An empty device list is expected until an Android device is paired to Windows.'
echo "For later commands: export ADB_SERVER_SOCKET=tcp:127.0.0.1:${port}"
