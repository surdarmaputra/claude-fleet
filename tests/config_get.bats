#!/usr/bin/env bats
load helper

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

@test "top-level key returns its value" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get max_agents"
  assert_output "3"
}

@test "missing key returns the supplied default" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get nonexistent_key fallback"
  assert_output "fallback"
}

@test "empty-value key falls through to default" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get work_repo_prefix none"
  assert_output "none"
}

@test "nested cron expression preserves internal spaces" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get schedule.spawn"
  assert_output "*/5 9-18 * * 1-5"
}

@test "all four cron schedules each have exactly 5 fields" {
  for key in schedule.spawn schedule.guard schedule.intake schedule.kb_sync; do
    run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get ${key} | wc -w | tr -d ' '"
    assert_output "5"
  done
}

@test "local config file overrides the default config" {
  echo "max_agents: 99" > "${FLEET_DIR}/fleet.config.local.yml"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get max_agents 0"
  assert_output "99"
}

@test "quoted YAML value has its quotes stripped" {
  cat > "${FLEET_DIR}/fleet.config.yml" <<'EOF'
schedule:
  spawn: "*/5 9-18 * * 1-5"
EOF
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get schedule.spawn"
  assert_output "*/5 9-18 * * 1-5"
}

@test "missing nested key returns the supplied default" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get schedule.nonexistent MISSING"
  assert_output "MISSING"
}
