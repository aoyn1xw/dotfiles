#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib-managed-block.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-managed-block.sh"

log() { printf '[shell] %s\n' "$*"; }

# backup_once <file>
#
# Keeps the first pre-dotfiles copy of a file we are about to modify so a
# broken setup can be undone by hand on a machine you cannot reinstall.
backup_once() {
  local target="$1"

  if [[ ! -f "$target" ]]; then
    return 0
  fi
  if [[ -e "${target}.pre-dotfiles" ]]; then
    return 0
  fi

  cp -- "$target" "${target}.pre-dotfiles"
  log "Backed up ${target} to ${target}.pre-dotfiles."
}

install_bashrc() {
  local target="${HOME}/.bashrc"

  backup_once "$target"
  rewrite_managed_block "$target" "${DOTFILES_DIR}/config/shell/dotfiles.bash"
  log "Applied the shell block to ${target}."
  log 'Open a new terminal, or run: source ~/.bashrc'
}

install_gitconfig() {
  local target="${HOME}/.gitconfig"

  backup_once "$target"
  # The absolute include path has to be generated at install time. Feeding the
  # body through stdin keeps ~/.gitconfig a single-line-per-key include rather
  # than a duplicated copy of every setting.
  rewrite_managed_block "$target" - <<INCLUDESNIPPET
[include]
	path = "${DOTFILES_DIR}/config/git/gitconfig"
INCLUDESNIPPET
  log "Pointed ${target} at the repository git settings."
}

check_git_identity() {
  if ! command -v git >/dev/null 2>&1; then
    log 'git is not on PATH; skipping the identity check.'
    return 0
  fi

  if git config --global --get user.name >/dev/null 2>&1 &&
    git config --global --get user.email >/dev/null 2>&1; then
    log 'Git author identity is configured.'
  else
    log 'WARNING: git identity is not set, so commits will prompt or fail.'
    log 'Run: git config --global user.name "Your Name" && git config --global user.email "you@example.com"'
  fi
}

install_vscode_settings() {
  local directory="${HOME}/.vscode-server/data/Machine"
  local destination="${directory}/settings.json"

  mkdir -p -- "$directory"
  if [[ -e "$destination" || -L "$destination" ]]; then
    log "VS Code settings already exist at ${destination}; leaving them unchanged."
    log "Merge ${DOTFILES_DIR}/config/vscode/settings.json manually to adopt these defaults."
    return 0
  fi

  cp -- "${DOTFILES_DIR}/config/vscode/settings.json" "$destination"
  log "Installed VS Code machine settings at ${destination}."
}

install_bashrc
install_gitconfig
install_vscode_settings
check_git_identity
