---
name: upgrade-project
description: >
  Safely migrates an existing agent-setup project to the latest generated format. Use when a repository was initialized by an older version and needs updated workflows, session entry docs, project skill overrides, or state fields without blindly overwriting user edits.
allowed-tools: Read, Write, Edit, Bash(mkdir:*), Bash(cp:*), Bash(ls:*), Bash(find:*), Bash(cat:*), Bash(test:*), Bash(diff:*), Bash(cmp:*), Bash(date:*), Bash(env:*), Bash($HOME/.claude/agent-setup/bin/render-templates.sh:*)
---

# upgrade-project — Safe Project Migration

## Purpose

`upgrade-project` migrates an already initialized repository to the latest framework-managed format.

Use it when:
- the project already contains `.claude/`, `.project/`, `AGENTS.md`, or `agent-setup/`
- `init-project` would skip existing generated files you now need to refresh
- generated project skills under `agent-setup/skills/` must be refreshed from the latest framework templates
- workflows must move from the old prose format to the new explicit orchestration format

Do not use `upgrade-project` for greenfield setup. Use `init-project` for that.

## Default mode

`upgrade-project` is preview-first.
It must not overwrite existing core generated files until it has:
1. detected what will change
2. shown a migration preview
3. received explicit confirmation in the current session

## Vault detection

Before starting, read `.project/state.json` and check `vault_project_path`.

If `vault_project_path` is set and non-null (**vault mode**):
- `AGENTS_DIR` = `<vault_project_path>/agents`
- `WORKFLOWS_DEF_DIR` = `<vault_project_path>/workflows/definitions`
- `SPEC_FILE` = `<vault_project_path>/spec/engineering-standards.md`

Otherwise (**legacy mode**):
- `AGENTS_DIR` = `agent-setup/agents`
- `WORKFLOWS_DEF_DIR` = `agent-setup/workflows`
- `SPEC_FILE` = `agent-setup/spec/engineering-standards.md`

## Migration scope

Migrate core files only:

**Always in repo:**
- `agent-setup/skills/*.md`
- `AGENTS.md`
- `.claude/CLAUDE.md`
- `.mcp.json` — Claude Code MCP servers (default: `context7`)
- `.codex/config.toml` — Codex CLI MCP servers (mirror of `.mcp.json`)
- `.project/state.json`
- the generated README block if it exists and is outdated

**UI projects only (when front-end stack detected):**
- `PRODUCT.md` — create if missing; never overwrite if present (user-authored)
- `DESIGN.md` — create if missing; never overwrite if present (user-authored)
- Impeccable skill install — run if not already present in `.claude/skills/impeccable/`

**In vault (vault mode) or repo (legacy mode):**
- `$WORKFLOWS_DEF_DIR/*.md`
- `$SPEC_FILE`

**Vault-only (vault mode):**
- `<vault_project_path>/_README.md` — refresh generated content; preserve user-authored sections
- `<vault_project_path>/_MOC_Sprints.md` — create if missing; otherwise leave user edits intact
- `<vault_project_path>/_MOC_Workflows.md` — same
- `<vault_project_path>/_MOC_Decisions.md` — same
- `<vault_project_path>/_MOC_Agents.md` — same
- `<vault_project_path>/sprints/sprint-001.md` — `needs-confirmation` if user edits detected; only inject missing frontmatter + `## 🔁 Workflow Runs` section when classified `replace`
- `<vault_project_path>/sprints/backlog.md` — same rule as sprint-001

Do not rewrite user source code or arbitrary project files.
After refreshing project-local `agent-setup/skills/*.md`, sync them to `.claude/skills/` and `.codex/skills/` as part of migration (see Phase 5.5).

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
- `.mcp.json`
- `.codex/config.toml`
- `.project/state.json`
- every file under `$WORKFLOWS_DEF_DIR/` that exists in the current framework templates
- every file under `agent-setup/skills/` that exists in the current framework templates
- the generated README block only, not the full file
- `$AGENTS_DIR/designer/agent.md` — classify as `replace` when it lacks the `## Design workflow` section (introduced in framework v1.10.0)
- `$AGENTS_DIR/test-writer/agent.md` — classify as `create` when missing (new agent role introduced in framework v1.11.0)
- `$AGENTS_DIR/developer/agent.md` — classify as `replace` when it lacks a `§11` / TDD green-phase reference (introduced in framework v1.11.0)
- `$AGENTS_DIR/qa-reviewer/agent.md` — classify as `replace` when it lacks a TDD adherence backstop reference (introduced in framework v1.11.0)
- `PRODUCT.md` — classify as `create` if missing on a UI project; `skip` if present (user-authored, never overwrite)
- `DESIGN.md` — same rule as `PRODUCT.md`

Detection rules:
- prefer generated markers such as `<!-- generated-by: /init-project -->`
- for `$AGENTS_DIR/designer/agent.md`: if the file lacks the `## Design workflow` section, treat it as pre-v1.10.0 and mark it `replace`. If it contains signs of custom user editing beyond the generated sections, mark it `needs-confirmation`.
- for `$AGENTS_DIR/test-writer/agent.md`: if the directory/file does not exist, mark `create`; this is additive and never overwrites existing agents.
- for `$AGENTS_DIR/developer/agent.md` and `$AGENTS_DIR/qa-reviewer/agent.md`: if the file has no mention of `test-writer` or `§11`, treat as pre-v1.11.0 and mark `replace`; if it shows custom user editing beyond the generated sections, mark `needs-confirmation`.
- for `PRODUCT.md` and `DESIGN.md`: always `skip` if the file exists — these are user-authored context files. Only `create` when absent on a UI project.
- for `$SPEC_FILE`, if the file lacks the `## 9. Active Refactoring` header, treat it as outdated and mark it `replace` (the §9 active-refactoring core principle was added in framework v1.7.0 — projects initialised earlier are missing it)
- for `$SPEC_FILE`, if the file lacks the `## 11. Test-Driven Development` header, treat it as outdated and mark it `replace` (TDD was made the default development strategy in framework v1.11.0)
- for the `analyze-design-dev-review` workflow, if `Stage 3 - Implement` exists instead of `Stage 3a - Red` / `3b - Green` / `3c - Refactor`, treat it as pre-v1.11.0 and mark `replace`
- for workflows, if the current file lacks explicit stage fields like `Agent:` / `Inputs:` / `Outputs:` / `Pass:` / `OnFailure:`, treat it as old generated content and mark it `replace` unless there is strong evidence of custom user editing
- for project skills, prefer replacement when the file still looks framework-generated; if it contains user-specific edits beyond stack adaptation, classify it `needs-confirmation`
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
- create `.mcp.json` if missing; if present, classify `needs-confirmation` (user may have added custom servers) and leave alone unless confirmed
- create `.codex/config.toml` if missing; same `needs-confirmation` rule when it already exists
- update only the generated block inside `README.md` if that block exists and is outdated
- never rewrite user-authored README content outside the generated marker block

### 5.1b Engineering standards & agent templates

**Active refactoring rollout (v1.7.0):**
- Refresh `$SPEC_FILE` whenever the `## 9. Active Refactoring` section is missing. Always create a backup first.
- Refresh `$AGENTS_DIR/developer/agent.md` and `$AGENTS_DIR/qa-reviewer/agent.md` whenever they lack the "Active refactoring" Responsibilities/Guardrails block.

**Designer agent v1.10.0 upgrade:**
- Refresh `$AGENTS_DIR/designer/agent.md` whenever the file lacks the `## Design workflow` section, applying the standard `replace` vs `needs-confirmation` classification.
- The new designer agent introduces: 3-phase workflow (Design Thinking → design doc → Impeccable quality gate), `frontend-design` skill integration, anti-convergence guardrails, and expanded DoD.

**TDD rollout (v1.11.0) — TDD becomes the default development strategy:**
- Create `$AGENTS_DIR/test-writer/agent.md` and `$AGENTS_DIR/test-writer/memory.md` if the directory is missing (render from the `test-writer` and `_memory` templates). This is purely additive.
- Refresh `$AGENTS_DIR/developer/agent.md` whenever it lacks a `test-writer` / `§11` reference: the developer role changes from "write code and tests" to green-phase-only (receives a failing test, writes minimal code, never edits the test).
- Refresh `$AGENTS_DIR/qa-reviewer/agent.md` whenever it lacks the TDD adherence backstop: the reviewer now checks that a `test:` commit precedes the implementation commit and rejects tautological tests.
- Refresh `$SPEC_FILE` whenever it lacks `## 11. Test-Driven Development`. Always create a backup first.
- Replace the `analyze-design-dev-review` workflow whenever `Stage 3 - Implement` is still a single monolithic stage: it splits into `3a - Red` (test-writer), `3b - Green` (developer), `3c - Refactor` (developer).
- Refresh `run-tests` under `agent-setup/skills/` whenever it lacks `expect-fail` mode.

Apply the standard `replace` vs `needs-confirmation` classification for all agent template refreshes. Do not rewrite `$AGENTS_DIR/*/memory.md` — memory is append-only.

### 5.2 Workflows
- create missing framework workflows under `$WORKFLOWS_DEF_DIR/`
- replace old prose workflows with the current explicit stage format
- if a workflow file was classified `needs-confirmation`, only replace it after confirmation

### 5.2b Vault MOCs and entry docs (vault mode only)
Skip this section entirely in legacy mode.
- create `<vault_project_path>/_MOC_Sprints.md`, `_MOC_Workflows.md`, `_MOC_Decisions.md`, `_MOC_Agents.md` if absent (render from `templates/obsidian/_MOC_*.md.tpl`)
- refresh `<vault_project_path>/_README.md` only if it lacks the `## Maps of Content` section — insert that section above the existing `## Quick links` block; leave other sections untouched
- for `sprints/sprint-001.md` and `sprints/backlog.md`: if classified `replace`, inject the frontmatter block from the latest template at the top of the file (skip if frontmatter already present); add `## 🔁 Workflow Runs` section if missing
- never rewrite agent memory files, decisions, designs, spikes, releases, or workflow run artifacts — those are append-only history

### 5.1c Impeccable design integration (UI projects only)

**UI detection** — a project is considered a UI project when any of the following is true:
- `package.json` contains at least one dependency matching: `react`, `vue`, `next`, `svelte`, `angular`, `solid`, `@angular`
- The project stack detected in `.project/state.json` is `Next.js`, `Node/JS`, or a front-end variant

**Impeccable install** — skip each if already present.

```bash
# Impeccable — anti-pattern scanner + quality gate
test -f ".claude/skills/impeccable/SKILL.md" \
  || npx --yes skills add pbakaus/impeccable

# frontend-design (Anthropic) — aesthetic direction + Design Thinking scaffolding
test -f ".claude/skills/frontend-design/SKILL.md" \
  || npx --yes skills add anthropics/claude-code#plugins/frontend-design
```

**`PRODUCT.md`** — create only if the file does not exist:

Generate with this structure, extracting from `vision.md` where available (use `TO CLARIFY` otherwise):
```markdown
# Product Design Context
<!-- generated-by: /upgrade-project -->

## Who we're designing for
<personas extracted from vision.md, or TO CLARIFY>

## Brand voice
<tone and personality extracted from vision.md, or TO CLARIFY>

## Anti-references (styles to avoid)
<extracted from vision.md, or TO CLARIFY>
```

**`DESIGN.md`** — create only if the file does not exist:
```markdown
# Design Spec
<!-- generated-by: /upgrade-project -->

> Generated stub — run `/impeccable document` to build the full spec.

## Design system
TO CLARIFY

## Color tokens
TO CLARIFY

## Typography scale
TO CLARIFY
```

If Impeccable install fails (e.g. `npx` unavailable), note the manual command in the final report and continue — do not block the migration.

### 5.3 Project skill overrides
- create missing framework skill overrides under `agent-setup/skills/`
- replace outdated generated skill overrides with the freshly rendered versions
- if a skill file was classified `needs-confirmation`, only replace it after confirmation

### 5.4 Project state
- update `.project/state.json` by preserving existing values and ensuring the orchestration keys exist:
  - `last_workflow_stage`
  - `last_workflow_result`
  - `active_workflow_run`
  - `workflow_runs`
  - `repos` (add as `[]` if missing — never overwrite an existing non-empty array)
  - `vault_path` (add as `null` if missing — never overwrite an existing value)
  - `vault_project_path` (add as `null` if missing — never overwrite an existing value)
- do not reset unrelated state fields such as sprint counters or existing clarifications

### 5.5 Runtime skill sync
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
2. Review migrated project skills under `agent-setup/skills/`
3. Review `.claude/CLAUDE.md` and `AGENTS.md`
4. Inspect `.project/state.json` orchestration fields
5. *(UI projects)* Fill `PRODUCT.md` (audience, brand voice, anti-references) and run `/impeccable document` to generate the full `DESIGN.md`
6. *(UI projects)* Run `/impeccable teach` so the designer agent loads the new context
7. If `test-writer` was newly created, mention it to the team: sprint tasks using `analyze-design-dev-review` now route through it automatically at Stage 3a
8. Run `run-workflow <workflow> <task-id|task-text>` or `sprint 001` to validate the upgraded project

## Hard rules
- Never touch files outside the managed core paths listed above
- Never overwrite ambiguous files without explicit confirmation
- Never delete user content as part of v1 migration
- Never use `init-project` as a destructive migration surrogate
