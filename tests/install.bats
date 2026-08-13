#!/usr/bin/env bats
load helper

FLEET_ROOT_REAL="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

setup()    { make_fleet_root; }
teardown() { teardown_fleet_root; }

@test "all four cron schedule strings are valid 5-field cron expressions" {
  for key in schedule.spawn schedule.guard schedule.intake schedule.kb_sync; do
    sched=$(FLEET_ROOT="${FLEET_ROOT_REAL}" bash -c \
      "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get ${key}")
    fields=$(echo "${sched}" | wc -w | tr -d ' ')
    [[ "${fields}" -eq 5 ]] || \
      fail "${key}: expected 5 fields, got ${fields} in [${sched}]"
  done
}

@test "cron minute field contains only valid characters" {
  for key in schedule.spawn schedule.guard schedule.intake schedule.kb_sync; do
    sched=$(FLEET_ROOT="${FLEET_ROOT_REAL}" bash -c \
      "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get ${key}")
    minute=$(echo "${sched}" | awk '{print $1}')
    [[ "${minute}" =~ ^[0-9*/,-]+$ ]] || \
      fail "${key}: invalid minute field [${minute}]"
  done
}

@test "cron schedule values do not contain surrounding quotes" {
  for key in schedule.spawn schedule.guard schedule.intake schedule.kb_sync; do
    sched=$(FLEET_ROOT="${FLEET_ROOT_REAL}" bash -c \
      "source '${FLEET_ROOT_REAL}/bin/lib.sh' && config_get ${key}")
    [[ "${sched}" != \"* && "${sched}" != \'* ]] || \
      fail "${key}: value still has surrounding quotes: [${sched}]"
  done
}
