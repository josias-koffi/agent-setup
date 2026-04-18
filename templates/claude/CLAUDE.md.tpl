<!-- generated-by: /init-project -->
<!-- vars: PROJECT_NAME, STACK_DETAILS, ARCHITECTURE_STYLE, LINT_CMD, FORMAT_CMD, TEST_CMD, BUILD_CMD, DEV_CMD -->
# CLAUDE.md — {{PROJECT_NAME}}

> Auto-loaded by Claude Code every session. Keep this file short. Long content goes in spec/, agent-setup/agents/<role>/, or .project/.

Codex CLI sessions should also read `AGENTS.md` at the repo root.

## Project
- Name: {{PROJECT_NAME}}
- Vision: `.project/vision.md` (source of truth, never auto-edit)
- State: `.project/state.json`
- Engineering spec: `agent-setup/spec/engineering-standards.md` (read before coding)

## Stack (detected)
- {{STACK_DETAILS}}
- Architecture: {{ARCHITECTURE_STYLE}}

## Commands
- Lint: `{{LINT_CMD}}`
- Format: `{{FORMAT_CMD}}`
- Test: `{{TEST_CMD}}`
- Build: `{{BUILD_CMD}}`
- Dev: `{{DEV_CMD}}`

## Agents — one per role, with own memory
- Product Owner → `agent-setup/agents/product-owner/agent.md` + `memory.md`
- Developer → `agent-setup/agents/developer/agent.md` + `memory.md`
- Designer → `agent-setup/agents/designer/agent.md` + `memory.md`
- Analyst → `agent-setup/agents/analyst/agent.md` + `memory.md`
- QA Reviewer → `agent-setup/agents/qa-reviewer/agent.md` + `memory.md`
- Tech Lead → `agent-setup/agents/tech-lead/agent.md` + `memory.md`
- Specialised (project-specific) → `agent-setup/agents/specialized/`

## Memory protocol (strict)
Before any substantial action, every agent MUST:
1. Read `.claude/CLAUDE.md` (this file)
2. Read `agent-setup/agents/<own-role>/memory.md`
3. Read `agent-setup/spec/engineering-standards.md`
4. Read the relevant sprint file under `.project/sprints/`

After completing a task, every agent MUST append a dated entry to its own `memory.md` covering: what was done, why, what it learned, and open questions.

## Enforcement policy
- **Blocking** (refuse commit/merge): failing tests, coverage below threshold in `agent-setup/spec/engineering-standards.md`, secrets detected, critical dependency vulnerabilities, missing ADR for stack changes.
- **Advisory** (warn but allow): style/naming nits, documentation gaps, non-critical TODOs.

See `agent-setup/spec/engineering-standards.md` for full rules.

## Hard rules
- Never modify `.project/vision.md`
- Never check a sprint task box unless every acceptance criterion is verified
- Never add features absent from `.project/vision.md` without explicit user approval
- Never introduce a new framework without an ADR in `.project/decisions/`

## Bootstrap a project
```
/init-project [optional-vision-file.md]
```

## Run a sprint
```
/sprint <sprint-number> <agent> <workflow> <task-id|all>
/sprint 001 developer analyze-design-dev-review US-001
```
