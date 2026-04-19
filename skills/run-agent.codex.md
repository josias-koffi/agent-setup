---
name: run-agent
description: >
  Runs a specific agent on an ad hoc task, with or without a named workflow, outside sprint files. Args: agent [workflow] task. Use when the user wants a project-scoped single-agent execution that is not tied to .project/sprints/sprint-NNN.md.
allowed-tools: Read, Write, Bash(git:*), Bash(npm:*), Bash(cargo:*), Bash(pytest:*), Bash(go:*)
---

# run-agent runner

## Purpose

`run-agent` is a single-agent executor. It does not orchestrate handoffs between multiple agents. If the user wants stage-by-stage multi-agent execution with persisted outputs between agents, use `$run-workflow` instead.

## Arguments
- `$ARGUMENTS[0]` = agent name
- `$ARGUMENTS[1]` = workflow name OR the task text when no workflow is used
- `$ARGUMENTS[2...]` = remaining task text when a workflow is provided

If `$ARGUMENTS[1]` matches `agent-setup/workflows/<name>.md`, treat it as a workflow. Otherwise treat all remaining input as task text.

## Strict sequence

### 1. Load context
- `AGENTS.md`
- `.claude/CLAUDE.md`
- `.project/vision.md`
- `.project/state.json`
- `agent-setup/spec/engineering-standards.md`
- `agent-setup/agents/<agent>/agent.md`
- `agent-setup/agents/<agent>/memory.md`
- `agent-setup/workflows/<workflow>.md` only if a workflow was requested

### 2. Validate
Stop on failure if:
- bootstrap files are missing
- the agent definition is missing
- task text is empty
- an explicitly requested workflow is missing

### 3. Run the task
- Execute the selected agent against the free-form task.
- If a workflow is present, use it as role guidance and quality gates for that one agent only.
- Do not attempt multi-agent handoffs from inside `run-agent`.
- Blocking failures stop execution.
- Advisory failures are warnings.

### 4. Update project state
- Do not touch sprint files.
- Update `.project/state.json > last_updated`.
- Optionally set `last_workflow_run` when a workflow was used.
- Do not create `.project/workflows/<run-id>/` artifacts unless the user explicitly asked for `$run-workflow`.

### 5. Update agent memory
Append a dated entry to `agent-setup/agents/<agent>/memory.md`:
- Did
- Why
- Learned
- Open

### 6. Report
Include:
- agent
- workflow or `none`
- task
- blocking verdict
- advisory warnings
- next action
