---
name: sprint
description: >
  Runs sprint tasks by inferring the assigned workflow from the sprint file, with optional explicit overrides. Preferred args: sprint-number [task-id|all]. Optional overrides: workflow.
allowed-tools: Read, Write, Bash(git:*), Bash(npm:*), Bash(cargo:*), Bash(pytest:*), Bash(go:*)
---

# sprint runner

## Purpose

`sprint` is the sprint-scoped orchestrator. It resolves the target task or tasks from the sprint file, reads the workflow declared by each task, and executes that workflow stage by stage. When the workflow contains multiple agents, `sprint` must orchestrate the handoff between them through `.project/workflows/<run-id>/` artifacts.

Use `run-agent` only for ad hoc mono-agent work outside sprint files.
Use `run-workflow` when you want direct workflow orchestration without entering through a sprint.

## Arguments
- `$ARGUMENTS[0]` = sprint number, zero-padded (for example `001`)
- `$ARGUMENTS[1]` = optional task ID such as `US-001`, or `all`
- `$ARGUMENTS[2]` = optional workflow override

## Supported invocation forms
- `sprint 001`
- `sprint 001 US-001`
- `sprint 001 US-001 analyze-design-dev-review`
- `sprint 001 US-001 developer-qa-reviewer-tech-lead`

## Strict sequence

### 0. Path resolution

Read `.project/state.json`. Extract `vault_project_path` (may be null or absent).

If `vault_project_path` is set and non-null, use vault paths:
- `SPEC_FILE` = `<vault_project_path>/spec/engineering-standards.md`
- `AGENTS_DIR` = `<vault_project_path>/agents`
- `WORKFLOWS_DEF_DIR` = `<vault_project_path>/workflows/definitions`
- `WORKFLOWS_RUNS_DIR` = `<vault_project_path>/workflows/runs`
- `SPRINTS_DIR` = `<vault_project_path>/sprints`
- `VISION_FILE` = `<vault_project_path>/vision.md`

Otherwise (legacy mode), use repo-relative paths:
- `SPEC_FILE` = `agent-setup/spec/engineering-standards.md`
- `AGENTS_DIR` = `agent-setup/agents`
- `WORKFLOWS_DEF_DIR` = `agent-setup/workflows`
- `WORKFLOWS_RUNS_DIR` = `.project/workflows`
- `SPRINTS_DIR` = `.project/sprints`
- `VISION_FILE` = `.project/vision.md`

All subsequent path references use these resolved variables.

### 1. Load context

Load in this order to maximise prompt-cache hits (stable content first, dynamic last).

**Static — load first (cache candidates for Claude Code):**
- `$SPEC_FILE`
- `.claude/CLAUDE.md`
- `AGENTS.md`

**Dynamic — load next:**
- `.project/state.json`
- `$SPRINTS_DIR/sprint-$ARGUMENTS[0].md`

**Repo discovery (inline, after state.json load):**
If `state.json.repos` contains any entry where `name`, `stack`, or `role` is `null`:
1. For each such entry, read the manifest file at its `path` (priority: `package.json` → `Cargo.toml` → `go.mod` → `composer.json` → `pyproject.toml` → `requirements.txt`)
2. Detect `name` (package name or dirname), `stack`, `description` (manifest description or first non-blank README line), `role` (infer from name/description: `frontend` | `backend` | `mobile` | `lib` | `infra`)
3. Write detected fields back to that repo entry in `.project/state.json`
4. Sync the updated `repos` array to every sibling repo that has a `.project/state.json` — replace only the `repos` field, leave all other fields untouched; skip silently if the sibling has no `.project/state.json`
This is a one-time cost per repo. On subsequent runs all fields are populated and no probe occurs.

**Lazy — load only when needed:**
- `$VISION_FILE`: load only if the targeted task's acceptance criteria reference vision sections, or a stage agent (e.g. product-owner, analyst, designer) lists it in its Inputs. Skip otherwise.

### 2. Resolve execution scope
- With only the sprint number, target every runnable task in the sprint.
- With a task ID, target only that task.
- For each targeted task, parse its title, acceptance criteria, `Workflow:` line, optional `Repos:` line, and optional `Depends-on:` line.
- If `$ARGUMENTS[2]` is present, use it as the workflow override.
- If a targeted task has no workflow and no override was provided, stop and report the missing metadata.
- If the task has a `Depends-on: <repo>/<task-id>` field, check whether that task is marked complete in the sibling repo's sprint file. If not, emit an advisory warning (do not block).

### 3. Resolve workflow mode
For each resolved workflow spec (from the task `Workflow:` field or the override), apply this priority:

**Pre-built workflow**: if `$WORKFLOWS_DEF_DIR/<spec>.md` exists, load it and use its declared stages.

**Dynamic agent chain**: if no workflow file is found, split the spec on `-` into agent segments. Verify each segment has a matching `$AGENTS_DIR/<segment>/agent.md`. If all segments are valid agents, construct dynamic stages (see `run-workflow` for the dynamic stage list construction rules). If any segment is unknown, stop and report.

### 4. Validate
Stop on failure if:
- required project files are missing
- the requested sprint file or task does not exist
- the resolved workflow spec cannot be resolved (neither a pre-built file nor a valid agent chain)
- a pre-built workflow file is not in explicit stage format with `Agent:`, `Inputs:`, `Outputs:`, `Pass:`, and `OnFailure:` per stage
- a targeted task is already fully checked

### 5. Orchestrate the workflow
For each targeted task:
- create `$WORKFLOWS_RUNS_DIR/<run-id>/`
  - for pre-built workflows: run-id is `<workflow-name>-<YYYYMMDDHHMMSS>`
  - for dynamic chains: run-id is `<agent1-agent2-agentN>-<YYYYMMDDHHMMSS>`
- write the task context to `$WORKFLOWS_RUNS_DIR/<run-id>/task.md`; if `state.json.repos` is non-empty, append a compact repos block:
  ```
  ## Available Repositories (N)
  - <role> [<stack>] <name> at <path> — <description>
  ```
  If the task has a `Repos:` field, include only the listed repos in this block; otherwise include all.
- for each stage (declared or dynamically constructed):
  - load `$AGENTS_DIR/<stage-agent>/agent.md`
  - load `$AGENTS_DIR/<stage-agent>/memory.md`
  - load all prior stage artifacts from `$WORKFLOWS_RUNS_DIR/<run-id>/`
  - execute the current stage with that agent persona
  - write the declared output artifact (`<NN>-<agent-name>.md`) — **max 400 words (~2 500 characters); summarise rather than quote if longer**
  - update `.project/state.json > last_workflow_stage`
  - append a dated entry to that agent's memory file at `$AGENTS_DIR/<stage-agent>/memory.md`
- on blocking failure, stop immediately, record the failure in `final-summary.md`, and do not tick the sprint task
- every stage artifact (`task.md`, `<NN>-<agent>.md`, `final-summary.md`) and every memory entry MUST follow the **Obsidian linking protocol** documented in `run-workflow.md` — frontmatter tags, wikilink backrefs to sprint task, workflow def, prev/next stage, and agent.
- after creating the run directory, append a line under the sprint file's `## 🔁 Workflow Runs` section: `- <YYYY-MM-DD> — [[workflows/runs/<run-id>|<workflow-name>]] (<task-id>) — in_progress` (create the section if absent). Update the verdict on completion.
- append a line under the workflow definition's `## Used by` section: `- [[sprints/sprint-<NNN>#<task-id>]] — <YYYY-MM-DD> → [[workflows/runs/<run-id>]]` (create the section if absent).

### 6. Update sprint file
Tick checkboxes only when every acceptance criterion is explicitly verified by the orchestrated workflow output.

### 7. Update `.project/state.json`
- `last_updated` = ISO now
- `last_workflow_run` = resolved workflow for the last completed task
- `last_task_completed` = last completed task ID, or `all`
- `last_workflow_result` = `passed` or `failed`
- clear `active_workflow_run` at the end of each task run
- add the sprint number to `completed_sprints` only if sprint DoD is fully met

### 8. Report
Include:
- sprint number
- targeted tasks
- resolved workflow per task
- run ID per task
- stage-by-stage verdicts
- artifact location under `$WORKFLOWS_RUNS_DIR/`
- final verdict
- next action
