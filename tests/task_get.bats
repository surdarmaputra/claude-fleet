#!/usr/bin/env bats
load helper

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

@test "reads the status field" {
  make_task "abc" "todo"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/abc.md' status"
  assert_output "todo"
}

@test "reads the id field" {
  make_task "my-task-99"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/my-task-99.md' id"
  assert_output "my-task-99"
}

@test "returns empty string for a field that does not exist" {
  make_task "x"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/x.md' nonexistent"
  assert_output ""
}

@test "now_ts produces a valid RFC3339 UTC timestamp" {
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && now_ts"
  assert_success
  [[ "${output}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}
