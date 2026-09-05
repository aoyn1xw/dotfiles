#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
tests_run=0

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail_test() {
  printf '[test] FAIL: %s\n' "$*" >&2
  exit 1
}

pass_test() {
  tests_run=$((tests_run + 1))
  printf '[test] PASS: %s\n' "$1"
}

assert_contains() {
  local output="$1"
  local expected="$2"

  case "$output" in
    *"$expected"*) ;;
    *) fail_test "Expected output to contain: ${expected}" ;;
  esac
}

assert_not_contains() {
  local output="$1"
  local unexpected="$2"

  case "$output" in
    *"$unexpected"*) fail_test "Output exposed or unexpectedly contained: ${unexpected}" ;;
    *) ;;
  esac
}

make_mock_command() {
  local directory="$1"
  local command_name="$2"
  local output="$3"
  local exit_code="${4:-0}"

  mkdir -p -- "$directory"
  printf '#!/usr/bin/env bash\nprintf '\''%%s\\n'\'' '\''%s'\''\nexit %s\n' "$output" "$exit_code" >"${directory}/${command_name}"
  chmod +x -- "${directory}/${command_name}"
}

make_mock_failure() {
  local directory="$1"
  local command_name="$2"
  local output="$3"
  local exit_code="$4"

  mkdir -p -- "$directory"
  printf '#!/usr/bin/env bash\nprintf '\''%%s\\n'\'' '\''%s'\'' >&2\nexit %s\n' "$output" "$exit_code" >"${directory}/${command_name}"
  chmod +x -- "${directory}/${command_name}"
}

make_healthy_environment() {
  local mock_bin="$1"

  make_mock_command "$mock_bin" codex 'codex-cli 1.0.0'
  make_mock_command "$mock_bin" agy 'agy 1.0.0'
  make_mock_command "$mock_bin" opencode '1.0.0'
  make_mock_command "$mock_bin" npm '10.0.0'
  make_mock_command "$mock_bin" curl 'curl must not be invoked' 97
}

test_installer_is_idempotent_and_secret_safe() {
  local case_root="${TEST_ROOT}/idempotent"
  local mock_bin="${case_root}/bin"
  local home="${case_root}/home"
  local config_home="${case_root}/config"
  local secret='test-openrouter-secret-value'
  local output
  local destination="${config_home}/opencode/opencode.json"
  local rerun_message

  make_healthy_environment "$mock_bin"
  mkdir -p -- "$home"

  if ! output="$(HOME="$home" XDG_CONFIG_HOME="$config_home" PATH="${mock_bin}:/usr/bin:/bin" OPENROUTER_API_KEY="$secret" bash "${REPO_DIR}/install.sh" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail_test 'First mocked installation failed.'
  fi

  assert_contains "$output" '[antigravity] Already installed: agy 1.0.0'
  assert_contains "$output" 'Antigravity: installed'
  assert_contains "$output" 'OpenRouter:  secret available'
  assert_not_contains "$output" "$secret"
  if [[ -L "$destination" ]]; then
    [[ "$(readlink -f -- "$destination")" == "$(readlink -f -- "${REPO_DIR}/config/opencode/opencode.json")" ]] || fail_test 'OpenCode config points to the wrong source.'
    rerun_message='OpenCode configuration is already linked.'
  elif cmp -s -- "$destination" "${REPO_DIR}/config/opencode/opencode.json"; then
    # Git Bash can emulate `ln -s` by copying when Windows symlinks are unavailable.
    rerun_message='OpenCode configuration already exists at'
  else
    fail_test 'OpenCode config was not installed correctly.'
  fi

  if ! output="$(HOME="$home" XDG_CONFIG_HOME="$config_home" PATH="${mock_bin}:/usr/bin:/bin" OPENROUTER_API_KEY="$secret" bash "${REPO_DIR}/install.sh" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail_test 'Second mocked installation failed.'
  fi

  assert_contains "$output" "$rerun_message"
  assert_not_contains "$output" "$secret"
  pass_test 'installer reruns safely and does not disclose the secret'
}

test_existing_config_is_preserved() {
  local case_root="${TEST_ROOT}/existing-config"
  local mock_bin="${case_root}/bin"
  local home="${case_root}/home"
  local config_home="${case_root}/config"
  local destination="${config_home}/opencode/opencode.json"
  local output

  make_healthy_environment "$mock_bin"
  mkdir -p -- "$home" "$(dirname -- "$destination")"
  printf 'keep-me\n' >"$destination"

  if ! output="$(HOME="$home" XDG_CONFIG_HOME="$config_home" PATH="${mock_bin}:/usr/bin:/bin" bash "${REPO_DIR}/install.sh" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail_test 'Installation with an existing config failed.'
  fi

  [[ "$(<"$destination")" == 'keep-me' ]] || fail_test 'Existing OpenCode config was modified.'
  assert_contains "$output" 'leaving it unchanged'
  pass_test 'existing OpenCode config is preserved'
}

test_antigravity_installer_uses_agy() {
  local case_root="${TEST_ROOT}/agy-detection"
  local mock_bin="${case_root}/bin"
  local output

  make_mock_command "$mock_bin" agy 'agy 1.0.0'
  make_mock_command "$mock_bin" curl 'curl must not be invoked' 97

  if ! output="$(PATH="${mock_bin}:/usr/bin:/bin" bash "${REPO_DIR}/scripts/install-antigravity.sh" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail_test 'Antigravity installer did not recognize agy.'
  fi

  assert_contains "$output" '[antigravity] Already installed: agy 1.0.0'
  assert_not_contains "$output" 'curl must not be invoked'
  pass_test 'Antigravity installation is detected through agy'
}

test_download_failure_propagates() {
  local case_root="${TEST_ROOT}/download-failure"
  local mock_bin="${case_root}/bin"
  local output

  make_mock_failure "$mock_bin" curl 'simulated download failure' 42

  if output="$(PATH="${mock_bin}:/usr/bin:/bin" bash "${REPO_DIR}/scripts/install-antigravity.sh" 2>&1)"; then
    fail_test 'Antigravity installer succeeded after a simulated download failure.'
  fi

  assert_contains "$output" 'simulated download failure'
  pass_test 'download failures propagate to the caller'
}

test_missing_npm_is_reported() {
  local empty_bin="${TEST_ROOT}/missing-npm/bin"
  local output

  mkdir -p -- "$empty_bin"
  if output="$(PATH="$empty_bin" "$BASH" "${REPO_DIR}/scripts/install-codex.sh" 2>&1)"; then
    fail_test 'Codex installer succeeded without npm.'
  fi

  assert_contains "$output" 'npm is required'
  pass_test 'missing installer dependencies are reported'
}

test_doctor_detects_healthy_and_broken_commands() {
  local case_root="${TEST_ROOT}/doctor"
  local mock_bin="${case_root}/bin"
  local home="${case_root}/home"
  local config_home="${case_root}/config"
  local secret='doctor-secret-value'
  local output

  make_healthy_environment "$mock_bin"
  mkdir -p -- "$home" "${config_home}/opencode"
  ln -s -- "${REPO_DIR}/config/opencode/opencode.json" "${config_home}/opencode/opencode.json"

  if ! output="$(HOME="$home" XDG_CONFIG_HOME="$config_home" PATH="${mock_bin}:/usr/bin:/bin" OPENROUTER_API_KEY="$secret" bash "${REPO_DIR}/scripts/doctor.sh" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail_test 'Doctor rejected a healthy mocked environment.'
  fi

  assert_contains "$output" 'Finished with 0 error(s)'
  assert_not_contains "$output" "$secret"

  make_mock_command "$mock_bin" agy 'simulated broken agy' 9
  if output="$(HOME="$home" XDG_CONFIG_HOME="$config_home" PATH="${mock_bin}:/usr/bin:/bin" OPENROUTER_API_KEY="$secret" bash "${REPO_DIR}/scripts/doctor.sh" 2>&1)"; then
    fail_test 'Doctor accepted an agy command with a broken version check.'
  fi

  assert_contains "$output" "'agy --version' failed"
  assert_not_contains "$output" "$secret"
  pass_test 'doctor distinguishes healthy and broken commands without exposing secrets'
}

test_installer_is_idempotent_and_secret_safe
test_existing_config_is_preserved
test_antigravity_installer_uses_agy
test_download_failure_propagates
test_missing_npm_is_reported
test_doctor_detects_healthy_and_broken_commands

printf '[test] Completed %d test(s).\n' "$tests_run"
