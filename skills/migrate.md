---
name: migrate
description: >
  Migrates an existing agent-setup project to an Obsidian vault. Moves .project/ content (vision, sprints, decisions, designs, spikes, releases, workflow runs) and agent-setup/ (agents, workflows definitions, spec) to the vault, leaving only .project/state.json, .claude/, .codex/, and agent-setup/skills/ in the repo. Args: vault_path=/abs/path (required).
allowed-tools: Read, Write, Edit, Bash(mkdir:*), Bash(cp:*), Bash(mv:*), Bash(ls:*), Bash(find:*), Bash(cat:*), Bash(test:*), Bash(rm:*), Bash(date:*), Bash(jq:*)
---

# migrate — Obsidian Vault Migration

## Purpose

`migrate` moves an initialized project's knowledge artifacts from the repo into a centralized Obsidian vault, leaving only the minimal repo footprint:
- `.project/state.json` (updated with vault_path)
- `.claude/` (CLAUDE.md, settings.json, skills overrides)
- `.codex/skills/`
- `agent-setup/skills/` (stack-specific skill overrides)

## Arguments
- Named arg `vault_path=<abs-path>` = absolute path to the Obsidian vault (required)

## Non-negotiable rules

1. **Never delete from repo until successfully copied to vault.** Copy first, verify, then remove.
2. If vault project folder already exists and has conflicting files, prompt for action (merge / skip / overwrite) per file.
3. **Idempotent**: if `vault_path` is already set in `.project/state.json`, report already migrated and suggest `upgrade-project`. Do not re-migrate.
4. Preserve `.claude/skills/`, `.codex/skills/`, and `agent-setup/skills/` in repo — these are runtime overrides, not knowledge files.
5. Create a backup in `.project/upgrades/<timestamp>/` before deleting anything from the repo.
6. Never modify user source code.

## Phase 0 — Preflight

Verify:
```bash
test -f .project/state.json || { echo "No .project/state.json found. Run /init-project first." >&2; exit 2; }
```

Parse arguments for `vault_path=<value>`. If absent, stop and report: "vault_path is required. Usage: /migrate vault_path=/abs/path/to/vault".

Check idempotency:
```bash
jq -r '.vault_path // empty' .project/state.json
```
If `vault_path` is already set and non-null, report: "Already migrated to vault at <path>. Use /upgrade-project to refresh framework files." and stop.

Read project context from `.project/state.json`:
- `project_name`
- `stack`, `architecture_style`

Compute:
- `VAULT_PATH` = provided vault_path argument
- `VAULT_PROJECT_PATH` = `$VAULT_PATH/$project_name`

## Phase 1 — Build migration manifest

Scan the following source paths and classify each existing file:

**From `.project/` → `$VAULT_PROJECT_PATH/`:**
- `.project/vision.md` → `vision.md`
- `.project/sprints/` → `sprints/`
- `.project/decisions/` → `decisions/`
- `.project/designs/` → `designs/`
- `.project/spikes/` → `spikes/`
- `.project/releases/` → `releases/`
- `.project/workflows/` → `workflows/runs/`

**From `agent-setup/` → `$VAULT_PROJECT_PATH/`:**
- `agent-setup/agents/` (excluding `specialized/` if empty) → `agents/`
- `agent-setup/workflows/` → `workflows/definitions/`
- `agent-setup/spec/` → `spec/`

For each destination file, classify:
- `create` — destination does not exist
- `conflict` — destination already exists with different content

## Phase 2 — Preview

Display the migration plan as a table:

```
Migration preview for <project_name>
Vault: <VAULT_PATH>
Project vault path: <VAULT_PROJECT_PATH>

FROM                              → TO (in vault)                               STATUS
.project/vision.md                → vision.md                                   create
.project/sprints/backlog.md       → sprints/backlog.md                          create
...
agent-setup/agents/developer/...  → agents/developer/...                        create

Files to REMOVE from repo after migration:
- .project/vision.md
- .project/sprints/
- .project/decisions/
- .project/designs/
- .project/spikes/
- .project/releases/
- .project/workflows/
- agent-setup/agents/
- agent-setup/workflows/
- agent-setup/spec/

Files to KEEP in repo:
- .project/state.json (updated with vault_path)
- .claude/
- .codex/
- agent-setup/skills/
```

For each `conflict`, list the file and ask: overwrite / skip / abort?

Then ask for explicit confirmation before proceeding.

## Phase 3 — Create vault structure

```bash
mkdir -p "$VAULT_PATH/.obsidian"
mkdir -p "$VAULT_PROJECT_PATH/"{agents/specialized,workflows/definitions,workflows/runs,sprints,decisions,designs,spikes,releases,spec}
```

If `$VAULT_PATH/.obsidian/app.json` does not exist, create a minimal Obsidian config:
```json
{
  "legacyEditor": false,
  "livePreview": true,
  "defaultViewMode": "source",
  "alwaysUpdateLinks": true,
  "useMarkdownLinks": false
}
```

If `$VAULT_PATH/_index.md` does not exist, create it with a project entry. If it exists, append the project link if not already listed.

## Phase 4 — Copy files to vault

Copy in this order (stop on any copy failure):

1. Copy `.project/vision.md` → `$VAULT_PROJECT_PATH/vision.md`
2. Copy `.project/sprints/` → `$VAULT_PROJECT_PATH/sprints/`
3. Copy `.project/decisions/` → `$VAULT_PROJECT_PATH/decisions/`
4. Copy `.project/designs/` → `$VAULT_PROJECT_PATH/designs/`
5. Copy `.project/spikes/` → `$VAULT_PROJECT_PATH/spikes/`
6. Copy `.project/releases/` → `$VAULT_PROJECT_PATH/releases/`
7. Copy `.project/workflows/` → `$VAULT_PROJECT_PATH/workflows/runs/`
8. Copy `agent-setup/agents/` → `$VAULT_PROJECT_PATH/agents/`
9. Copy `agent-setup/workflows/` → `$VAULT_PROJECT_PATH/workflows/definitions/`
10. Copy `agent-setup/spec/` → `$VAULT_PROJECT_PATH/spec/`

For `conflict` files: apply the per-file resolution chosen in Phase 2.

Generate four Maps of Content (MOCs) at the vault project root. These are the entry points the AI agents search first — link them from `_README.md`.

`$VAULT_PROJECT_PATH/_MOC_Sprints.md`:
```markdown
---
tags: [moc, sprints]
parent: "[[_README]]"
---
# 🗓 Sprints MOC

> Index of every sprint, its tasks, and the workflow runs they triggered. Update by appending — never rewrite history.

## Active
- [[sprints/sprint-001]] — <goal>

## Archive
<!-- - [[sprints/sprint-000]] — <goal> -->

## Recent task → run map
<!-- Append on each completed run -->
<!-- | Task | Sprint | Workflow run | Verdict | Date | -->
```

`$VAULT_PROJECT_PATH/_MOC_Workflows.md`:
```markdown
---
tags: [moc, workflows]
parent: "[[_README]]"
---
# 🔁 Workflows MOC

## Definitions
- [[workflows/definitions/analyze-design-dev-review]]
- [[workflows/definitions/bug-triage]]
- [[workflows/definitions/spike-research]]
- [[workflows/definitions/release]]

## Recent runs
<!-- Append newest first. -->
<!-- - YYYY-MM-DD — [[workflows/runs/<run-id>]] — <workflow> — <task> — <verdict> -->
```

`$VAULT_PROJECT_PATH/_MOC_Decisions.md`:
```markdown
---
tags: [moc, decisions]
parent: "[[_README]]"
---
# 📜 Decisions MOC

## Accepted
<!-- - [[decisions/ADR-001-<slug>]] — <one-line summary> — triggered by [[sprints/sprint-NNN#US-XXX]] -->

## Proposed
## Superseded
```

`$VAULT_PROJECT_PATH/_MOC_Agents.md`:
```markdown
---
tags: [moc, agents]
parent: "[[_README]]"
---
# 🤖 Agents MOC

| Agent | Definition | Memory | Recent task |
|-------|------------|--------|-------------|
| Product Owner | [[agents/product-owner/agent]] | [[agents/product-owner/memory]] | — |
| Developer | [[agents/developer/agent]] | [[agents/developer/memory]] | — |
| Designer | [[agents/designer/agent]] | [[agents/designer/memory]] | — |
| Analyst | [[agents/analyst/agent]] | [[agents/analyst/memory]] | — |
| QA Reviewer | [[agents/qa-reviewer/agent]] | [[agents/qa-reviewer/memory]] | — |
| Tech Lead | [[agents/tech-lead/agent]] | [[agents/tech-lead/memory]] | — |
```

Generate `$VAULT_PROJECT_PATH/_README.md` (project overview with [[wikilinks]]):
```markdown
---
tags: [project/<project_name>]
---
# <project_name>
> Stack: <stack> · Architecture: <architecture_style>

## Maps of Content
- [[_MOC_Sprints|🗓 Sprints]]
- [[_MOC_Workflows|🔁 Workflows]]
- [[_MOC_Decisions|📜 Decisions]]
- [[_MOC_Agents|🤖 Agents]]

## Quick links
- [[vision|Vision]]
- [[sprints/backlog|Backlog]]
- [[spec/engineering-standards|Engineering Standards]]

## Agents
- [[agents/developer/agent|Developer]]
- [[agents/product-owner/agent|Product Owner]]
...
```

## Phase 5 — Create backup of repo files to be removed

Create backup directory:
```bash
mkdir -p .project/upgrades/<timestamp>
```

Copy to backup (before deleting):
- `.project/vision.md`
- `.project/sprints/`
- `.project/decisions/`, `designs/`, `spikes/`, `releases/`, `workflows/`
- `agent-setup/agents/`
- `agent-setup/workflows/`
- `agent-setup/spec/`

Write `.project/upgrades/<timestamp>/summary.md` with: timestamp, vault destination, list of files moved.

## Phase 6 — Update state.json

Update `.project/state.json` using jq or Edit:
- Set `vault_path` = `$VAULT_PATH`
- Set `vault_project_path` = `$VAULT_PROJECT_PATH`
- Set `vision_source` = `$VAULT_PROJECT_PATH/vision.md`
- Set `engineering_spec` = `$VAULT_PROJECT_PATH/spec/engineering-standards.md`
- Set `last_updated` = ISO now

Do not touch any other state.json fields.

## Phase 7 — Remove migrated files from repo

Remove only files/dirs successfully copied:

```bash
rm -f .project/vision.md
rm -rf .project/sprints .project/decisions .project/designs .project/spikes .project/releases .project/workflows
rm -rf agent-setup/agents agent-setup/workflows agent-setup/spec
```

If `agent-setup/` is now empty (only contained the removed dirs), remove it:
```bash
rmdir agent-setup 2>/dev/null || true
```

## Phase 8 — Final report

Report:
- Vault path and project vault path
- Files migrated to vault (count)
- Files kept in repo
- Backup location: `.project/upgrades/<timestamp>/`
- state.json updated fields

Recommended next actions:
1. Open vault in Obsidian: `obsidian "$VAULT_PATH"`
2. Review `$VAULT_PROJECT_PATH/_README.md`
3. Review `$VAULT_PROJECT_PATH/vision.md`
4. Run `sprint 001` — skills now resolve paths via vault_project_path in state.json
5. Open `.claude/CLAUDE.md` — paths updated to point to vault
