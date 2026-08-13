#!/usr/bin/env bats
load test_helper/common

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
UNINSTALL="${FLEET_ROOT_REAL}/uninstall"

# Create a minimal self-contained fake fleet root that uninstall can operate on.
# We avoid touching the real ~/.local/bin or crontab by overriding HOME and PATH.
setup() {
  # Isolated home so symlink and cron writes don't touch the real system.
  FAKE_HOME="$(mktemp -d)"
  mkdir -p "${FAKE_HOME}/.local/bin"

  # Fleet root is a temp copy with only the files uninstall touches.
  FLEET_DIR="$(mktemp -d)"
  mkdir -p "${FLEET_DIR}/bin" "${FLEET_DIR}/.claude/skills" \
           "${FLEET_DIR}/logs" "${FLEET_DIR}/tasks" \
           "${FLEET_DIR}/scratch" "${FLEET_DIR}/results"

  # Minimal fleet binary so the symlink target resolves correctly.
  echo '#!/usr/bin/env bash' > "${FLEET_DIR}/bin/fleet"
  chmod +x "${FLEET_DIR}/bin/fleet"

  # Gitignored runtime files that uninstall should remove.
  echo "host: test" > "${FLEET_DIR}/fleet.config.local.yml"
  echo "API_KEY=secret" > "${FLEET_DIR}/.env"
  echo "2024-01-01,task1,1,100,50" > "${FLEET_DIR}/usage.csv"
  touch "${FLEET_DIR}/.now.lock"
  touch "${FLEET_DIR}/logs/fleet.log"
  touch "${FLEET_DIR}/tasks/t1.md"
  touch "${FLEET_DIR}/scratch/work.txt"

  # A gitignored skill (not tracked) and a .gitkeep (should be preserved).
  touch "${FLEET_DIR}/.claude/skills/installed-skill.md"
  touch "${FLEET_DIR}/.claude/skills/.gitkeep"

  # Symlink pointing at our fake fleet dir.
  ln -sf "${FLEET_DIR}/bin/fleet" "${FAKE_HOME}/.local/bin/fleet"

  export HOME="${FAKE_HOME}"
  export FLEET_ROOT="${FLEET_DIR}"
}

teardown() {
  rm -rf "${FAKE_HOME:-}" "${FLEET_DIR:-}"
}

# Run uninstall with --force so no prompt is shown, using isolated HOME and FLEET_ROOT.
run_uninstall() {
  HOME="${FAKE_HOME}" FLEET_ROOT="${FLEET_DIR}" \
    bash "${UNINSTALL}" --force "$@"
}

# Wrapper for --purge tests (separate function so bats captures exit code cleanly).
run_uninstall_purge() {
  HOME="${FAKE_HOME}" FLEET_ROOT="${FLEET_DIR}" \
    bash "${UNINSTALL}" --force --purge
}

# ---------------------------------------------------------------------------

@test "uninstall: exits 0 with --force" {
  run run_uninstall
  assert_success
}

@test "uninstall: prints 'uninstall complete' on success" {
  run run_uninstall
  assert_output --partial "uninstall complete"
}

@test "uninstall: removes ~/.local/bin/fleet symlink" {
  run run_uninstall
  assert_success
  [[ ! -e "${FAKE_HOME}/.local/bin/fleet" ]]
}

@test "uninstall: does not remove symlink pointing elsewhere" {
  # Point symlink at something unrelated.
  ln -sf /usr/bin/env "${FAKE_HOME}/.local/bin/fleet"
  run run_uninstall
  assert_success
  assert_output --partial "skipped:"
  [[ -L "${FAKE_HOME}/.local/bin/fleet" ]]
}

@test "uninstall: removes fleet.config.local.yml" {
  run run_uninstall
  assert_success
  [[ ! -f "${FLEET_DIR}/fleet.config.local.yml" ]]
}

@test "uninstall: removes .env" {
  run run_uninstall
  assert_success
  [[ ! -f "${FLEET_DIR}/.env" ]]
}

@test "uninstall: removes usage.csv" {
  run run_uninstall
  assert_success
  [[ ! -f "${FLEET_DIR}/usage.csv" ]]
}

@test "uninstall: removes .now.lock" {
  run run_uninstall
  assert_success
  [[ ! -f "${FLEET_DIR}/.now.lock" ]]
}

@test "uninstall: removes logs/ directory" {
  run run_uninstall
  assert_success
  [[ ! -d "${FLEET_DIR}/logs" ]]
}

@test "uninstall: removes tasks/ directory" {
  run run_uninstall
  assert_success
  [[ ! -d "${FLEET_DIR}/tasks" ]]
}

@test "uninstall: removes scratch/ directory" {
  run run_uninstall
  assert_success
  [[ ! -d "${FLEET_DIR}/scratch" ]]
}

@test "uninstall: leaves results/ directory intact" {
  touch "${FLEET_DIR}/results/output.md"
  run run_uninstall
  assert_success
  [[ -d "${FLEET_DIR}/results" ]]
  [[ -f "${FLEET_DIR}/results/output.md" ]]
}

@test "uninstall: leaves .gitkeep in .claude/skills/" {
  run run_uninstall
  assert_success
  [[ -f "${FLEET_DIR}/.claude/skills/.gitkeep" ]]
}

@test "uninstall: succeeds even when runtime files are already absent" {
  rm -rf "${FLEET_DIR}/logs" "${FLEET_DIR}/tasks" "${FLEET_DIR}/scratch"
  rm -f "${FLEET_DIR}/fleet.config.local.yml" "${FLEET_DIR}/.env" \
        "${FLEET_DIR}/usage.csv" "${FLEET_DIR}/.now.lock"
  run run_uninstall
  assert_success
  assert_output --partial "uninstall complete"
}

@test "uninstall: --help exits 0 and prints usage" {
  run bash "${UNINSTALL}" --help
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "--purge"
}

@test "uninstall: unknown option exits non-zero" {
  run bash "${UNINSTALL}" --bogus
  assert_failure
}

@test "uninstall: --purge deletes the repo directory" {
  run run_uninstall_purge
  assert_success
  [[ ! -d "${FLEET_DIR}" ]]
}

@test "uninstall: --purge also removes symlink before deleting repo" {
  run run_uninstall_purge
  assert_success
  [[ ! -L "${FAKE_HOME}/.local/bin/fleet" ]]
}
