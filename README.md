# Universal GitHub Codespaces dotfiles

This repository bootstraps a personal coding-agent command-line environment in every new GitHub Codespace, independently of the repository opened in that Codespace. It installs:

- [OpenAI Codex CLI](https://developers.openai.com/codex/cli/) from the official `@openai/codex` npm package;
- [Google Antigravity CLI](https://antigravity.google/) using Google's official CLI install script; and
- [OpenCode](https://opencode.ai/docs/) with its official install script and an OpenRouter configuration that reads `OPENROUTER_API_KEY` from the environment.

The Antigravity installer uses Google's current CLI endpoint, `https://antigravity.google/cli/install.sh`. This replaces the repository's earlier Gemini CLI fallback; no npm package name is inferred for Antigravity.

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

No OAuth sessions, API keys, `auth.json` files, or authentication caches belong in this repository.

## Test and rerun

The best end-to-end test is a brand-new Codespace for a repository with no `.devcontainer`. In its terminal, run:

```bash
command -v codex && codex --version
command -v agy && agy --version
command -v opencode && opencode --version
test -n "${OPENROUTER_API_KEY:-}" && echo 'OpenRouter secret available' || echo 'OpenRouter secret missing'
```

For a single read-only health check with actionable output, run:

```bash
bash scripts/doctor.sh
```

The doctor checks prerequisites, executable paths and version commands, the OpenCode configuration, and whether the OpenRouter secret is present. It never prints the secret value.

Repository checks can be run without installing or authenticating any agent CLI:

```bash
bash -n install.sh scripts/*.sh tests/*.sh
shellcheck install.sh scripts/*.sh tests/*.sh
python3 -m json.tool config/opencode/opencode.json >/dev/null
bash tests/test-install.sh
```

The mocked test suite covers rerun idempotency, `agy` detection, dependency and download failures, existing-config preservation, doctor health checks, and secret non-disclosure. GitHub Actions runs the same checks on every push and pull request.

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
```

A newly created disposable Codespace receives the current release available from those channels at creation time.

## Security notes

- Treat this repository as public: store credentials only in GitHub Codespaces secrets or the tools' interactive user-level stores.
- Limit `OPENROUTER_API_KEY` repository access to repositories that genuinely need it. A Codespace and code running inside it can read secrets authorized for that repository.
- Review third-party install scripts before use if your threat model requires pinning. This setup intentionally follows OpenCode's current official rolling installer.
- Never commit `.env`, private keys, agent state, or home-directory configuration dumps. `.gitignore` provides defense in depth, but it is not a substitute for checking commits.

## Troubleshooting

- **A command is missing:** rerun `install.sh` and read the component-specific error. Node/npm is required for Codex; `curl` is required for Antigravity and OpenCode. Standard Codespaces images provide these prerequisites.
- **A global npm permission error occurs:** use the Codespaces image's user-managed Node installation rather than `sudo`; do not install agent CLIs as root.
- **`opencode` is installed but not found in an old shell:** start a new shell or add `$HOME/.opencode/bin` to that shell's `PATH`. The root installer includes it while validating.
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
│   └── opencode/opencode.json
├── scripts/
│   ├── doctor.sh
│   ├── install-antigravity.sh
│   ├── install-codex.sh
│   └── install-opencode.sh
└── tests/
    └── test-install.sh
```
