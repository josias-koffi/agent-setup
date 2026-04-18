---
name: sprint
description: >
  Runs a specific agent on an active sprint task using a named workflow. Args: sprint-number agent workflow task-id|all.
allowed-tools: Read, Write, Bash(git:*), Bash(npm:*), Bash(cargo:*), Bash(pytest:*), Bash(go:*)
---

# sprint runner

## Arguments
- `$ARGUMENTS[0]` = sprint number, zero-padded (e.g. "001")
- `$ARGUMENTS[1]` = agent name (e.g. "developer")
- `$ARGUMENTS[2]` = workflow name (e.g. "analyze-design-dev-review")
- `$ARGUMENTS[3]` = task ID or "all"

## Strict sequence

### 1. Load context
- `AGENTS.md`
- `.claude/CLAUDE.md`
- `.project/vision.md`
- `.project/state.json`
- `spec/engineering-standards.md`
- `sprints/sprint-$ARGUMENTS[0].md`
- `agents/$ARGUMENTS[1]/agent.md`
- `agents/$ARGUMENTS[1]/memory.md`
- `workflows/$ARGUMENTS[2].md`

### 2. Validate (STOP on failure)
- Every file above exists.
- Task `$ARGUMENTS[3]` present in sprint file (or "all").
- Task is not already fully checked.
- Report validation before continuing.

### 3. Run workflow
Execute each workflow step in order. For each step:
- Confirm assigned agent matches or is compatible.
- Load referenced skills from `skills/`.
- Execute the action.
- Verify the pass criterion.
- **Blocking rule fails** → STOP, report, go to rollback point.
- **Advisory rule fails** → warn, continue, log in sprint file.

### 4. Update sprint file
Tick checkboxes only when every acceptance criterion is verified.

### 5. Update `.project/state.json`
- `last_updated` = ISO 8601 now
- `last_workflow_run` = $ARGUMENTS[2]
- `last_task_completed` = $ARGUMENTS[3]
- If sprint DoD fully met, push sprint number into `completed_sprints`.

### 6. Update agent memory
Append a dated entry to `agents/$ARGUMENTS[1]/memory.md`:
- Did / Why / Learned / Open

### 7. Report
Sprint / Agent / Workflow / Task / Steps completed / Blocking verdict / Advisory warnings / Next action.
