# Shared helpers for claude-backlog-md hooks.
# Sourced by on-plan-exit.sh and on-tool.sh. Keep this tiny and dependency-free.

# State directory — per-project, in /tmp so it never pollutes the repo.
# Hashed pwd so multiple projects don't collide.
cbm_state_dir() {
  local hash
  if command -v shasum >/dev/null 2>&1; then
    hash=$(pwd -P | shasum -a 1 | cut -c1-12)
  elif command -v sha1sum >/dev/null 2>&1; then
    hash=$(pwd -P | sha1sum | cut -c1-12)
  else
    # Fallback: just sanitize the path
    hash=$(pwd -P | tr '/ ' '__' | cut -c1-40)
  fi
  echo "${TMPDIR:-/tmp}/cbm-${hash}"
}

# JSON field extractor that prefers jq when available, falls back to python3
# (which is bundled with macOS and every modern Linux distro).
cbm_json_get() {
  local field="$1" input="$2"
  if command -v jq >/dev/null 2>&1; then
    echo "$input" | jq -r ".${field} // empty" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    echo "$input" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    parts = '${field}'.split('.')
    for p in parts:
        d = d.get(p, '') if isinstance(d, dict) else ''
    print(d if d else '')
except Exception:
    pass
" 2>/dev/null
  else
    return 1
  fi
}

# Are we in a backlog-initialized project?
cbm_is_backlog_project() {
  [ -d backlog/tasks ]
}

# Is the `backlog` CLI on PATH?
cbm_has_backlog_cli() {
  command -v backlog >/dev/null 2>&1
}
