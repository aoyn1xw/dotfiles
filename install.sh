#!/usr/bin/env bash
set -euo pipefail

# GitHub runs this file from its dotfiles clone, not from the project workspace.
DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${HOME}/bin:${PATH}"

log() { printf '[dotfiles] %s\n' "$*"; }

install_config() {
  local source="${DOTFILES_DIR}/config/opencode/opencode.json"
  local directory="${XDG_CONFIG_HOME:-${HOME}/.config}/opencode"
  local destination="${directory}/opencode.json"

  mkdir -p -- "$directory"
  if [[ -L "$destination" ]] && [[ "$(readlink -f -- "$destination")" == "$(readlink -f -- "$source")" ]]; then
    log 'OpenCode configuration is already linked.'
  elif [[ -e "$destination" || -L "$destination" ]]; then
    log "OpenCode configuration already exists at ${destination}; leaving it unchanged."
    log "Merge ${source} manually if the existing file does not configure OpenRouter."
  else
    ln -s -- "$source" "$destination"
    log "Linked OpenCode configuration to ${destination}."
  fi
}

failures=0
run_installer() {
  local name="$1"
  local script="$2"
  log "Setting up ${name}..."
  if ! "$script"; then
    printf '[dotfiles] ERROR: %s installation failed.\n' "$name" >&2
    failures=$((failures + 1))
  fi
}

run_installer 'OpenAI Codex CLI' "${DOTFILES_DIR}/scripts/install-codex.sh"
run_installer 'Google Antigravity CLI' "${DOTFILES_DIR}/scripts/install-antigravity.sh"
run_installer 'OpenCode' "${DOTFILES_DIR}/scripts/install-opencode.sh"
install_config

printf '\nCodespaces environment setup complete.\n\n'
printf 'Codex:       %s\n' "$(command -v codex >/dev/null 2>&1 && printf installed || printf missing)"
printf 'Antigravity: %s\n' "$(command -v agy >/dev/null 2>&1 && printf installed || printf missing)"
printf 'OpenCode:    %s\n' "$(command -v opencode >/dev/null 2>&1 && printf installed || printf missing)"
if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
  printf 'OpenRouter:  secret available\n'
else
  printf 'OpenRouter:  secret missing (add OPENROUTER_API_KEY as a Codespaces secret)\n'
fi

if (( failures > 0 )); then
  printf '\n[dotfiles] ERROR: %d required component(s) failed to install.\n' "$failures" >&2
  exit 1
fi
