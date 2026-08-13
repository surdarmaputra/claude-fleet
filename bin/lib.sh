#!/usr/bin/env bash
# Shared utilities sourced by all fleet scripts.
set -euo pipefail

FLEET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${FLEET_ROOT}/fleet.config.yml"
LOCAL_CONFIG_FILE="${FLEET_ROOT}/fleet.config.local.yml"
ENV_FILE="${FLEET_ROOT}/.env"
LOG_FILE="${FLEET_ROOT}/logs/fleet.log"
USAGE_CSV="${FLEET_ROOT}/usage.csv"
TASKS_DIR="${FLEET_ROOT}/tasks"
RESULTS_DIR="${FLEET_ROOT}/results"
SCRATCH_DIR="${FLEET_ROOT}/scratch"

# Load .env if present
[[ -f "${ENV_FILE}" ]] && set -a && source "${ENV_FILE}" && set +a

# Read a scalar from config files. Local file takes precedence over default.
# Usage: config_get key [default]
# Handles top-level keys and one level of nesting (budget.warn_at_percent).
config_get() {
  local key="${1}" default="${2:-}"
  local val

  _config_read_key() {
    local file="${1}" k="${2}"
    if [[ ! -f "${file}" ]]; then return; fi
    if [[ "${k}" == *.* ]]; then
      local parent="${k%%.*}" child="${k#*.}"
      awk -v parent="${parent}:" -v child="  ${child}:" '
        /^[^ ]/ { in_parent=0 }
        $0 ~ "^"parent { in_parent=1; next }
        in_parent && $0 ~ "^"child {
          sub(/^[^:]+:[[:space:]]*/, "")
          sub(/#.*$/, "")
          gsub(/[[:space:]]/, "")
          print; exit
        }
      ' "${file}"
    else
      grep -E "^${k}:" "${file}" | head -1 \
        | sed 's/^[^:]*:[[:space:]]*//' \
        | sed 's/[[:space:]]*#.*//' \
        | tr -d '[:space:]'
    fi
  }

  # Local file wins; fall back to default config.
  val=$(_config_read_key "${LOCAL_CONFIG_FILE}" "${key}")
  [[ -z "${val}" ]] && val=$(_config_read_key "${CONFIG_FILE}" "${key}")
  echo "${val:-${default}}"
}

# Timestamp in RFC3339 UTC
now_ts() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Append one heartbeat line to fleet.log.
# Usage: log_heartbeat <job> <exit_code> [key=value ...]
log_heartbeat() {
  local job="${1}" code="${2}"
  shift 2
  local ts
  ts=$(now_ts)
  printf "%-26s %-12s exit=%-3s %s\n" "${ts}" "${job}" "${code}" "$*" >> "${LOG_FILE}"
}

# Frontmatter: read a single field from a task file.
# Usage: task_get <file> <field>
task_get() {
  local file="${1}" field="${2}"
  awk -v f="${field}" '
    /^---$/ { count++; next }
    count == 1 && $0 ~ "^"f":" { sub(/^[^:]+:[[:space:]]*/, ""); print; exit }
    count >= 2 { exit }
  ' "${file}" | tr -d '[:space:]'
}

# List all task files matching optional status filter.
# Usage: list_tasks [status]
list_tasks() {
  local status="${1:-}"
  for f in "${TASKS_DIR}"/*.md; do
    [[ -f "${f}" ]] || continue
    if [[ -n "${status}" ]]; then
      local s
      s=$(task_get "${f}" "status")
      [[ "${s}" == "${status}" ]] || continue
    fi
    echo "${f}"
  done
}

# Count tmux sessions matching a task id prefix.
tmux_running_count() {
  tmux ls 2>/dev/null | grep -c "^fleet-" || true
}

# Find the tmux session name for a task id (fleet-<id>).
tmux_session_for() {
  local task_id="${1}"
  tmux ls 2>/dev/null | grep -o "^fleet-${task_id}[^:]*" | head -1 || true
}

# Ensure log dir exists.
mkdir -p "${FLEET_ROOT}/logs"
