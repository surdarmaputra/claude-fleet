#!/usr/bin/env bats
load helper

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
FLEET="${FLEET_ROOT_REAL}/bin/fleet"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

# ── usage / routing ───────────────────────────────────────────────────────────

@test "no arguments prints usage" {
  run "${FLEET}"
  assert_failure
  assert_output --partial "usage:"
}

@test "unknown command exits nonzero" {
  run "${FLEET}" notacommand
  assert_failure
}

# ── tasks ─────────────────────────────────────────────────────────────────────

@test "tasks: prints '(no tasks)' when the task dir is empty" {
  run "${FLEET}" tasks
  assert_output --partial "no tasks"
}

@test "tasks: lists a todo task by id" {
  make_task "abc"
  run "${FLEET}" tasks
  assert_output --partial "abc"
}

@test "tasks: --status filter shows only matching tasks" {
  make_task "t1" "done"
  make_task "t2" "todo"
  make_task "t3" "todo"
  run "${FLEET}" tasks --status done
  assert_output --partial "t1"
  refute_output --partial "t2"
  refute_output --partial "t3"
}

@test "tasks: --persona filter shows only matching tasks" {
  make_task "p1"
  # make_task always sets persona=default; add a second with a different one
  sed -i 's/persona: default/persona: researcher/' "${FLEET_DIR}/tasks/p1.md"
  make_task "p2"
  run "${FLEET}" tasks --persona researcher
  assert_output --partial "p1"
  refute_output --partial "p2"
}

# ── agents ────────────────────────────────────────────────────────────────────

@test "agents: reports no sessions when none are running" {
  run "${FLEET}" agents
  assert_output --regexp "no agent|running agents"
}

# ── logs ─────────────────────────────────────────────────────────────────────

@test "logs: prints '(no log yet)' when log file is absent" {
  run "${FLEET}" logs
  assert_output --partial "no log yet"
}

@test "logs: tails the fleet log when it exists" {
  echo "2026-01-01T00:00:00Z spawn        exit=0" > "${FLEET_DIR}/logs/fleet.log"
  run "${FLEET}" logs
  assert_output --partial "spawn"
}

# ── budget ────────────────────────────────────────────────────────────────────

@test "budget: reports sessions and budget status" {
  run "${FLEET}" budget
  assert_output --regexp "session|budget"
}

# ── doctor ────────────────────────────────────────────────────────────────────

@test "doctor: runs without crashing" {
  run "${FLEET}" doctor
  assert_output --partial "fleet doctor"
}

@test "doctor: reports OK when config file is present" {
  run "${FLEET}" doctor
  assert_output --partial "fleet.config.yml"
}

# ── cron ─────────────────────────────────────────────────────────────────────

@test "cron: outputs installed schedule section" {
  run "${FLEET}" cron
  assert_output --regexp "schedule|cron|launchd"
}
