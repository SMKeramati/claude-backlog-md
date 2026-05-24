#!/bin/bash
# on-plan-exit.sh — fires after Claude calls ExitPlanMode.
#
# Stages the plan content to a temp file. Does NOT create the backlog task yet
# — we don't know if the user accepted or rejected the plan. on-tool.sh
# consumes this file on the next non-plan-mode tool call (which only happens
# if the plan was accepted).
#
# If user rejects, Claude re-enters plan mode and calls ExitPlanMode again,
# overwriting the staged file with the new plan. So rejected plans never
# materialize as backlog tasks. Clean.

set -eu

# Source helpers
. "$(dirname "$0")/lib.sh"

cbm_is_backlog_project || exit 0

input=$(cat)
plan=$(cbm_json_get "tool_input.plan" "$input")

# If plan field is empty or extraction failed, exit silently.
[ -n "$plan" ] || exit 0

state_dir=$(cbm_state_dir)
mkdir -p "$state_dir"
printf '%s' "$plan" > "$state_dir/pending-plan.md"

exit 0
