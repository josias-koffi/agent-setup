---
name: run-agent
description: >
  Runs a specific agent on an ad hoc task outside sprint files. Args: agent task. Use when the user wants a project-scoped single-agent execution that is not tied to .project/sprints/sprint-NNN.md.
allowed-tools: Read, Write, Bash(git:*), Bash(npm:*), Bash(cargo:*), Bash(pytest:*), Bash(go:*)
---

# run-agent runner

## Purpose

`run-agent` is a single-agent executor. It does not orchestrate handoffs between multiple agents. If the user wants stage-by-stage multi-agent execution with persisted outputs between agents, use `run-workflow` instead.

## Arguments
- `$ARGUMENTS[0]` = agent name
- `$ARGUMENTS[1...]` = task text

Example:
- `run-agent developer Fix checkout race condition`
- `run-agent qa-reviewer Review recent checkout changes for regressions`

## Strict sequence

### 0. Path resolution

Read `.project/state.json`. Extract `vault_project_path` (may be null or absent).

If `vault_project_path` is set and non-null, use vault paths:
- `SPEC_FILE` = `<vault_project_path>/spec/engineering-standards.md`
- `AGENTS_DIR` = `<vault_project_path>/agents`
- `VISION_FILE` = `<vault_project_path>/vision.md`

Otherwise (legacy mode):
- `SPEC_FILE` = `agent-setup/spec/engineering-standards.md`
- `AGENTS_DIR` = `agent-setup/agents`
- `VISION_FILE` = `.project/vision.md`

### 1. Load context

Load in this order to maximise prompt-cache hits (stable content first, dynamic last).

**Static — load first (cache candidates for Claude Code):**
- `$SPEC_FILE`
- `.claude/CLAUDE.md`
- `AGENTS.md`
- `$AGENTS_DIR/<agent>/agent.md`

**Semi-static — load next:**
- `$AGENTS_DIR/<agent>/memory.md`

**Dynamic — load last:**
- `.project/state.json`

**Repo discovery (inline, after state.json load):**
If `state.json.repos` contains any entry where `name`, `stack`, or `role` is `null`:
1. For each such entry, read the manifest file at its `path` (priority: `package.json` → `Cargo.toml` → `go.mod` → `composer.json` → `pyproject.toml` → `requirements.txt`)
2. Detect `name` (package name or dirname), `stack`, `description` (manifest description or first non-blank README line), `role` (infer from name/description: `frontend` | `backend` | `mobile` | `lib` | `infra`)
3. Write detected fields back to that repo entry in `.project/state.json`
4. Sync the updated `repos` array to every sibling repo that has a `.project/state.json` — replace only the `repos` field, leave all other fields untouched; skip silently if the sibling has no `.project/state.json`
This is a one-time cost per repo. On subsequent runs all fields are populated and no probe occurs.
If `state.json.repos` is non-empty after discovery, prepend a compact repos block to the task context before agent execution:
```
## Available Repositories (N)
- <role> [<stack>] <name> at <path> — <description>
```

**Lazy — load only when needed:**
- `$VISION_FILE`: load only if the agent's Inputs list it or the task explicitly requires vision context. Skip otherwise.

### 2. Validate
Stop on failure if:
- bootstrap files are missing
- the agent definition is missing
- task text is empty

### 3. Run the task
- Execute the selected agent against the free-form task.
- Do not attempt multi-agent handoffs from inside `run-agent`.
- Do not load or require a workflow.
- Blocking failures stop execution.
- Advisory failures are warnings.

### 4. Update project state
- Do not touch sprint files.
- Update `.project/state.json > last_updated`.
- Do not create `.project/workflows/<run-id>/` artifacts unless the user explicitly asked for `run-workflow`.

### 5. Update agent memory
Append a dated entry to `$AGENTS_DIR/<agent>/memory.md` using the linked format:
```
## <YYYY-MM-DD> — <task short title> (ad hoc · run-agent)
- **Context**: ad hoc · last sprint [[sprints/sprint-<NNN>]] · last run [[workflows/runs/<state.last_workflow_run-id>]] (if any)
- **Did**: <what was done>
- **Why**: <reason>
- **Learned**: <insight>
- **Open**: <unresolved — link to [[decisions/ADR-...]] or [[spikes/SPIKE-...]] if produced>
```
Wikilinks must point to vault-relative paths when `vault_project_path` is set; in legacy mode, write the same logical paths anyway so the graph survives `/migrate`.

### 6. Report
Include:
- agent
- task
- blocking verdict
- advisory warnings
- next action
