---
name: sprint
description: >
  Runs sprint tasks by inferring the assigned workflow from the sprint file, with optional explicit overrides. Preferred args: sprint-number [task-id|all]. Optional overrides: workflow.
allowed-tools: Read, Write, Bash(git:*), Bash(npm:*), Bash(cargo:*), Bash(pytest:*), Bash(go:*)
---

# /sprint runner

## Purpose

`sprint` is the sprint-scoped orchestrator. It resolves the target task or tasks from the sprint file, reads the workflow declared by each task, and executes that workflow stage by stage. When the workflow contains multiple agents, `sprint` must orchestrate the handoff between them through `.project/workflows/<run-id>/` artifacts.

Use `/run-agent` only for ad hoc mono-agent work outside sprint files.
Use `/run-workflow` when you want direct workflow orchestration without entering through a sprint.

## Arguments
- `$ARGUMENTS[0]` = sprint number, zero-padded (for example `001`)
- `$ARGUMENTS[1]` = optional task ID such as `US-001`, or `all`
- `$ARGUMENTS[2]` = optional workflow override

## Supported invocation forms
- `/sprint 001`
- `/sprint 001 US-001`
- `/sprint 001 US-001 analyze-design-dev-review`
- `/sprint 001 US-001 developer-qa-reviewer-tech-lead`

## Strict sequence

### 1. Load context
- `.claude/CLAUDE.md`
- `AGENTS.md`
- `.project/vision.md`
- `.project/state.json`
- `agent-setup/spec/engineering-standards.md`
- `.project/sprints/sprint-$ARGUMENTS[0].md`

### 2. Resolve execution scope
- With only the sprint number, target every runnable task in the sprint.
- With a task ID, target only that task.
- For each targeted task, parse its title, acceptance criteria, and `Workflow:` line.
- If `$ARGUMENTS[2]` is present, use it as the workflow override.
- If a targeted task has no workflow and no override was provided, stop and report the missing metadata.

### 3. Resolve workflow mode
For each resolved workflow spec (from the task `Workflow:` field or the override), apply this priority:

**Pre-built workflow**: if `agent-setup/workflows/<spec>.md` exists, load it and use its declared stages.

**Dynamic agent chain**: if no workflow file is found, split the spec on `-` into agent segments. Verify each segment has a matching `agent-setup/agents/<segment>/agent.md`. If all segments are valid agents, construct dynamic stages (see `/run-workflow` for the dynamic stage list construction rules). If any segment is unknown, stop and report.

### 4. Validate
Stop on failure if:
- required project files are missing
- the requested sprint file or task does not exist
- the resolved workflow spec cannot be resolved (neither a pre-built file nor a valid agent chain)
- a pre-built workflow file is not in explicit stage format with `Agent:`, `Inputs:`, `Outputs:`, `Pass:`, and `OnFailure:` per stage
- a targeted task is already fully checked

### 5. Orchestrate the workflow
For each targeted task:
- create `.project/workflows/<run-id>/`
  - for pre-built workflows: run-id is `<workflow-name>-<YYYYMMDDHHMMSS>`
  - for dynamic chains: run-id is `<agent1-agent2-agentN>-<YYYYMMDDHHMMSS>`
- write the task context to `.project/workflows/<run-id>/task.md`
- for each stage (declared or dynamically constructed):
  - load `agent-setup/agents/<stage-agent>/agent.md`
  - load `agent-setup/agents/<stage-agent>/memory.md`
  - load all prior stage artifacts from `.project/workflows/<run-id>/`
  - execute the current stage with that agent persona
  - write the declared output artifact (`<NN>-<agent-name>.md`)
  - update `.project/state.json > last_workflow_stage`
  - append a dated entry to that agent's memory file
- on blocking failure, stop immediately, record the failure in `final-summary.md`, and do not tick the sprint task

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
- artifact location under `.project/workflows/`
- final verdict
- next action
