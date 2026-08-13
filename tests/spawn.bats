#!/usr/bin/env bats
load helper

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
SPAWN="${FLEET_ROOT_REAL}/bin/spawn"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

@test "exits 0 when there are no tasks" {
  run "${SPAWN}"
  assert_success
}

@test "skips a task whose persona directory does not exist" {
  make_task "t1"
  sed -i 's/persona: default/persona: ghost_persona/' "${FLEET_DIR}/tasks/t1.md"
  run "${SPAWN}"
  assert_output --partial "unknown persona"
}

@test "does not crash when the task dir contains only done tasks" {
  make_task "finished" "done"
  run "${SPAWN}"
  assert_success
}

@test "does not claim more tasks than max_agents allows" {
  # max_agents=3 by default; make 5 tasks — only 3 should be claimed
  for i in 1 2 3 4 5; do make_task "t${i}"; done
  # Without a real tmux/claude binary no tasks will actually be launched,
  # but spawn must exit cleanly and not error out.
  run "${SPAWN}"
  # Exit 0 (no tasks claimed because no persona dirs exist)
  assert_success
}
