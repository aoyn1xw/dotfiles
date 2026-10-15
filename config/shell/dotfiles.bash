# Managed by the dotfiles repository: re-run install.sh to refresh this block.
# Anything added below the closing marker is preserved; anything inside these
# markers is overwritten, so keep personal edits outside them.

# install.sh only exports PATH for its own process. Repeat it here so agent
# CLIs stay reachable in terminals opened after setup finished.
export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${HOME}/bin:${PATH}"

# Keep more scrollback than the defaults, and append rather than overwrite so
# two terminal windows do not clobber each other's history mid-session.
export HISTCONTROL='ignoreboth'
export HISTSIZE=100000
export HISTFILESIZE=200000
shopt -s histappend

# Deliberately no PS1 override: the Codespaces image prompt already carries
# useful remote and codespace context.

alias g='git'
alias gs='git status --short --branch'
alias gd='git diff'
alias gl='git pull --rebase'
alias gp='git push'
alias gco='git checkout'
alias gcm='git commit -m'
alias gca='git commit --amend --no-edit'
alias la='ls -A'
alias ll='ls -Alh'
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ..3='cd ../../..'

gitbranch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'not a git repository\n'
}

mkcd() {
  mkdir -p -- "$1" && cd -- "$1"
}
