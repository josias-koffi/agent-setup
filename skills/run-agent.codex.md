---
name: run-agent
description: >
  Runs a specific agent on an ad hoc task outside sprint files. Args: agent task. Use when the user wants a project-scoped single-agent execution that is not tied to .project/sprints/sprint-NNN.md.
allowed-tools: Read, Write, Bash(git:*), Bash(npm:*), Bash(cargo:*), Bash(pytest:*), Bash(go:*)
---

# run-agent runner

## Purpose

`run-agent` is a single-agent executor. It does not orchestrate handoffs between multiple agents. If the user wants stage-by-stage multi-agent execution with persisted outputs between agents, use `$run-workflow` instead.

## Arguments
- `$ARGUMENTS[0]` = agent name
- `$ARGUMENTS[1...]` = task text

Example:
- `$run-agent developer Fix checkout race condition`
- `$run-agent qa-reviewer Review recent checkout changes for regressions`

## Strict sequence

### 1. Load context
- `AGENTS.md`
- `.claude/CLAUDE.md`
- `.project/vision.md`
- `.project/state.json`
- `agent-setup/spec/engineering-standards.md`
- `agent-setup/agents/<agent>/agent.md`
- `agent-setup/agents/<agent>/memory.md`

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
- task
- blocking verdict
- advisory warnings
- next action
