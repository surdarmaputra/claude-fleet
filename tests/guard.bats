#!/usr/bin/env bats
load helper

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
GUARD="${FLEET_ROOT_REAL}/bin/guard"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

@test "exits 0 when there are no tasks" {
  run "${GUARD}"
  assert_success
}

@test "resets an orphaned doing task back to todo" {
  make_task "orphan" "doing"
  run "${GUARD}"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/orphan.md' status"
  assert_output "todo"
}

@test "increments the attempts counter on each orphan recovery" {
  make_task "retried" "doing"
  run "${GUARD}"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/retried.md' attempts"
  assert_output "1"
}

@test "blocks a task that has already failed 3 times" {
  make_task "stubborn" "doing" "normal" "3"
  run "${GUARD}"
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/stubborn.md' status"
  assert_output "blocked"
}

@test "exits 2 when a task is blocked" {
  make_task "bad" "doing" "normal" "3"
  run "${GUARD}"
  assert [ "${status}" -eq 2 ]
}

@test "leaves a todo task untouched" {
  make_task "idle" "todo"
  run "${GUARD}"
  assert_success
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/idle.md' status"
  assert_output "todo"
}
