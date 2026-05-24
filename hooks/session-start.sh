#!/bin/bash
# session-start.sh — gated context injector for backlog-initialized projects.
#
# Fires on SessionStart in EVERY Claude Code session, but exits silently
# unless the current project has a `backlog/` folder. So:
#   • Random project / casual chat        → no-op, zero context cost
#   • Project with `backlog/tasks/`       → injects a compact state summary
#
# The output is read by Claude as additional context for the session.

set -eu

[ -d backlog/tasks ] || exit 0

# Quick state summary — no titles, just counts + the In Progress titles.
# We deliberately keep this <15 lines so it never bloats the conversation.
in_progress=$(find backlog/tasks -type f -name '*.md' -exec grep -l '^status: .*In Progress' {} + 2>/dev/null || true)
todo_count=$(find backlog/tasks -type f -name '*.md' -exec grep -l '^status: .*To Do' {} + 2>/dev/null | wc -l | tr -d ' ')
done_count=$(find backlog/tasks -type f -name '*.md' -exec grep -l '^status: .*Done' {} + 2>/dev/null | wc -l | tr -d ' ')
ip_count=$(echo "$in_progress" | grep -c . 2>/dev/null || echo 0)

echo "## Backlog state (auto-injected by claude-backlog-md)"
echo "In Progress: $ip_count · To Do: $todo_count · Done: $done_count"

if [ "$ip_count" -gt 0 ]; then
  echo
  echo "Currently in progress:"
  echo "$in_progress" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    awk '
      /^id:/    { v=$0; sub(/^id:[[:space:]]*/, "", v); id=v }
      /^title:/ { v=$0; sub(/^title:[[:space:]]*/, "", v); gsub(/^"|"$/, "", v); gsub(/^'\''|'\''$/, "", v); print "- " id " — " v; exit }
    ' "$f"
  done
fi

echo
echo "Use Backlog MCP tools (task_list, task_view, task_edit) to interact. Run \`backlog board\` for the terminal kanban."
