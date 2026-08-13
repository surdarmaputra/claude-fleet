#!/usr/bin/env bash
# Loaded by every .bats file via load helper

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

load "${BATS_TEST_DIRNAME}/lib/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/lib/bats-assert/load.bash"

# Create a temp fleet root with config copied in.
# Sets and exports FLEET_ROOT and FLEET_DIR.
make_fleet_root() {
  FLEET_DIR="$(mktemp -d)"
  mkdir -p "${FLEET_DIR}/logs" "${FLEET_DIR}/tasks" \
            "${FLEET_DIR}/results" "${FLEET_DIR}/scratch"
  cp "${FLEET_ROOT_REAL}/fleet.config.yml" "${FLEET_DIR}/fleet.config.yml"
  export FLEET_ROOT="${FLEET_DIR}"
}

teardown_fleet_root() {
  rm -rf "${FLEET_DIR:-}"
}

# Write a minimal task file.
# Usage: make_task <id> [status] [priority] [attempts]
make_task() {
  local id="${1}" status="${2:-todo}" priority="${3:-normal}" attempts="${4:-}"
  local f="${FLEET_ROOT}/tasks/${id}.md"
  {
    echo "---"
    echo "id: ${id}"
    echo "status: ${status}"
    echo "persona: default"
    echo "priority: ${priority}"
    [[ -n "${attempts}" ]] && echo "attempts: ${attempts}"
    echo "---"
    echo "Do something for task ${id}."
  } > "${f}"
}

# Convenience: source lib.sh in the current FLEET_ROOT context.
source_lib() {
  source "${FLEET_ROOT_REAL}/bin/lib.sh"
}
