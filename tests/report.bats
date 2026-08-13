#!/usr/bin/env bats
load helper

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
REPORT="${FLEET_ROOT_REAL}/bin/report"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

@test "prints a message when no usage CSV exists" {
  run "${REPORT}"
  assert_success
  assert_output --partial "No usage data"
}

@test "parses a CSV and groups output by persona" {
  cat > "${FLEET_DIR}/usage.csv" <<'EOF'
timestamp,task_id,persona,input_tokens,output_tokens,cache_hit_tokens
2026-01-01T10:00:00Z,task-1,default,1000,200,50
2026-01-01T11:00:00Z,task-2,default,500,100,0
EOF
  run "${REPORT}"
  assert_success
  assert_output --partial "default"
  assert_output --partial "By persona"
}

@test "parses a CSV and groups output by task" {
  cat > "${FLEET_DIR}/usage.csv" <<'EOF'
timestamp,task_id,persona,input_tokens,output_tokens,cache_hit_tokens
2026-01-01T10:00:00Z,task-1,default,1000,200,50
EOF
  run "${REPORT}"
  assert_output --partial "task-1"
  assert_output --partial "By task"
}

@test "exits nonzero on an unknown option" {
  run "${REPORT}" --bad-opt
  assert_failure
}
