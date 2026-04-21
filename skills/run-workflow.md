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

## Workflow resolution

Resolve `$ARGUMENTS[0]` using the following priority order:

### 1. Pre-built workflow file
Check whether `agent-setup/workflows/<arg>.md` exists.
- If it does, load it and follow the **Required workflow format** rules below.

### 2. Dynamic agent chain
If no workflow file is found, treat the argument as a hyphen-separated list of agent names and split it into segments.
- For each segment, verify that `agent-setup/agents/<segment>/agent.md` exists.
- If every segment resolves to a valid agent, construct a **dynamic stage list** (see below).
- If any segment does not resolve, stop and report which segments are unknown.

### Dynamic stage list construction
Given a chain `agent1-agent2-agentN`, synthesize stages at runtime:

```
Stage 1
  Agent: agent1
  Inputs:
    - .project/workflows/<run-id>/task.md
  Outputs:
    - .project/workflows/<run-id>/01-agent1.md
  Pass: output file written and non-empty
  OnFailure: Stop

Stage 2
  Agent: agent2
  Inputs:
    - .project/workflows/<run-id>/task.md
    - .project/workflows/<run-id>/01-agent1.md
  Outputs:
    - .project/workflows/<run-id>/02-agent2.md
  Pass: output file written and non-empty
  OnFailure: Stop

...

Stage N
  Agent: agentN
  Inputs:
    - .project/workflows/<run-id>/task.md
    - all prior artifacts .project/workflows/<run-id>/NN-*.md
  Outputs:
    - .project/workflows/<run-id>/0N-agentN.md
  Pass: output file written and non-empty
  OnFailure: Stop
```

Each agent must produce its output artifact before the next agent begins. Each agent reads all prior artifacts in full to maintain context continuity. The run-id used for the directory is `<chain-slug>-<YYYYMMDDHHMMSS>` where `<chain-slug>` is the full `agent1-agent2-agentN` string.

**Artifact size cap**: every stage output file must not exceed 400 words (~2 500 characters). Summarise rather than quote when output would exceed this limit.

## Task resolution

### Sprint-backed task
If the next argument looks like a task ID such as `US-001`, `BUG-004`, or `SPIKE-002`:
- search `.project/sprints/` for the matching task block
- load the task title, acceptance criteria, and any `Agent:` or `Workflow:` metadata
- treat the sprint file as the source task record

### Ad hoc task
If no sprint task is found:
- treat the remaining text as the task description
- create a synthetic run label based on the workflow spec and current date/time
- do not update sprint files

## Required workflow format (pre-built workflows only)

The workflow file must live at `agent-setup/workflows/<workflow>.md` and must use explicit stages. Each stage must declare:
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
- `agent-setup/spec/engineering-standards.md`
- `.claude/CLAUDE.md`
- `AGENTS.md`
- For pre-built workflows: `agent-setup/workflows/<workflow>.md`

**Semi-static — load next:**
- Per-stage: `agent-setup/agents/<stage-agent>/agent.md`
- Per-stage: `agent-setup/agents/<stage-agent>/memory.md`

**Dynamic — load last:**
- `.project/state.json`
- `.project/sprints/sprint-NNN.md` (only when task is sprint-backed)

**Lazy — load only when needed:**
- `.project/vision.md`: load only if the task or any stage agent lists `vision.md` in its Inputs, or if acceptance-criteria validation requires it. Skip otherwise.

### 2. Create the workflow run directory
Create `.project/workflows/<run-id>/`.
Inside it, maintain at minimum:
- `task.md` — resolved task context
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
- load `agent-setup/agents/<stage-agent>/agent.md`
- load `agent-setup/agents/<stage-agent>/memory.md`
- load every prior stage artifact already written under `.project/workflows/<run-id>/`
- execute only the current stage with the assigned agent persona
- write the declared output artifact for that stage
- record whether the stage passed its `Pass:` rule
- update `.project/state.json > last_workflow_stage`

### 5. Handle failures
- If a stage hits a blocking failure, obey `OnFailure:`.
- Default behavior is to stop the workflow immediately.
- Record the failure in `.project/workflows/<run-id>/final-summary.md`.
- Set `.project/state.json > last_workflow_result` to `failed`.
- Clear `active_workflow_run` before exiting.

### 6. Handle success
When all stages pass:
- write `.project/workflows/<run-id>/final-summary.md`
- set `.project/state.json > last_workflow_result` to `passed`
- clear `active_workflow_run`
- if the task was sprint-backed, report back the task ID but do not tick sprint checkboxes automatically unless every acceptance criterion is explicitly verified

### 7. Update memory
After each completed stage, append a dated entry to that stage agent's memory file:
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
- location of artifacts under `.project/workflows/<run-id>/`
- final verdict
- next action
