#!/usr/bin/env bats
# Tests for bin/lib.sh: config_get, task_get, now_ts
load test_helper/common

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

# ── config_get ────────────────────────────────────────────────────────────────

@test "config_get: top-level key returns its value" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get max_agents"
  assert_output "3"
}

@test "config_get: missing key returns the supplied default" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get nonexistent_key fallback"
  assert_output "fallback"
}

@test "config_get: empty-value key falls through to default" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get work_repo_prefix none"
  assert_output "none"
}

@test "config_get: nested cron expression preserves internal spaces" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get schedule.spawn"
  assert_output "*/5 9-18 * * 1-5"
}

@test "config_get: all four cron schedules each have exactly 5 fields" {
  for key in schedule.spawn schedule.guard schedule.intake schedule.kb_sync; do
    run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get ${key} | wc -w | tr -d ' '"
    assert_output "5"
  done
}

@test "config_get: local config file overrides the default config" {
  echo "max_agents: 99" > "${FLEET_DIR}/fleet.config.local.yml"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get max_agents 0"
  assert_output "99"
}

@test "config_get: quoted YAML value has its quotes stripped" {
  cat > "${FLEET_DIR}/fleet.config.yml" <<'EOF'
schedule:
  spawn: "*/5 9-18 * * 1-5"
EOF
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get schedule.spawn"
  assert_output "*/5 9-18 * * 1-5"
}

@test "config_get: missing nested key returns the supplied default" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get schedule.nonexistent MISSING"
  assert_output "MISSING"
}

# ── task_get ──────────────────────────────────────────────────────────────────

@test "task_get: reads the status field" {
  make_task "abc" "todo"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/abc.md' status"
  assert_output "todo"
}

@test "task_get: reads the id field" {
  make_task "my-task-99"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/my-task-99.md' id"
  assert_output "my-task-99"
}

@test "task_get: returns empty string for a field that does not exist" {
  make_task "x"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/x.md' nonexistent"
  assert_output ""
}

# ── now_ts ────────────────────────────────────────────────────────────────────

@test "now_ts: produces a valid RFC3339 UTC timestamp" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && now_ts"
  assert_success
  [[ "${output}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}
