---
name: upgrade-project
description: >
  Safely migrates an existing agent-setup project to the latest generated format. Use when a repository was initialized by an older version and needs updated workflows, session entry docs, or state fields without blindly overwriting user edits.
allowed-tools: Read, Write, Edit, Bash(mkdir:*), Bash(cp:*), Bash(ls:*), Bash(find:*), Bash(cat:*), Bash(test:*), Bash(diff:*), Bash(cmp:*), Bash(date:*), Bash(env:*), Bash($HOME/.claude/agent-setup/bin/render-templates.sh:*)
---

# upgrade-project — Safe Project Migration

## Purpose

`upgrade-project` migrates an already initialized repository to the latest framework-managed format.

Use it when:
- the project already contains `.claude/`, `.project/`, `AGENTS.md`, or `agent-setup/`
- `init-project` would skip existing generated files you now need to refresh
- workflows must move from the old prose format to the new explicit orchestration format

Do not use `upgrade-project` for greenfield setup. Use `init-project` for that.

## Default mode

`upgrade-project` is preview-first.
It must not overwrite existing core generated files until it has:
1. detected what will change
2. shown a migration preview
3. received explicit confirmation in the current session

## Migration scope

Migrate core files only:
- `agent-setup/workflows/*.md`
- `AGENTS.md`
- `.claude/CLAUDE.md`
- `.project/state.json`
- the generated README block if it exists and is outdated

Do not rewrite user source code or arbitrary project files.
Sync project-local `agent-setup/skills/*.md` to `.claude/skills/` and `.codex/skills/` as part of migration (see Phase 5.4).

## Phase 0 — Preflight

```bash
test -x "${CLAUDE_HOME:-$HOME/.claude}/agent-setup/bin/render-templates.sh" \
  || { echo "Framework not installed. Run: bash bootstrap.sh --force (from the agent-setup repo)" >&2; exit 2; }

test -d .project -o -d agent-setup -o -f AGENTS.md -o -d .claude \
  || { echo "This repository does not look initialised. Use /init-project instead." >&2; exit 2; }
```

If preflight fails, stop and report the exact reason.

## Phase 1 — Build a temporary fresh render

Create a temporary directory and render the latest framework output into it using the current project's context.

Requirements:
- reuse the existing `.project/vision.md` when present
- detect current project metadata the same way `init-project` does
- call the renderer once to build a fresh candidate tree under the temp directory
- do not write repo-tracked files during this phase

This temporary render is the source of truth for comparison.

## Phase 2 — Detect and classify core files

For each managed path, classify it as exactly one of:
- `create` — missing in the project, safe to add
- `replace` — exists and appears framework-generated and unchanged enough to refresh safely
- `needs-confirmation` — exists but appears user-modified or ambiguous
- `skip` — already up to date

Managed paths:
- `AGENTS.md`
- `.claude/CLAUDE.md`
- `.project/state.json`
- every file under `agent-setup/workflows/` that exists in the current framework templates
- the generated README block only, not the full file

Detection rules:
- prefer generated markers such as `<!-- generated-by: /init-project -->`
- for workflows, if the current file lacks explicit stage fields like `Agent:` / `Inputs:` / `Outputs:` / `Pass:` / `OnFailure:`, treat it as old generated content and mark it `replace` unless there is strong evidence of custom user editing
- for `.project/state.json`, preserve current values where possible; treat missing orchestration keys as migration targets, not as a reason to reset the whole file blindly
- if a file differs from the fresh render and contains signs of hand edits, classify it `needs-confirmation`

## Phase 3 — Show the preview

Print a migration summary grouped by action:
- Create
- Replace
- Needs confirmation
- Skip

For each `needs-confirmation` file, explain why it is ambiguous.

Do not modify repo-tracked files yet.

Then ask for explicit confirmation to proceed with the proposed creates/replacements.
If confirmation is not granted, stop after printing the preview.

## Phase 4 — Backup before overwrite

Before any overwrite, create a dated migration backup folder:

```text
.project/upgrades/<timestamp>/
```

Inside it, store:
- backup copies of every file that will be replaced
- `summary.md` listing each action taken, source path, backup path, and reason

Create backups only for files that will actually be overwritten.

## Phase 5 — Apply migration

### 5.1 Core docs
- create or replace `AGENTS.md`
- create or replace `.claude/CLAUDE.md`
- update only the generated block inside `README.md` if that block exists and is outdated
- never rewrite user-authored README content outside the generated marker block

### 5.2 Workflows
- create missing framework workflows under `agent-setup/workflows/`
- replace old prose workflows with the current explicit stage format
- if a workflow file was classified `needs-confirmation`, only replace it after confirmation

### 5.3 Project state
- update `.project/state.json` by preserving existing values and ensuring the orchestration keys exist:
  - `last_workflow_stage`
  - `last_workflow_result`
  - `active_workflow_run`
  - `workflow_runs`
  - `repos` (add as `[]` if missing — never overwrite an existing non-empty array)
- do not reset unrelated state fields such as sprint counters or existing clarifications

### 5.4 Project skill overrides
Sync every `agent-setup/skills/*.md` to both runtime directories so project-level overrides stay current:

```bash
for skill_file in agent-setup/skills/*.md; do
  skill_name="$(basename "$skill_file" .md)"
  mkdir -p ".claude/skills/$skill_name"
  cp "$skill_file" ".claude/skills/$skill_name/SKILL.md"
  mkdir -p ".codex/skills/$skill_name"
  cp "$skill_file" ".codex/skills/$skill_name/SKILL.md"
done
```

## Phase 6 — Final report

Report:
- created files
- replaced files
- skipped files
- files left untouched because confirmation was not granted
- backup directory path
- recommended next actions

Recommended next actions:
1. Review migrated workflows under `agent-setup/workflows/`
2. Review `.claude/CLAUDE.md` and `AGENTS.md`
3. Inspect `.project/state.json` orchestration fields
4. Run `run-workflow <workflow> <task-id|task-text>` or `sprint 001` to validate the upgraded project

## Hard rules
- Never touch files outside the managed core paths listed above
- Never overwrite ambiguous files without explicit confirmation
- Never delete user content as part of v1 migration
- Never use `init-project` as a destructive migration surrogate
