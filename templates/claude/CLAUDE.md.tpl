<!-- generated-by: /init-project -->
<!-- vars: PROJECT_NAME, STACK_DETAILS, ARCHITECTURE_STYLE, LINT_CMD, FORMAT_CMD, TEST_CMD, BUILD_CMD, DEV_CMD, VAULT_PROJECT_PATH, SPEC_PATH, AGENTS_DIR, WORKFLOWS_DEF_DIR, WORKFLOWS_RUNS_DIR, SPRINTS_DIR, VISION_PATH -->
# CLAUDE.md — {{PROJECT_NAME}}

> Auto-loaded by Claude Code every session. Keep this file short. Long content goes in spec/, agents/<role>/, or sprints/.

Codex CLI sessions should also read `AGENTS.md` at the repo root.

## Project
- Name: {{PROJECT_NAME}}
- Vision: `{{VISION_PATH}}` (source of truth, never auto-edit)
- State: `.project/state.json`
- Engineering spec: `{{SPEC_PATH}}` (read before coding)
- Workflow runs: `{{WORKFLOWS_RUNS_DIR}}/`

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
- Product Owner -> `{{AGENTS_DIR}}/product-owner/agent.md` + `memory.md`
- Developer -> `{{AGENTS_DIR}}/developer/agent.md` + `memory.md`
- Designer -> `{{AGENTS_DIR}}/designer/agent.md` + `memory.md`
- Analyst -> `{{AGENTS_DIR}}/analyst/agent.md` + `memory.md`
- QA Reviewer -> `{{AGENTS_DIR}}/qa-reviewer/agent.md` + `memory.md`
- Tech Lead -> `{{AGENTS_DIR}}/tech-lead/agent.md` + `memory.md`
- Specialised -> `{{AGENTS_DIR}}/specialized/`

## Path resolution
Read `.project/state.json` for `vault_project_path`. If set, all agent/workflow/sprint paths are under the vault. Skills resolve paths automatically.

## Memory protocol
Before substantial work, every agent must read:
1. `.claude/CLAUDE.md`
2. `{{AGENTS_DIR}}/<own-role>/memory.md`
3. `{{SPEC_PATH}}`
4. the relevant sprint file: `{{SPRINTS_DIR}}/sprint-NNN.md`
5. `{{WORKFLOWS_RUNS_DIR}}/<run-id>/` artifacts when workflow-orchestrated

After completing a task or workflow stage, append a dated entry to that agent's `memory.md`.

## Hard rules
- Never modify `{{VISION_PATH}}`
- Never check a sprint task box unless every acceptance criterion is verified
- Never add features absent from the vision without explicit user approval
- Never introduce a new framework without an ADR in the decisions folder
- **Active refactoring is part of every task** — on every touched file, fix obvious duplication, dead code, and size violations (see `{{SPEC_PATH}}` §9). On existing/active projects this is in-scope of the current task, not a separate sprint. Untouched files stay untouched.

## Project commands
```text
/init-project [optional-vision-file.md] [vault_path=/abs/path]
/migrate [vault_path=/abs/path]
/sprint <sprint-number> [task-id]
/run-agent <agent> <task text>
/run-workflow <workflow> <task-id|task-text>
/upgrade-project
```

## Command semantics
- `/init-project` = initialize project; use `vault_path=` to enable Obsidian vault mode
- `/migrate` = migrate existing .project/ and agent-setup/ to an Obsidian vault
- `/sprint` = sprint-scoped workflow orchestration
- `/run-agent` = ad hoc single-agent execution outside sprint files
- `/run-workflow` = direct staged multi-agent orchestration
- `/upgrade-project` = safe preview-first migration for older initialized projects
