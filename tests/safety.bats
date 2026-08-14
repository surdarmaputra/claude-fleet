#!/usr/bin/env bats
load test_helper/common

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
FLEET="${FLEET_ROOT_REAL}/bin/fleet"
SPAWN="${FLEET_ROOT_REAL}/bin/spawn"
GUARD="${FLEET_ROOT_REAL}/bin/guard"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

# ── fleet config ──────────────────────────────────────────────────────────────

@test "config: shows fleet.config.yml section" {
  run "${FLEET}" config
  assert_success
  assert_output --partial "fleet.config.yml"
}

@test "config: shows local config section" {
  run "${FLEET}" config
  assert_success
  assert_output --partial "fleet.config.local.yml"
}

@test "config: shows pause status as active when not paused" {
  run "${FLEET}" config
  assert_success
  assert_output --partial "active (not paused)"
}

@test "config: shows PAUSED when .paused file exists" {
  touch "${FLEET_DIR}/.paused"
  run "${FLEET}" config
  assert_success
  assert_output --partial "PAUSED"
}

@test "config: shows effective schedule section" {
  run "${FLEET}" config
  assert_success
  assert_output --partial "effective schedule"
  assert_output --partial "spawn:"
  assert_output --partial "guard:"
}

@test "config: shows .env section" {
  run "${FLEET}" config
  assert_success
  assert_output --partial ".env"
}

# ── fleet pause / resume ──────────────────────────────────────────────────────

@test "pause: creates .paused lockfile" {
  run "${FLEET}" pause
  assert_success
  assert_output --partial "paused"
  assert [ -f "${FLEET_DIR}/.paused" ]
}

@test "pause: is idempotent when already paused" {
  touch "${FLEET_DIR}/.paused"
  run "${FLEET}" pause
  assert_success
  assert_output --partial "already paused"
}

@test "resume: removes .paused lockfile" {
  touch "${FLEET_DIR}/.paused"
  run "${FLEET}" resume
  assert_success
  assert_output --partial "resumed"
  assert [ ! -f "${FLEET_DIR}/.paused" ]
}

@test "resume: reports not paused when lockfile absent" {
  run "${FLEET}" resume
  assert_success
  assert_output --partial "not paused"
}

# ── spawn respects pause ──────────────────────────────────────────────────────

@test "spawn: exits immediately when .paused exists" {
  touch "${FLEET_DIR}/.paused"
  make_task "t1"
  run "${SPAWN}"
  assert_success
  # Task must still be todo — spawn must not have claimed it.
  run grep "^status: todo" "${FLEET_DIR}/tasks/t1.md"
  assert_success
}

@test "spawn: logs paused=true to fleet.log" {
  touch "${FLEET_DIR}/.paused"
  run "${SPAWN}"
  assert_success
  run grep "paused=true" "${FLEET_DIR}/logs/fleet.log"
  assert_success
}

# ── guard respects pause ──────────────────────────────────────────────────────

@test "guard: skips orphan recovery when .paused exists" {
  touch "${FLEET_DIR}/.paused"
  # A doing task with no tmux session is an orphan — guard should leave it.
  make_task "orphan" "doing"
  run "${GUARD}"
  assert_success
  run grep "^status: doing" "${FLEET_DIR}/tasks/orphan.md"
  assert_success
}

# ── fleet kill ────────────────────────────────────────────────────────────────

@test "kill: requires an argument" {
  run "${FLEET}" kill
  assert_failure
  assert_output --partial "usage"
}

@test "kill: reports no session when id has no tmux session" {
  make_task "mytask" "doing"
  run "${FLEET}" kill mytask
  assert_success
  assert_output --partial "no session"
}

@test "kill: resets task to todo even when no session exists" {
  make_task "mytask" "doing"
  run "${FLEET}" kill mytask
  assert_success
  run grep "^status: todo" "${FLEET_DIR}/tasks/mytask.md"
  assert_success
}

@test "kill --all: reports no sessions when none running" {
  run "${FLEET}" kill --all
  assert_success
  assert_output --partial "no agent sessions running"
}

@test "kill --all: resets all doing tasks to todo" {
  make_task "t1" "doing"
  make_task "t2" "doing"
  run "${FLEET}" kill --all
  assert_success
  run grep "^status: todo" "${FLEET_DIR}/tasks/t1.md"
  assert_success
  run grep "^status: todo" "${FLEET_DIR}/tasks/t2.md"
  assert_success
}

# ── fleet halt ────────────────────────────────────────────────────────────────

@test "halt: creates .paused lockfile" {
  run "${FLEET}" halt
  assert_success
  assert [ -f "${FLEET_DIR}/.paused" ]
}

@test "halt: resets doing tasks to todo" {
  make_task "t1" "doing"
  make_task "t2" "doing"
  run "${FLEET}" halt
  assert_success
  run grep "^status: todo" "${FLEET_DIR}/tasks/t1.md"
  assert_success
  run grep "^status: todo" "${FLEET_DIR}/tasks/t2.md"
  assert_success
}

@test "halt: reports killed and reset counts" {
  make_task "t1" "doing"
  run "${FLEET}" halt
  assert_success
  assert_output --partial "killed"
  assert_output --partial "reset"
}

@test "halt: does not disturb todo or done tasks" {
  make_task "t1" "todo"
  make_task "t2" "done"
  run "${FLEET}" halt
  assert_success
  run grep "^status: todo" "${FLEET_DIR}/tasks/t1.md"
  assert_success
  run grep "^status: done" "${FLEET_DIR}/tasks/t2.md"
  assert_success
}
