---
name: sprint
description: >
  Runs sprint tasks by inferring the assigned agent and workflow from the sprint file, with optional explicit overrides. Preferred args: sprint-number [task-id|all]. Optional overrides: agent workflow.
allowed-tools: Read, Write, Bash(git:*), Bash(npm:*), Bash(cargo:*), Bash(pytest:*), Bash(go:*)
---

# sprint runner

## Arguments
- `$ARGUMENTS[0]` = sprint number, zero-padded (e.g. `001`)
- `$ARGUMENTS[1]` = optional task ID such as `US-001`, or `all`
- `$ARGUMENTS[2]` = optional agent name override
- `$ARGUMENTS[3]` = optional workflow name override

## Supported invocation forms

### 1. Sprint only
Example:
- `sprint 001`

Meaning:
- load `.project/sprints/sprint-001.md`
- run every runnable task in that sprint
- for each task, read its `Agent:` and `Workflow:` lines from the sprint file

### 2. One task with inferred agent/workflow
Example:
- `sprint 001 US-001`

Meaning:
- load task `US-001` from `.project/sprints/sprint-001.md`
- infer the assigned agent and workflow from the task block itself

### 3. Explicit override form
Example:
- `sprint 001 US-001 developer analyze-design-dev-review`

Meaning:
- load task `US-001`
- force the provided agent and workflow instead of the values declared in the sprint file

## Strict sequence

### 1. Load context
- `AGENTS.md`
- `.claude/CLAUDE.md`
- `.project/vision.md`
- `.project/state.json`
- `agent-setup/spec/engineering-standards.md`
- `.project/sprints/sprint-$ARGUMENTS[0].md`

### 2. Resolve execution scope
- If only the sprint number is provided, target every runnable task in the sprint.
- If a task ID is provided, target only that task.
- For each targeted task, parse:
  - `Agent: <role>`
  - `Workflow: <name>`
- If `$ARGUMENTS[2]` and `$ARGUMENTS[3]` are both present, use them as overrides.
- If the task does not declare an agent or workflow and no override was provided, STOP and report the missing metadata.

### 3. Validate (STOP on failure)
- Every required project file exists.
- Target task exists when a task ID was requested.
- Each targeted task is not already fully checked.
- Resolved agent exists under `agent-setup/agents/<agent>/agent.md`.
- Resolved workflow exists under `agent-setup/workflows/<workflow>.md`.
- Report the resolved execution plan before continuing.

### 4. Run workflow
For each targeted task:
- Load `agent-setup/agents/<agent>/agent.md`
- Load `agent-setup/agents/<agent>/memory.md`
- Load `agent-setup/workflows/<workflow>.md`
- Load referenced skills from `agent-setup/skills/`.
- Execute each workflow step in order.
- Verify the pass criterion.
- **Blocking rule fails** → STOP, report, go to rollback point.
- **Advisory rule fails** → warn, continue, log in sprint file.

### 5. Update sprint file
Tick checkboxes only when every acceptance criterion is verified.

### 6. Update `.project/state.json`
- `last_updated` = ISO 8601 now
- `last_workflow_run` = resolved workflow for the last completed task
- `last_task_completed` = last completed task ID, or `all` when the whole sprint run completed
- If sprint DoD fully met, push sprint number into `completed_sprints`.

### 7. Update agent memory
For each agent that actually ran, append a dated entry to `agent-setup/agents/<agent>/memory.md`:
- Did / Why / Learned / Open

### 8. Report
Sprint / Targeted tasks / Resolved agent-workflow pairs / Steps completed / Blocking verdict / Advisory warnings / Next action.
