# Universal GitHub Codespaces dotfiles

This repository bootstraps a personal coding-agent command-line environment in every new GitHub Codespace, independently of the repository opened in that Codespace. It installs:

- [OpenAI Codex CLI](https://developers.openai.com/codex/cli/) from the official `@openai/codex` npm package;
- [Google Antigravity CLI](https://antigravity.google/) using Google's official CLI install script;
- [OpenCode](https://opencode.ai/docs/) with its official install script and an OpenRouter configuration that reads `OPENROUTER_API_KEY` from the environment;
- [Cursor CLI](https://cursor.com/docs/cli/overview) using Cursor's official install script, which links the `agent` command into `$HOME/.local/bin`;
- everyday shell, git, and editor defaults for the Codespace you are working in.

The Antigravity installer uses Google's current CLI endpoint, `https://antigravity.google/cli/install.sh`. This replaces the repository's earlier Gemini CLI fallback; no npm package name is inferred for Antigravity.

## What you get day to day

`install.sh` also applies a set of defaults that only exist in the Codespace, so you do not have to reconfigure each one:

- **`~/.bashrc`** gains a marker-delimited block that puts `$HOME/.opencode/bin`, `$HOME/.local/bin`, and `$HOME/bin` back on `PATH` for new terminals, raises history to 100,000 entries, switches history to append mode so two terminals do not clobber each other, and adds aliases (`gs`, `gd`, `gl`, `gp`, `gco`, `gcm`, `gca`, `la`, `ll`, `..`, `...`, `..3`) plus `mkcd` and `gitbranch`. It deliberately does **not** override `PS1`, because the Codespaces prompt already carries useful remote context.
- **`~/.gitconfig`** gains an `[include]` pointing at `config/git/gitconfig` in this repository, which sets `init.defaultBranch=main`, `pull.rebase=true`, `push.autoSetupRemote=true`, `fetch.prune=true`, `fetch.pruneTags=true`, and `rerere.enabled=true`.
- **VS Code** gets machine settings at `~/.vscode-server/data/Machine/settings.json` with a 14px editor font, 1.5 line height, format-on-save, trimmed whitespace, and a 13px terminal font. This is a per-user path, so it applies to every Codespace without a `.devcontainer` in each project.

### Editing files the installer owns

`~/.bashrc` and `~/.gitconfig` are *not* replaced. Each install writes a single block between these markers:

```text
# >>> dotfiles managed block >>>
# <<< dotfiles managed block <<<
```

Everything outside the markers is preserved byte for byte, so rerunning `install.sh` refreshes the repository-owned settings and keeps your own edits. The block is always appended last, which means keys you add yourself with `git config --global user.name` land after it and survive every rerun.

**Keep edits outside the markers.** Anything inside them is overwritten on the next run.

Your original `~/.bashrc` and `~/.gitconfig` are copied to `~/.bashrc.pre-dotfiles` and `~/.gitconfig.pre-dotfiles` once, before the first modification.

### Set your git identity

Author identity is deliberately not committed to this public repository. Set it once per Codespace:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

`install.sh` and `scripts/doctor.sh` both warn when it is unset, because an unset identity makes `git commit` prompt — or fail outright — partway through a class.

## Enable these dotfiles

GitHub can clone a selected public or private dotfiles repository into each new Codespace and run a recognized setup script such as `install.sh`. This does not require `.devcontainer` changes in each project. See [GitHub's Codespaces dotfiles documentation](https://docs.github.com/en/codespaces/setting-your-user-preferences/personalizing-github-codespaces-for-your-account).

1. On GitHub, open **Settings → Codespaces**.
2. Under **Dotfiles**, select **Automatically install dotfiles**.
3. Choose this repository and save the setting.
4. Create a **new** Codespace for an authorized repository. Dotfiles setup runs during creation; existing Codespaces are not retroactively rebuilt.

The installer only writes beneath the user's home/configuration directories. It determines this repository's location from the script itself and never edits the checked-out project.

## Add the OpenRouter secret

1. Create an OpenRouter API key in your OpenRouter account.
2. On GitHub, open **Settings → Codespaces → Secrets → New secret**.
3. Name it exactly `OPENROUTER_API_KEY` and paste the key as its value.
4. Grant the secret access to every repository where it should be available (or select all repositories if that matches your security policy).
5. Create a new Codespace, or restart an existing one after changing secret access.

The committed OpenCode config contains only `{env:OPENROUTER_API_KEY}`. During startup OpenCode resolves that expression from the environment; the installer neither prints nor writes the secret. If a user config already exists at `${XDG_CONFIG_HOME:-~/.config}/opencode/opencode.json`, installation preserves it and prints instructions instead of overwriting it.

## Authentication that remains manual

- **Codex:** run `codex` and follow its supported ChatGPT or API-key authentication flow. Provisioning never launches login.
- **Antigravity:** run `agy` and follow Google's authentication flow. Provisioning never launches an interactive login or writes credentials to this repository.
- **OpenCode/OpenRouter:** no `/connect` is needed when the Codespaces secret is available. If it is absent, add the secret as described above and recreate/restart the Codespace.
- **Cursor:** run `agent login`, or set `CURSOR_API_KEY` as a Codespaces secret. Provisioning never launches login or writes credentials to this repository.

No OAuth sessions, API keys, `auth.json` files, or authentication caches belong in this repository.

## Test and rerun

The best end-to-end test is a brand-new Codespace for a repository with no `.devcontainer`. In its terminal, run:

```bash
command -v codex && codex --version
command -v agy && agy --version
command -v opencode && opencode --version
command -v agent && agent --version
test -n "${OPENROUTER_API_KEY:-}" && echo 'OpenRouter secret available' || echo 'OpenRouter secret missing'
```

For a single read-only health check with actionable output, run:

```bash
bash scripts/doctor.sh
```

The doctor checks prerequisites, executable paths and version commands, the OpenCode configuration, the managed blocks in `~/.bashrc` and `~/.gitconfig`, whether the git author identity is set, whether VS Code machine settings exist, whether `gh` is authenticated, and whether the OpenRouter secret is present. It never prints the secret value.

Repository checks can be run without installing or authenticating any agent CLI:

```bash
bash -n install.sh scripts/*.sh tests/*.sh
shellcheck install.sh scripts/*.sh tests/*.sh
python3 -m json.tool config/opencode/opencode.json >/dev/null
python3 -m json.tool config/vscode/settings.json >/dev/null
bash tests/test-install.sh
```

The mocked test suite covers rerun idempotency, `agy` and `agent` detection, dependency and download failures, existing-config preservation, doctor health checks, secret non-disclosure, managed-block idempotency, preservation of pre-existing `~/.bashrc` and `~/.gitconfig` content, and preservation of existing VS Code settings. GitHub Actions runs the same checks on every push and pull request.

To rerun setup manually from the dotfiles clone, locate it and execute its installer. GitHub commonly places the clone in its Codespaces persisted-share area, but the exact location is implementation-managed; this portable command finds the script without touching the project:

```bash
find /workspaces/.codespaces -path '*/dotfiles/install.sh' -type f -exec bash {} \;
```

Running `./install.sh` from a manual clone is also supported. Existing commands and the existing OpenCode link are detected, making reruns safe.

## Updating tools

The bootstrap skips tools already on `PATH` so routine shell starts stay fast. To update explicitly using each project's official channel:

```bash
npm install --global @openai/codex
curl -fsSL https://antigravity.google/cli/install.sh | bash
curl --proto '=https' --tlsv1.2 -fsSL https://opencode.ai/install | bash
agent update
```

A newly created disposable Codespace receives the current release available from those channels at creation time.

## Security notes

- Treat this repository as public: store credentials only in GitHub Codespaces secrets or the tools' interactive user-level stores.
- Limit `OPENROUTER_API_KEY` repository access to repositories that genuinely need it. A Codespace and code running inside it can read secrets authorized for that repository.
- Review third-party install scripts before use if your threat model requires pinning. This setup intentionally follows OpenCode's current official rolling installer.
- Never commit `.env`, private keys, agent state, or home-directory configuration dumps. `.gitignore` provides defense in depth, but it is not a substitute for checking commits.

## Troubleshooting

- **A command is missing:** rerun `install.sh` and read the component-specific error. Node/npm is required for Codex; `curl` is required for Antigravity, OpenCode, and Cursor CLI. Standard Codespaces images provide these prerequisites.
- **A global npm permission error occurs:** use the Codespaces image's user-managed Node installation rather than `sudo`; do not install agent CLIs as root.
- **`opencode` is installed but not found in an old shell:** start a new shell or add `$HOME/.opencode/bin` to that shell's `PATH`. The root installer includes it while validating.
- **A CLI worked during install but is missing in a new terminal:** the installers only set `PATH` for their own process. The managed block in `~/.bashrc` restores it; run `source ~/.bashrc` or rerun `install.sh` if the block is gone.
- **`git commit` prompts for a name and email:** author identity is never committed here. Run the two `git config --global` commands in *Set your git identity*.
- **VS Code settings did not apply:** if `~/.vscode-server/data/Machine/settings.json` already existed, installation left it untouched. Merge `config/vscode/settings.json` into it by hand, or delete it and rerun `install.sh`.
- **A personal edit disappeared:** edits inside the managed-block markers are overwritten on every run. Move them below the closing marker. The pre-dotfiles copies `~/.bashrc.pre-dotfiles` and `~/.gitconfig.pre-dotfiles` hold the originals.
- **`gh` is not authenticated:** run `gh auth login`. Codespaces normally pre-authenticates it, and an expired session blocks `git push`.
- **OpenRouter is not authenticated:** confirm `printenv OPENROUTER_API_KEY >/dev/null` succeeds (do not print the value), confirm the secret is authorized for the current repository, and restart or recreate the Codespace.
- **OpenCode says config already exists:** merge the `provider.openrouter.options.apiKey` setting from `config/opencode/opencode.json` into the existing file. The installer intentionally will not destroy personal configuration.
- **Dotfiles did not run:** verify the repository selection under GitHub Settings, inspect Codespace creation logs, and test with a newly created Codespace.

## Repository layout

```text
.
├── .github/workflows/test.yml
├── install.sh
├── README.md
├── config/
│   ├── git/gitconfig
│   ├── opencode/opencode.json
│   ├── shell/dotfiles.bash
│   └── vscode/settings.json
├── scripts/
│   ├── doctor.sh
│   ├── install-antigravity.sh
│   ├── install-codex.sh
│   ├── install-cursor.sh
│   ├── install-opencode.sh
│   ├── install-shell.sh
│   └── lib-managed-block.sh
└── tests/
    └── test-install.sh
```
