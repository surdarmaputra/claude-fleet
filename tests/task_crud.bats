#!/usr/bin/env bats
load test_helper/common

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
FLEET="${FLEET_ROOT_REAL}/bin/fleet"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

# ── task new ──────────────────────────────────────────────────────────────────

@test "task new: creates a task file with auto-generated id" {
  run "${FLEET}" task new --body "do something"
  assert_success
  assert_output --partial "created:"
  # exactly one .md file in tasks/
  count=$(ls "${FLEET_DIR}/tasks/"*.md 2>/dev/null | wc -l | tr -d ' ')
  [ "${count}" -eq 1 ]
}

@test "task new: --id sets the file name and frontmatter id" {
  run "${FLEET}" task new --id my-task --body "hello"
  assert_success
  assert_output --partial "my-task"
  assert [ -f "${FLEET_DIR}/tasks/my-task.md" ]
  run grep "^id: my-task" "${FLEET_DIR}/tasks/my-task.md"
  assert_success
}

@test "task new: defaults status to todo" {
  run "${FLEET}" task new --id t1 --body "x"
  assert_success
  run grep "^status: todo" "${FLEET_DIR}/tasks/t1.md"
  assert_success
}

@test "task new: --persona sets persona field" {
  run "${FLEET}" task new --id t2 --persona coder --body "x"
  assert_success
  run grep "^persona: coder" "${FLEET_DIR}/tasks/t2.md"
  assert_success
}

@test "task new: --priority high sets priority field" {
  run "${FLEET}" task new --id t3 --priority high --body "x"
  assert_success
  run grep "^priority: high" "${FLEET_DIR}/tasks/t3.md"
  assert_success
}

@test "task new: rejects duplicate id" {
  "${FLEET}" task new --id dup --body "x"
  run "${FLEET}" task new --id dup --body "y"
  assert_failure
  assert_output --partial "already exists"
}

@test "task new: rejects invalid persona" {
  run "${FLEET}" task new --id bad --persona ghost --body "x"
  assert_failure
  assert_output --partial "invalid persona"
}

@test "task new: rejects invalid priority" {
  run "${FLEET}" task new --id bad --priority urgent --body "x"
  assert_failure
  assert_output --partial "invalid priority"
}

@test "task new: reads body from stdin when --body not given" {
  run bash -c "echo 'stdin body' | '${FLEET}' task new --id stdin-task"
  assert_success
  run grep "stdin body" "${FLEET_DIR}/tasks/stdin-task.md"
  assert_success
}

# ── task show ─────────────────────────────────────────────────────────────────

@test "task show: prints the task file contents" {
  make_task "show-me"
  run "${FLEET}" task show show-me
  assert_success
  assert_output --partial "show-me"
  assert_output --partial "status:"
}

@test "task show: fails for unknown id" {
  run "${FLEET}" task show no-such-task
  assert_failure
  assert_output --partial "no task with id"
}

# ── task edit ─────────────────────────────────────────────────────────────────

@test "task edit: updates a field" {
  make_task "edit-me"
  run "${FLEET}" task edit edit-me priority high
  assert_success
  assert_output --partial "priority=high"
  run grep "^priority: high" "${FLEET_DIR}/tasks/edit-me.md"
  assert_success
}

@test "task edit: rejects invalid status value" {
  make_task "edit-bad"
  run "${FLEET}" task edit edit-bad status flying
  assert_failure
  assert_output --partial "invalid status"
}

@test "task edit: fails for unknown task id" {
  run "${FLEET}" task edit ghost-task status done
  assert_failure
  assert_output --partial "no task with id"
}

# ── task delete ───────────────────────────────────────────────────────────────

@test "task delete --force: removes the task file" {
  make_task "kill-me"
  run "${FLEET}" task delete kill-me --force
  assert_success
  assert_output --partial "deleted"
  assert [ ! -f "${FLEET_DIR}/tasks/kill-me.md" ]
}

@test "task delete: fails for unknown task id" {
  run "${FLEET}" task delete no-such --force
  assert_failure
  assert_output --partial "no task with id"
}

# ── task done / block ─────────────────────────────────────────────────────────

@test "task done: sets status to done" {
  make_task "finish-me"
  run "${FLEET}" task done finish-me
  assert_success
  assert_output --partial "marked done"
  run grep "^status: done" "${FLEET_DIR}/tasks/finish-me.md"
  assert_success
}

@test "task block: sets status to blocked" {
  make_task "block-me"
  run "${FLEET}" task block block-me
  assert_success
  assert_output --partial "marked blocked"
  run grep "^status: blocked" "${FLEET_DIR}/tasks/block-me.md"
  assert_success
}

@test "task done: fails for unknown id" {
  run "${FLEET}" task done ghost
  assert_failure
}

@test "task block: fails for unknown id" {
  run "${FLEET}" task block ghost
  assert_failure
}

# ── routing ───────────────────────────────────────────────────────────────────

@test "task: no subcommand prints usage" {
  run "${FLEET}" task
  assert_failure
  assert_output --partial "new"
  assert_output --partial "show"
  assert_output --partial "edit"
  assert_output --partial "delete"
}

@test "task: unknown subcommand exits nonzero" {
  run "${FLEET}" task frobnicate
  assert_failure
}
