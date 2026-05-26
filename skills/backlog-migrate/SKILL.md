---
name: backlog-migrate
description: Use when the user runs `/backlog-md:backlog-migrate`, or asks to "migrate /docs to backlog.md", "move my existing plans and todos into backlog", "import these markdown files into backlog as-is", "convert my docs folder into a backlog structure", or "set up backlog from what's already there". Walks a docs folder, classifies each markdown file by status from its folder location and content, shows a one-line-per-file dry run, waits for confirmation, then creates exactly one backlog entry per source file with the file's content moved verbatim. The migration is a pure relocation — content is never decomposed, summarized, split into sub-tasks, or rewritten. Source files are never deleted.
argument-hint: "[path-to-docs-folder]"
allowed-tools: Read, Glob, Grep, Bash
---

# Migrate existing docs into Backlog.md

This skill moves an existing `/docs` folder (or similar) into a clean [Backlog.md](https://github.com/MrLesk/Backlog.md) structure. The migration is pure relocation: every source markdown file becomes exactly one backlog entry, with its content moved unchanged. A 200-line plan file becomes one entry whose `plan` field is that 200-line plan.

The unit is the file, not the bullet point inside the file. Decomposition is for the planning phase (which happens elsewhere), not for this skill.

## Mapping

For each `.md` file in the input path, pick one row from this table.

| Where the file lives, or what it looks like | Backlog action | Status |
|---|---|---|
| `plan/todo/`, `todo/`, `roadmap/`, `backlog/`, or filename suggests planned work | one `task_create` | To Do |
| `plan/in-progress/`, `wip/`, `current/`, or body explicitly says "in progress" / "WIP" | one `task_create` | In Progress |
| `plan/done/`, `done/`, `completed/`, `shipped/`, or filename says "done" | one `task_create` | Done |
| Older duplicate of another file (same topic, older mtime, marked DRAFT / OLD / OUTDATED) | one `task_create` then `task_archive` | Done, archived |
| Architecture, methodology, runbook, audit, spec, requirements, design doc, ADR | one `document_create` | — |

If a file matches no row clearly (short note, ambiguous title, lives at the root with no folder signal), list it in the dry run with a `?` and let the user pick during confirmation.

## Flow

### 1. Survey

Default input path: `./docs/`. If the user passed an argument, use that.

List every `.md` file recursively with `Glob`. The folder structure (`plan/todo/`, `plan/done/`, `roadmap/`) classifies a file before any content read. For ambiguous files only, open the first 40 lines to disambiguate.

### 2. Show the dry run

Print one line per file, grouped by destination. End with the apply prompt. The user gets the whole plan at a glance and answers once.

```
backlog-migrate: dry run for ./docs

  To Do (3):
    docs/plan/todo/login-flow.md          → task
    docs/plan/todo/migrate-postgres.md    → task
    docs/plan/todo/refactor-checkout.md   → task

  In Progress (1):
    docs/plan/in-progress/oauth-rollout.md  → task

  Done (2):
    docs/plan/done/setup-pipeline.md       → task
    docs/plan/done/initial-deploy.md       → task

  Done, archived (1):
    docs/old-methodology.md                → task, then archived

  Reference docs (4):
    docs/architecture.md     → document
    docs/runbook.md          → document
    docs/audit-2026.md       → document
    docs/methodology.md      → document

  Uncertain (1 — pick: todo / in-progress / done / archive / doc / skip):
    docs/random-notes.md  ?

Total: 11 source files → 11 backlog entries.
Apply? (yes / cancel)
```

### 3. Confirm

`yes` or `apply` → proceed. Anything else → exit cleanly. The user reruns the skill if they want a different result.

### 4. Apply

One backlog operation per source file. Prefer the MCP tools when the `backlog` MCP server is connected (`task_create`, `task_archive`, `document_create`); fall back to the `backlog` CLI otherwise. Either way:

- **Title** comes from the file's H1, or the filename (humanized) if there is no H1.
- **`plan` field** (for tasks) or **body** (for documents) is the source file's full content, verbatim. No edits, no Markdown cleanup, no rewording.
- **`notes` field** records the source path (e.g. `migrated from docs/plan/todo/login-flow.md`) so the user can trace back.
- **Status** comes from the mapping table.
- **Archived entries** are created as Done first, then archived in the same step.

Source files are left untouched. After applying, print a compact summary:

```
✓ Created 9 tasks (3 To Do, 1 In Progress, 2 Done, 1 archived)
✓ Created 4 reference documents

Originals are still in /docs — review and delete with `git rm` when you're confident the migration looks right.
Run `backlog board` to see the kanban.
```

## Edges

- Project already has populated `backlog/tasks/` → tell the user and exit; suggest `backlog task list` or `backlog board` instead.
- Input "docs" folder is generated reference material (Sphinx, TypeDoc, OpenAPI, etc.) → tell the user this skill is for handwritten docs and exit.
- User wants ongoing sync between docs and backlog → tell them this is one-shot migration, not sync.
