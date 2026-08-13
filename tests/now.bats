#!/usr/bin/env bats
load test_helper/common

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
NOW="${FLEET_ROOT_REAL}/bin/now"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

@test "debounces a call made within the 30-second window" {
  # Lock timestamp 5 seconds ago — inside the 30s window
  echo $(( $(date -u +%s) - 5 )) > "${FLEET_DIR}/.now.lock"
  run "${NOW}"
  assert_output --partial "debounced"
}

@test "passes through when the lock is older than the window" {
  # Lock timestamp 60 seconds ago — outside the 30s window
  echo $(( $(date -u +%s) - 60 )) > "${FLEET_DIR}/.now.lock"
  # spawn runs but exits 0 (no tasks); we just check no debounce message
  run "${NOW}"
  refute_output --partial "debounced"
}

@test "passes through when no lock file exists" {
  run "${NOW}"
  refute_output --partial "debounced"
}
