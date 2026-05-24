# claude-backlog-md

**Claude Code plugin for [Backlog.md](https://github.com/MrLesk/Backlog.md).** Wraps the MCP server, auto-installs the CLI on first use, and adds a `/bootstrap` skill for turning a messy `/docs` folder into a clean Backlog. Minimal — three gated hooks, zero CLAUDE.md edits.

## Quick start

```bash
# In Claude Code:
/plugin install SMKeramati/claude-backlog-md
```

No prior install needed — the plugin grabs `backlog-md` via `bun` / `npm` / `brew` on first use.

**Plugin stays dormant until a project has a `backlog/` folder.** To opt in:

- New project → `backlog init "My Project"`
- Existing project with `/docs` → run `/backlog-md:bootstrap` (Claude migrates, asks first)

After that, your flow auto-tracks: plan accepted → task `To Do`; `git commit` → task `In Progress`. Everywhere else: zero hooks, zero context.

---

```
SessionStart hook  ──┐
                     ├─ only activates in projects with a `backlog/` folder
MCP server         ──┘  (so casual chats don't trigger anything)

/backlog-md:bootstrap  ──  user-invoked, interactive migration
                                     dry-runs the plan, asks before writing
```

---

## What it does

| Component | What | When it activates |
|---|---|---|
| **MCP server** | Bundles [Backlog.md's MCP](https://github.com/MrLesk/Backlog.md#mcp-integration) (task_create, task_list, task_edit, document_create, …). | Whenever you use Claude Code. Backlog itself reports "not initialized" for projects without `backlog/` — graceful degradation. |
| **Auto-install** | First time the MCP server starts and `backlog` CLI isn't on PATH, the wrapper installs it via `bun` → `npm` → `brew` (in that order). | Once. Subsequent sessions are instant. |
| **SessionStart hook** | Injects a compact task-state summary (`In Progress: 2 · To Do: 5 · Done: 11`) and the titles of in-progress tasks. | **Gated:** only when `backlog/tasks/` exists in the current project. Casual chats in unrelated projects see zero impact. |
| **Plan-acceptance hook** | When Claude finishes a plan via `ExitPlanMode` *and* the user accepts it (detected by the next non-plan tool firing), creates a new task with status `To Do`. The plan content goes into the task's `plan` field. Rejected plans never materialize — Claude's next `ExitPlanMode` overwrites the staged plan instead. | Gated on `backlog/`; silent everywhere else. |
| **Commit-detection hook** | When Claude runs `git commit` (and only `commit` — not `log`, `status`, etc.), the currently-active task is bumped from `To Do` → `In Progress`. Idempotent: tasks already past `To Do` are not touched. | Gated; only fires on actual git commits, never on file edits. |
| **`bootstrap` skill** | Reads an existing `/docs` folder, classifies each file as task vs reference doc, dry-runs a migration plan, waits for confirmation, then populates `backlog/`. | User-invoked: `/backlog-md:bootstrap [path]`. |

What's deliberately **not** included:

- No CLAUDE.md edits (ever).
- No `Stop` / `PreToolUse` / `UserPromptSubmit` hooks. The three hooks above fire on narrow, deterministic events — they don't run on every turn or every keystroke.
- No prompt injection of long instruction blocks. Backlog.md's own MCP already ships a 25-line agent nudge — we don't duplicate it.

### Workflow this creates

```
Claude proposes a plan      →  ExitPlanMode call
You accept                  →  next tool fires  →  task created, status: To Do
Claude works, runs tests    →  (no hook activity — silent)
Claude runs `git commit`    →  task → In Progress
You manually mark Done      →  `backlog task complete <id>`  (or via MCP)
```

State (which task is "active") is stored in `${TMPDIR}/cbm-<project-hash>/` — never inside your repo.

---

## Install

This is a Claude Code plugin. Install via your plugin marketplace setup, or clone directly:

```bash
# from your Claude Code session:
/plugin install SMKeramati/claude-backlog-md
```

(Or place the repo under your plugins directory and enable it.)

The first time you trigger any Backlog MCP tool, the wrapper auto-installs `backlog-md` if you don't have it. No manual step needed — but you can pre-install it if you prefer:

```bash
brew install backlog-md          # macOS, no JS runtime needed
# or
bun add -g backlog.md            # fastest
# or
npm install -g backlog.md
```

---

## Usage

### In a Backlog-initialized project

Just use Claude Code normally — `task_list`, `task_create`, `task_edit`, etc. are exposed as MCP tools. The SessionStart hook reminds Claude (and you) what's in progress.

```
You: what's left on the auth refactor?
Claude: [reads task_list via MCP, answers]
```

### In a project that has `/docs` but no `backlog/`

Run the bootstrap skill:

```
/backlog-md:bootstrap
```

or pointing at a non-default path:

```
/backlog-md:bootstrap ./project-notes
```

The skill will:

1. Survey every `.md` file under that path.
2. Classify each as **To Do / In Progress / Done / Reference doc / Outdated**.
3. Show you a **dry-run plan** as a table.
4. Wait for you to say "yes / edit / cancel".
5. If yes: run `backlog init` (if needed), then `backlog task create` and `document_create` for each item.
6. **Never deletes source files.** You clean up `/docs` yourself when you're happy.

### In any other project

The MCP server is registered but Backlog will report `backlog://init-required` until you run `backlog init`. The SessionStart hook exits silently. Effectively zero overhead.

---

## Architecture (the honest cost)

| Layer | Cost when project has no `backlog/` | Cost when project has `backlog/` |
|---|---|---|
| MCP server process | Running, idle. ~5 MB RAM. | Running, serving tool calls. |
| MCP tools in Claude's context | ~200 tokens (deferred — full schemas load on use) | Same — 200 token baseline |
| SessionStart hook | Single `[ -d backlog/tasks ] || exit 0` — ~5 ms | ~50 ms to scan task files + emit ~10-line summary |

So on a casual "hello Claude" session in a random project: the MCP daemon exists but does nothing, the hook exits in milliseconds, no context noise.

---

## Files

```
claude-backlog-md/
├── .claude-plugin/plugin.json    # manifest
├── .mcp.json                     # registers `backlog` MCP server
├── bin/backlog-mcp.sh            # wrapper: auto-installs CLI, then `backlog mcp start`
├── hooks/
│   ├── hooks.json                # event → script wiring
│   ├── lib.sh                    # shared helpers (state dir, JSON parsing, gates)
│   ├── session-start.sh          # gated context injector
│   ├── on-plan-exit.sh           # stages plan content (after ExitPlanMode)
│   └── on-tool.sh                # consumes plan + detects git commit
├── skills/
│   └── bootstrap/
│       └── SKILL.md              # `/backlog-md:bootstrap`
└── README.md
```

10 files. No node_modules, no build step, no daemon other than the MCP server (which Backlog.md provides).

---

## Compatibility

| Concern | Handled |
|---|---|
| No JS runtime on the machine | ✅ wrapper falls back to `brew install backlog-md` |
| No Homebrew | ✅ tries `bun` then `npm` first |
| No installer at all | ❌ fails with clear error pointing at `bun.sh/install` |
| macOS / Linux | ✅ bash 3.2 compatible, POSIX-y tools |
| Project without `backlog/` | ✅ hook is a no-op, MCP gracefully reports init-required |

---

## What about cross-project view?

This plugin doesn't do it — Backlog.md is per-repo by design. For "what am I working on across all my projects?", see [SMKeramati/backlog-overview](https://github.com/SMKeramati/backlog-overview) — a ~250-line bash script that scans every `backlog/tasks/` under a root folder and prints a grouped report.

---

## License

MIT. See [LICENSE](LICENSE).

---

## Credits

- [MrLesk/Backlog.md](https://github.com/MrLesk/Backlog.md) — the underlying task manager and MCP server. This plugin is a thin Claude Code wrapper around it.
