#!/usr/bin/env bash
# Shared helpers for the marker-delimited block that install.sh owns inside
# dot-managed files such as ~/.bashrc and ~/.gitconfig.
#
# This file is sourced, never executed. Sourcing it defines DOTFILES_DIR,
# the two markers, and the rewrite helpers.

# Consumed by the scripts that source this file.
# shellcheck disable=SC2034
DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

readonly MANAGED_BLOCK_BEGIN='# >>> dotfiles managed block >>>'
readonly MANAGED_BLOCK_END='# <<< dotfiles managed block <<<'

# managed_block_exists <file>
#
# Succeeds only when the file exists and carries both markers on their own
# lines. A half-written block counts as missing so callers can repair it.
managed_block_exists() {
  local target="$1"

  [[ -f "$target" ]] || return 1
  grep -qxF -- "$MANAGED_BLOCK_BEGIN" "$target" &&
    grep -qxF -- "$MANAGED_BLOCK_END" "$target"
}

# rewrite_managed_block <target-file> <snippet-file>
#
# Removes any previous managed block and appends the current snippet in its
# place. Content outside the markers is preserved, so a rerun refreshes
# repository-owned settings without discarding personal edits made after the
# block. The block is appended last, so keys a user adds afterwards with
# `git config --global` land outside it and survive later reruns.
#
# A snippet path of '-' reads the snippet body from stdin instead, for
# settings that have to be generated at install time.
rewrite_managed_block() {
  local target="$1"
  local snippet="$2"
  local temporary
  local directory

  directory="$(dirname -- "$target")"
  mkdir -p -- "$directory"

  temporary="$(mktemp)"
  if [[ -f "$target" ]]; then
    awk -v begin="$MANAGED_BLOCK_BEGIN" -v end="$MANAGED_BLOCK_END" '
      $0 == begin { skip = 1; next }
      $0 == end { skip = 0; next }
      skip == 0 { print }
    ' "$target" >"$temporary"
  fi

  printf '%s\n' "$MANAGED_BLOCK_BEGIN" >>"$temporary"
  if [[ "$snippet" == '-' ]]; then
    cat >>"$temporary"
  else
    cat -- "$snippet" >>"$temporary"
  fi

  # A snippet that does not end in a newline would run straight into the
  # closing marker and break the user's shell file, so normalise before sealing.
  if [[ -s "$temporary" ]] && [[ "$(tail -c 1 -- "$temporary")" != '' ]]; then
    printf '\n' >>"$temporary"
  fi
  printf '%s\n' "$MANAGED_BLOCK_END" >>"$temporary"

  mv -- "$temporary" "$target"
}
