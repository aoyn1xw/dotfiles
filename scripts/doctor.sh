#!/usr/bin/env bash
set -uo pipefail

export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${HOME}/bin:${PATH}"

# Provides DOTFILES_DIR, the managed-block markers, and managed_block_exists.
# shellcheck source=scripts/lib-managed-block.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-managed-block.sh"

failures=0
warnings=0

ok() {
  printf '[doctor] OK: %s\n' "$*"
}

warn() {
  printf '[doctor] WARN: %s\n' "$*"
  warnings=$((warnings + 1))
}

fail() {
  printf '[doctor] ERROR: %s\n' "$*" >&2
  failures=$((failures + 1))
}

check_dependency() {
  local command_name="$1"
  local path

  if path="$(command -v -- "$command_name" 2>/dev/null)"; then
    ok "Dependency ${command_name} is available at ${path}."
  else
    fail "Dependency ${command_name} is missing."
  fi
}

check_cli() {
  local label="$1"
  local command_name="$2"
  local path
  local version

  if ! path="$(command -v -- "$command_name" 2>/dev/null)"; then
    fail "${label} command '${command_name}' is missing."
    return
  fi

  if version="$("$command_name" --version 2>&1)"; then
    version="${version%%$'\n'*}"
    if [[ -z "$version" ]]; then
      version='version output was empty'
    fi
    ok "${label}: ${version} (${path})."
  else
    fail "${label} is at ${path}, but '${command_name} --version' failed."
  fi
}

check_opencode_config() {
  local source="${DOTFILES_DIR}/config/opencode/opencode.json"
  local destination="${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/opencode.json"
  local source_target
  local destination_target

  if [[ -L "$destination" ]]; then
    source_target="$(readlink -f -- "$source" 2>/dev/null || true)"
    destination_target="$(readlink -f -- "$destination" 2>/dev/null || true)"
    if [[ -n "$source_target" && "$destination_target" == "$source_target" ]]; then
      ok "OpenCode configuration is linked to the repository config."
    else
      warn "OpenCode configuration symlink points elsewhere: ${destination}."
    fi
  elif [[ -e "$destination" ]]; then
    warn "OpenCode uses an existing user-managed config at ${destination}; verify its OpenRouter settings manually."
  else
    fail "OpenCode configuration is missing at ${destination}; rerun install.sh."
  fi
}

check_gh_auth() {
  if ! command -v gh >/dev/null 2>&1; then
    fail 'gh is missing, so push and pull authentication cannot be verified.'
    return
  fi

  if gh auth status >/dev/null 2>&1; then
    ok 'gh is authenticated.'
  else
    fail 'gh is installed but not authenticated; run: gh auth login'
  fi
}

check_managed_block() {
  local label="$1"
  local target="$2"

  if managed_block_exists "$target"; then
    ok "${label} carries the managed block."
  else
    fail "${label} has no managed block at ${target}; rerun install.sh."
  fi
}

check_shell_exports() {
  local target="${HOME}/.bashrc"

  if [[ ! -f "$target" ]]; then
    return
  fi
  if grep -qF -- '${HOME}/.opencode/bin' "$target"; then
    ok 'The managed block keeps the agent CLI directories on PATH.'
  else
    warn "The managed block in ${target} no longer exports the agent CLI PATH."
  fi
}

check_git_identity() {
  if ! command -v git >/dev/null 2>&1; then
    warn 'git is not on PATH, so the author identity cannot be checked.'
    return
  fi

  if git config --global --get user.name >/dev/null 2>&1 &&
    git config --global --get user.email >/dev/null 2>&1; then
    ok 'Git author identity is configured.'
  else
    warn 'Git author identity is unset; commits will prompt or fail.'
    warn 'Run: git config --global user.name "Your Name" && git config --global user.email "you@example.com"'
  fi
}

check_vscode_settings() {
  local destination="${HOME}/.vscode-server/data/Machine/settings.json"

  if [[ -e "$destination" ]]; then
    ok "VS Code machine settings exist at ${destination}."
  else
    warn "VS Code machine settings are missing at ${destination}; rerun install.sh to adopt the repository defaults."
  fi
}

printf '[doctor] Checking Codespaces dotfiles health...\n'
check_dependency bash
check_dependency curl
check_dependency npm
check_cli 'Codex' codex
check_cli 'Antigravity' agy
check_cli 'OpenCode' opencode
check_opencode_config
check_managed_block '.bashrc' "${HOME}/.bashrc"
check_shell_exports
check_managed_block '.gitconfig' "${HOME}/.gitconfig"
check_git_identity
check_vscode_settings
check_gh_auth

if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
  ok 'OPENROUTER_API_KEY is available (value not displayed).'
else
  warn 'OPENROUTER_API_KEY is missing; add it as a Codespaces secret to use OpenRouter.'
fi

printf '[doctor] Finished with %d error(s) and %d warning(s).\n' "$failures" "$warnings"
if ((failures > 0)); then
  exit 1
fi
