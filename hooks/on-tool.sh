#!/bin/bash
# on-tool.sh — fires after Bash, Edit, Write, MultiEdit.
#
# Does two jobs:
#
# 1. If a plan was staged by on-plan-exit.sh AND this tool call is NOT
#    ExitPlanMode (it can't be — the matcher excludes it), the plan was
#    accepted. Create a `backlog task` with status "To Do" and remember its
#    ID as the active task.
#
# 2. If this tool call was a `git commit`, and there's an active task whose
#    status is "To Do", bump it to "In Progress".
#
# Both jobs gate on `backlog/tasks/` existing. In every other project this
# script exits in milliseconds with no output.

set -eu

. "$(dirname "$0")/lib.sh"

cbm_is_backlog_project || exit 0
cbm_has_backlog_cli   || exit 0   # plugin hasn't installed backlog yet — skip

input=$(cat)
tool=$(cbm_json_get "tool_name" "$input")
state_dir=$(cbm_state_dir)

# ── Job 1: consume pending plan (plan was accepted) ──────────────────────────
pending="$state_dir/pending-plan.md"
if [ -f "$pending" ]; then
  plan=$(cat "$pending")
  # Title = first heading (or first non-empty line), truncated to 80 chars.
  title=$(printf '%s\n' "$plan" \
    | sed -E '/^[[:space:]]*$/d' \
    | head -1 \
    | sed -E 's/^#+[[:space:]]*//' \
    | cut -c1-80)
  [ -n "$title" ] || title="Plan from $(date +%Y-%m-%d)"

  # Create task. Use --plain for parseable output, capture ID.
  id=$(backlog task create "$title" --plan "$plan" --status "To Do" --plain 2>/dev/null \
       | grep -oE 'task-[0-9]+' | head -1 || true)

  if [ -n "$id" ]; then
    echo "$id" > "$state_dir/active-task"
    echo "Backlog: created $id from accepted plan — status: To Do"
  fi
  rm -f "$pending"
fi

# ── Job 2: detect `git commit` → bump active task to In Progress ─────────────
if [ "$tool" = "Bash" ]; then
  cmd=$(cbm_json_get "tool_input.command" "$input")

  # Extract the first non-flag subcommand after `git`. This handles
  # `git commit ...`, `git -c foo=bar commit ...`, and `cd x && git commit ...`.
  # We do NOT match `git log ... commit ...` because we only look at the
  # FIRST git subcommand.
  subcmd=$(printf '%s\n' "$cmd" | awk '
    {
      # Walk tokens, find "git", skip flags, return next bare word.
      for (i = 1; i <= NF; i++) {
        if ($i == "git") {
          for (j = i + 1; j <= NF; j++) {
            if (substr($j, 1, 1) == "-") {
              # -c foo=bar is `-c` plus value; skip both
              if ($j == "-c" || $j == "-C") { j++; continue }
              continue
            }
            print $j; exit
          }
        }
      }
    }
  ')

  if [ "$subcmd" = "commit" ] && [ -f "$state_dir/active-task" ]; then
    id=$(cat "$state_dir/active-task")
    # Only bump if currently "To Do" — don't disturb In Progress / Done.
    status=$(backlog task view "$id" --plain 2>/dev/null \
             | awk -F': *' 'tolower($1)=="status"{print $2; exit}')
    if [ "$(echo "$status" | tr '[:upper:]' '[:lower:]')" = "to do" ]; then
      if backlog task edit "$id" --status "In Progress" --plain >/dev/null 2>&1; then
        echo "Backlog: $id → In Progress (commit detected)"
      fi
    fi
  fi
fi

exit 0
