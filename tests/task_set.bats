#!/usr/bin/env bats
load helper

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
TASK_SET="${FLEET_ROOT_REAL}/bin/task-set"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

@test "updates an existing field" {
  make_task "t1" "todo"
  run "${TASK_SET}" "${FLEET_DIR}/tasks/t1.md" status doing
  assert_success
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/t1.md' status"
  assert_output "doing"
}

@test "adds a field that was not present" {
  make_task "t2"
  run "${TASK_SET}" "${FLEET_DIR}/tasks/t2.md" attempts 1
  assert_success
  run bash -c "source '${FLEET_ROOT_REAL}/bin/lib.sh' && task_get '${FLEET_DIR}/tasks/t2.md' attempts"
  assert_output "1"
}

@test "preserves the task body after mutation" {
  cat > "${FLEET_DIR}/tasks/t3.md" <<'EOF'
---
id: t3
status: todo
---
My task body.
Second line.
EOF
  run "${TASK_SET}" "${FLEET_DIR}/tasks/t3.md" status done
  assert_success
  run awk '/^---$/{n++; next} n>=2{print}' "${FLEET_DIR}/tasks/t3.md"
  assert_output --partial "My task body."
  assert_output --partial "Second line."
}

@test "prints an error and exits nonzero when file does not exist" {
  run "${TASK_SET}" "${FLEET_DIR}/tasks/ghost.md" status done
  assert_failure
  assert_output --partial "not found"
}

@test "prints usage and exits nonzero when called with no arguments" {
  run "${TASK_SET}"
  assert_failure
  assert_output --partial "usage"
}
