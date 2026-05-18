---
name: run-workflow
description: >
  Orchestrates a named multi-agent workflow end to end. Args: workflow task-id|task-text. Accepts a pre-built workflow name (e.g. analyze-design-dev-review) or a dynamic agent chain (e.g. developer-qa-reviewer-tech-lead). Use when the user wants stage-by-stage execution where each agent output becomes the next stage input and artifacts are persisted under .project/workflows/.
allowed-tools: Read, Write, Bash(git:*), Bash(npm:*), Bash(cargo:*), Bash(pytest:*), Bash(go:*)
---

# run-workflow orchestrator

## Purpose

`run-workflow` is the dedicated multi-agent orchestrator. It executes one workflow stage at a time, with the agent assigned to that stage, and persists handoff artifacts so the next agent reads concrete prior output.

Use `run-workflow` for true agent chaining.
Use `sprint` for sprint-scoped workflow execution.
Use `run-agent` for single-agent execution.

## Arguments
- `$ARGUMENTS[0]` = workflow spec — either a pre-built workflow name or a dynamic agent chain
- `$ARGUMENTS[1...]` = task reference or free-form task text

Examples:
- `run-workflow analyze-design-dev-review US-005`
- `run-workflow analyze-design-dev-review fix auth error when using social auth`
- `run-workflow developer-qa-reviewer US-012`
- `run-workflow analyst-tech-lead-developer spike on caching strategy`

## Path resolution

Read `.project/state.json`. Extract `vault_project_path` (may be null or absent).

If `vault_project_path` is set and non-null, use vault paths:
- `SPEC_FILE` = `<vault_project_path>/spec/engineering-standards.md`
- `AGENTS_DIR` = `<vault_project_path>/agents`
- `WORKFLOWS_DEF_DIR` = `<vault_project_path>/workflows/definitions`
- `WORKFLOWS_RUNS_DIR` = `<vault_project_path>/workflows/runs`
- `SPRINTS_DIR` = `<vault_project_path>/sprints`
- `VISION_FILE` = `<vault_project_path>/vision.md`

Otherwise (legacy mode):
- `SPEC_FILE` = `agent-setup/spec/engineering-standards.md`
- `AGENTS_DIR` = `agent-setup/agents`
- `WORKFLOWS_DEF_DIR` = `agent-setup/workflows`
- `WORKFLOWS_RUNS_DIR` = `.project/workflows`
- `SPRINTS_DIR` = `.project/sprints`
- `VISION_FILE` = `.project/vision.md`

## Workflow resolution

Resolve `$ARGUMENTS[0]` using the following priority order:

### 1. Pre-built workflow file
Check whether `$WORKFLOWS_DEF_DIR/<arg>.md` exists.
- If it does, load it and follow the **Required workflow format** rules below.

### 2. Dynamic agent chain
If no workflow file is found, treat the argument as a hyphen-separated list of agent names and split it into segments.
- For each segment, verify that `$AGENTS_DIR/<segment>/agent.md` exists.
- If every segment resolves to a valid agent, construct a **dynamic stage list** (see below).
- If any segment does not resolve, stop and report which segments are unknown.

### Dynamic stage list construction
Given a chain `agent1-agent2-agentN`, synthesize stages at runtime:

```
Stage 1
  Agent: agent1
  Inputs:
    - $WORKFLOWS_RUNS_DIR/<run-id>/task.md
  Outputs:
    - $WORKFLOWS_RUNS_DIR/<run-id>/01-agent1.md
  Pass: output file written and non-empty
  OnFailure: Stop

Stage 2
  Agent: agent2
  Inputs:
    - $WORKFLOWS_RUNS_DIR/<run-id>/task.md
    - $WORKFLOWS_RUNS_DIR/<run-id>/01-agent1.md
  Outputs:
    - $WORKFLOWS_RUNS_DIR/<run-id>/02-agent2.md
  Pass: output file written and non-empty
  OnFailure: Stop

...

Stage N
  Agent: agentN
  Inputs:
    - $WORKFLOWS_RUNS_DIR/<run-id>/task.md
    - all prior artifacts $WORKFLOWS_RUNS_DIR/<run-id>/NN-*.md
  Outputs:
    - $WORKFLOWS_RUNS_DIR/<run-id>/0N-agentN.md
  Pass: output file written and non-empty
  OnFailure: Stop
```

Each agent must produce its output artifact before the next agent begins. Each agent reads all prior artifacts in full to maintain context continuity. The run-id used for the directory is `<chain-slug>-<YYYYMMDDHHMMSS>` where `<chain-slug>` is the full `agent1-agent2-agentN` string.

**Artifact size cap**: every stage output file must not exceed 400 words (~2 500 characters). Summarise rather than quote when output would exceed this limit.

## Obsidian linking protocol (vault mode)

Every artifact written by this skill MUST be linkable through the Obsidian graph. Apply this whenever `vault_project_path` is set in `.project/state.json`.

### Stage artifact frontmatter
Each stage output file (`$WORKFLOWS_RUNS_DIR/<run-id>/NN-<agent>.md`) starts with:
```yaml
---
tags: [run/<run-id>, workflow/<workflow-name>, agent/<stage-agent>, sprint/<sprint-NNN>, stage/<NN>]
run: "[[workflows/runs/<run-id>/task]]"
workflow_def: "[[workflows/definitions/<workflow-name>]]"
agent: "[[agents/<stage-agent>/agent]]"
sprint_task: "[[sprints/sprint-<NNN>#<task-id>]]"   # omit if ad hoc
previous_stage: "[[workflows/runs/<run-id>/<NN-1>-<prev-agent>]]"  # omit on stage 1
---
```
For ad hoc tasks, omit `sprint_task` and the `sprint/<NNN>` tag.

### Stage artifact body footer
Append at the end of every stage artifact (after the agent's verdict block):
```
---
**Navigation**: [[workflows/runs/<run-id>/task|Task]] · prev [[workflows/runs/<run-id>/<NN-1>-<prev-agent>]] · next [[workflows/runs/<run-id>/<NN+1>-<next-agent>]]
```

### Run task.md
The `task.md` written in step 2 starts with:
```yaml
---
tags: [run/<run-id>, workflow/<workflow-name>, sprint/<sprint-NNN>]
workflow_def: "[[workflows/definitions/<workflow-name>]]"
sprint_task: "[[sprints/sprint-<NNN>#<task-id>]]"
---
```

### final-summary.md
Starts with frontmatter linking every stage:
```yaml
---
tags: [run/<run-id>, run/final, workflow/<workflow-name>, sprint/<sprint-NNN>, verdict/<passed|failed>]
stages: ["[[workflows/runs/<run-id>/01-...]]", "[[workflows/runs/<run-id>/02-...]]", ...]
sprint_task: "[[sprints/sprint-<NNN>#<task-id>]]"
---
```

### Sprint file back-reference
On successful start AND on completion, append a line under the sprint file's `## 🔁 Workflow Runs` section (create the section if absent):
```
- <YYYY-MM-DD> — [[workflows/runs/<run-id>|<workflow-name>]] (<task-id>) — <verdict>
```

### Workflow definition back-reference
On run start, append a line under the workflow definition file's `## Used by` section (create it if absent):
```
- [[sprints/sprint-<NNN>#<task-id>]] — <YYYY-MM-DD> → [[workflows/runs/<run-id>]]
```

### Memory entry format
Every per-stage memory entry appended to `$AGENTS_DIR/<stage-agent>/memory.md` MUST use:
```
## <YYYY-MM-DD> — <task-id or short title> (stage <NN> · [[workflows/runs/<run-id>]])
- **Context**: [[sprints/sprint-<NNN>#<task-id>]] · [[workflows/runs/<run-id>/<NN>-<agent>]]
- **Did**: ...
- **Why**: ...
- **Learned**: ...
- **Open**: ... (link [[decisions/ADR-...]] or [[spikes/SPIKE-...]] if produced)
```

In legacy mode (no `vault_project_path`), still write frontmatter and wikilinks using repo-relative paths translated through the same logical names — Obsidian still resolves them when the user later runs `/migrate`.

## Task resolution

### Sprint-backed task
If the next argument looks like a task ID such as `US-001`, `BUG-004`, or `SPIKE-002`:
- search `$SPRINTS_DIR/` for the matching task block
- load the task title, acceptance criteria, and any `Agent:` or `Workflow:` metadata
- treat the sprint file as the source task record

### Ad hoc task
If no sprint task is found:
- treat the remaining text as the task description
- create a synthetic run label based on the workflow spec and current date/time
- do not update sprint files

## Required workflow format (pre-built workflows only)

The workflow file must live at `$WORKFLOWS_DEF_DIR/<workflow>.md` and must use explicit stages. Each stage must declare:
- `Agent:`
- `Inputs:`
- `Outputs:`
- `Pass:`
- `OnFailure:`

If the workflow file is prose-only or missing any required stage field, stop and report that the workflow must be migrated to the explicit orchestration format.

## Strict sequence

### 1. Load shared context

Load in this order to maximise prompt-cache hits (stable content first, dynamic last).

**Static — load first (cache candidates for Claude Code):**
- `$SPEC_FILE`
- `.claude/CLAUDE.md`
- `AGENTS.md`
- For pre-built workflows: `$WORKFLOWS_DEF_DIR/<workflow>.md`

**Semi-static — load next:**
- Per-stage: `$AGENTS_DIR/<stage-agent>/agent.md`
- Per-stage: `$AGENTS_DIR/<stage-agent>/memory.md`

**Dynamic — load last:**
- `.project/state.json`
- `$SPRINTS_DIR/sprint-NNN.md` (only when task is sprint-backed)

**Repo discovery (inline, after state.json load):**
If `state.json.repos` contains any entry where `name`, `stack`, or `role` is `null`:
1. For each such entry, read the manifest file at its `path` (priority: `package.json` → `Cargo.toml` → `go.mod` → `composer.json` → `pyproject.toml` → `requirements.txt`)
2. Detect `name` (package name or dirname), `stack`, `description` (manifest description or first non-blank README line), `role` (infer from name/description: `frontend` | `backend` | `mobile` | `lib` | `infra`)
3. Write detected fields back to that repo entry in `.project/state.json`
4. Sync the updated `repos` array to every sibling repo that has a `.project/state.json` — replace only the `repos` field, leave all other fields untouched; skip silently if the sibling has no `.project/state.json`
This is a one-time cost per repo. On subsequent runs all fields are populated and no probe occurs.

**Lazy — load only when needed:**
- `$VISION_FILE`: load only if the task or any stage agent lists it in its Inputs, or if acceptance-criteria validation requires it. Skip otherwise.

### 2. Create the workflow run directory
Create `$WORKFLOWS_RUNS_DIR/<run-id>/`.
Inside it, maintain at minimum:
- `task.md` — resolved task context; if `state.json.repos` is non-empty, append a compact repos block:
  ```
  ## Available Repositories (N)
  - <role> [<stack>] <name> at <path> — <description>
  ```
- one artifact file per stage
- `final-summary.md` — final verdict and next action

### 3. Update state before execution
Set in `.project/state.json`:
- `active_workflow_run` = `<run-id>`
- `last_workflow_run` = workflow name
- `last_workflow_stage` = null
- `last_workflow_result` = `in_progress`
- append or update an item in `workflow_runs`

### 4. Execute each stage in order
For every stage declared in the workflow:
- load `$AGENTS_DIR/<stage-agent>/agent.md`
- load `$AGENTS_DIR/<stage-agent>/memory.md`
- load every prior stage artifact already written under `$WORKFLOWS_RUNS_DIR/<run-id>/`
- execute only the current stage with the assigned agent persona
- write the declared output artifact for that stage
- record whether the stage passed its `Pass:` rule
- update `.project/state.json > last_workflow_stage`

### 5. Handle failures
- If a stage hits a blocking failure, obey `OnFailure:`.
- Default behavior is to stop the workflow immediately.
- Record the failure in `$WORKFLOWS_RUNS_DIR/<run-id>/final-summary.md`.
- Set `.project/state.json > last_workflow_result` to `failed`.
- Clear `active_workflow_run` before exiting.

### 6. Handle success
When all stages pass:
- write `$WORKFLOWS_RUNS_DIR/<run-id>/final-summary.md`
- set `.project/state.json > last_workflow_result` to `passed`
- clear `active_workflow_run`
- if the task was sprint-backed, report back the task ID but do not tick sprint checkboxes automatically unless every acceptance criterion is explicitly verified

### 7. Update memory
After each completed stage, append a dated entry to `$AGENTS_DIR/<stage-agent>/memory.md`:
- Stage
- Did
- Why
- Learned
- Open

### 8. Report
Include:
- workflow name
- run ID
- task source: sprint task or ad hoc
- task text or task ID
- stage-by-stage verdicts
- location of artifacts under `$WORKFLOWS_RUNS_DIR/<run-id>/`
- final verdict
- next action
