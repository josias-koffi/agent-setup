---
name: run-agent
description: >
  Runs a specific agent on an ad hoc task, with or without a named workflow, outside sprint files. Args: agent [workflow] task. Use when the user wants a project-scoped agent execution that is not tied to sprints/sprint-NNN.md.
allowed-tools: Read, Write, Bash(git:*), Bash(npm:*), Bash(cargo:*), Bash(pytest:*), Bash(go:*)
---

# run-agent runner

## Arguments
- `$ARGUMENTS[0]` = agent name (for example `"developer"`)
- `$ARGUMENTS[1]` = workflow name OR the task text when no workflow is used
- `$ARGUMENTS[2...]` = remaining task text when a workflow is provided

## Modes

### 1. Agent + workflow + task
Example:
- `run-agent developer analyze-design-dev-review Fix checkout race condition`

Interpretation:
- agent = `developer`
- workflow = `analyze-design-dev-review`
- task = `Fix checkout race condition`

### 2. Agent + task only
Example:
- `run-agent qa-reviewer Review recent checkout changes for regressions`

Interpretation:
- agent = `qa-reviewer`
- workflow = none
- task = `Review recent checkout changes for regressions`

If `$ARGUMENTS[1]` matches an existing file in `workflows/<name>.md`, treat it as a workflow. Otherwise, treat the full remaining input as the task text.

## Strict sequence

### 1. Load context
- `AGENTS.md`
- `.claude/CLAUDE.md`
- `.project/vision.md`
- `.project/state.json`
- `spec/engineering-standards.md`
- `agents/$ARGUMENTS[0]/agent.md`
- `agents/$ARGUMENTS[0]/memory.md`
- `workflows/$ARGUMENTS[1].md` only if a workflow was detected

### 2. Validate (STOP on failure)
- Project bootstrap files exist.
- Agent exists under `agents/<agent>/agent.md`.
- Task text is not empty.
- Workflow exists if one was explicitly requested.

### 3. Run the task
- Execute the selected agent against the free-form task.
- If a workflow is present, execute its steps in order.
- If no workflow is present, act directly from the agent role, project vision, engineering standards, and task text.
- **Blocking rule fails** → STOP and report.
- **Advisory rule fails** → warn and continue where appropriate.

### 4. Update project state
- Do not touch sprint files.
- Do not require a sprint task ID.
- Update `.project/state.json > last_updated`.

### 5. Update agent memory
Append a dated entry to `agents/$ARGUMENTS[0]/memory.md`:
- Did / Why / Learned / Open

### 6. Report
Agent / Workflow used or `none` / Task / Steps completed / Blocking verdict / Advisory warnings / Next action.
