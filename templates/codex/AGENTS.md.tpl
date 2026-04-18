<!-- generated-by: /init -->
<!-- vars: PROJECT_NAME, STACK_DETAILS, ARCHITECTURE_STYLE, LINT_CMD, FORMAT_CMD, TEST_CMD, BUILD_CMD, DEV_CMD -->
# AGENTS.md — {{PROJECT_NAME}}

This repository uses a multi-agent workflow for Codex CLI sessions.

## Project
- Name: {{PROJECT_NAME}}
- Vision: `.project/vision.md` (source of truth, never auto-edit)
- State: `.project/state.json`
- Engineering spec: `spec/engineering-standards.md`

## Stack
- {{STACK_DETAILS}}
- Architecture: {{ARCHITECTURE_STYLE}}

## Commands
- Lint: `{{LINT_CMD}}`
- Format: `{{FORMAT_CMD}}`
- Test: `{{TEST_CMD}}`
- Build: `{{BUILD_CMD}}`
- Dev: `{{DEV_CMD}}`

## Required reading before substantial work
1. `AGENTS.md`
2. `.claude/CLAUDE.md`
3. `agents/<own-role>/memory.md`
4. `spec/engineering-standards.md`
5. the relevant sprint file under `sprints/`

## Agent roles
- Product Owner: `agents/product-owner/`
- Developer: `agents/developer/`
- Designer: `agents/designer/`
- Analyst: `agents/analyst/`
- QA Reviewer: `agents/qa-reviewer/`
- Tech Lead: `agents/tech-lead/`
- Specialized roles: `agents/specialized/`

## Hard rules
- Never modify `.project/vision.md`
- Never check a sprint task box unless every acceptance criterion is verified
- Never add features absent from `.project/vision.md` without explicit user approval
- Never introduce a new framework without an ADR in `.project/decisions/`

## Memory protocol
After completing a task, append a dated entry to `agents/<own-role>/memory.md` covering what was done, why, what was learned, and open questions.

## Sprint workflow
Use the installed `sprint` skill with:

```text
sprint <sprint-number> <agent> <workflow> <task-id|all>
```
