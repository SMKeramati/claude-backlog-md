---
name: backlog-migrate
description: Use when the user runs `/backlog-md:backlog-migrate`, or asks to "migrate /docs to backlog.md", "import existing docs into backlog", "bootstrap backlog from this project's documentation", "set up backlog from what's already there", or "extract tasks from these scattered markdown files". Reads the project's existing /docs folder, separates roadmap / todo / done / in-progress content from reference docs, and populates a clean Backlog.md project via the backlog CLI. Interactive — shows a dry-run plan first and waits for confirmation before writing anything.
argument-hint: "[path-to-docs-folder]"
allowed-tools: Read, Glob, Grep, Bash
---

# Migrate existing project docs into Backlog.md

Use this skill to migrate a project's existing, unstructured `/docs` folder (or similar) into a clean [Backlog.md](https://github.com/MrLesk/Backlog.md) setup. The skill is **interactive and conservative**: it always shows the user what it intends to do before touching the filesystem.

The argument is the path to the docs folder. If omitted, default to `./docs` and fall back to `./doc`, `./documentation`, or the project root.

## When the user invokes this skill

Follow this exact workflow. Do **not** skip steps. Do **not** call `backlog task create` until after the user confirms the plan.

### Step 1 — Survey

1. Resolve the docs folder. If it doesn't exist, tell the user and stop.
2. Use `Glob` to list every `.md` file under it (including nested folders like `plan/todo/`, `plan/done/`, `roadmap/`).
3. Note any pre-existing folder conventions (e.g. `plan/todo/`, `plan/done/`, `roadmap.md`, `TODO.md`) — these are strong signals.
4. Use `Bash` to check whether `backlog/` already exists in the project root and whether the `backlog` CLI is on PATH.

### Step 2 — Classify each file into one of four buckets

For each `.md` file, decide which bucket it belongs to. Use the file path, filename, and a quick read of the top of the file (first ~40 lines via `Read`) — not the whole file unless needed.

| Bucket | Heuristic | Becomes |
|---|---|---|
| **Task: To Do** | Path matches `plan/todo/*`, `roadmap/*`, `backlog/*`, `todo/*`; or file is short (<50 lines) and reads like a single feature description | One `backlog task` per file, `--status "To Do"` |
| **Task: Done** | Path matches `plan/done/*`, `done/*`, `archive/*`, `completed/*`; or filename indicates shipped work | One `backlog task`, `--status "Done"` |
| **Task: In Progress** | File explicitly mentions "in progress", "WIP", "currently working on", or sits in `plan/in-progress/` | `--status "In Progress"` |
| **Reference doc** | Architecture, runbook, methodology, spec, audit, requirements — anything that describes *how things work* rather than *what to do next* | One Backlog document via the `document_create` MCP tool (kept as docs, not turned into tasks) |
| **Skip / archive** | Outdated drafts, duplicates with later versions, scratch notes the user clearly abandoned | Listed for the user but NOT imported. Recommend `git mv` to an `archive/` folder. |

When two versions of the same doc exist (e.g. `methodology.md` and `methodology-simple.md`), prefer the **most recently modified** as the canonical one and flag the other for the user's review.

### Step 3 — Show the user a dry-run plan

Output a table grouped by bucket. Format:

```
## Bootstrap plan for /path/to/docs

To Do (N tasks):
  - <path> → task: "<title>"
  - ...

In Progress (N tasks):
  - <path> → task: "<title>"

Done (N tasks):
  - <path> → task: "<title>"

Reference docs to keep (N):
  - <path> → backlog doc: "<title>"

Files I'm flagging as outdated / duplicate (you decide):
  - <path>  (reason: ...)
```

End with a clear ask: **"Apply this plan? (yes / edit / cancel)"**

If the user says **edit**, ask which entries to change and re-print the plan. If **cancel**, exit cleanly. If **yes**, proceed.

### Step 4 — Apply

Only after explicit confirmation:

1. **Initialize backlog if needed.** Run `backlog init "<project-name>" --defaults --no-mcp` (no MCP setup — this plugin already provides MCP; we just need the file structure). Use the parent folder name as the project name unless the user provided one. If `backlog/` already exists, skip init.
2. **Create tasks** — one `backlog task create` per item, with `--status`, and `--notes` set to the path of the source file so the user can trace back. Use `--plain` and capture stdout for the assigned task ID.
3. **Create reference docs** — use the `document_create` MCP tool for each reference doc. Set the `title` from the file's H1 (or filename), and the `content` from the source file's body.
4. **Do NOT delete the source files.** Leave the original `/docs` untouched. The user can clean up themselves with `git rm` once they've confirmed the migration looks right.

### Step 5 — Report

Print a compact summary:

```
✓ Created N tasks (X in progress, Y to do, Z done)
✓ Created M reference docs
○ Flagged K files as outdated/duplicate — left in place for your review

Next steps:
  - Run `backlog board` to see the kanban
  - Run `backlog browser` for the web UI
  - When you're confident the migration is good, you can `git rm` the originals from /docs
```

## Guardrails

- **Never write before confirming.** The dry-run step is non-negotiable.
- **Never delete.** Even after success, the source docs are left in place. The user owns deletion.
- **Read minimal.** When classifying, read at most the first 40 lines of each file unless the user asks for deeper analysis. Across a 50-file docs folder this is the difference between fast and painful.
- **Don't moralize.** If files look "messy," don't lecture about doc hygiene. Migrate what's there.
- **Stay within docs.** Do not scan the entire codebase for tasks — only the docs folder the user pointed at. Code-level TODOs are out of scope (use imdone for those).

## When NOT to use this skill

- Project already has a populated `backlog/tasks/` folder — there's nothing to migrate. Suggest `backlog task list` instead.
- The "docs" folder is actually rendered API docs / generated reference material — those don't map to backlog content.
- User wants ongoing two-way sync between docs and backlog — this skill is one-shot migration, not sync.
