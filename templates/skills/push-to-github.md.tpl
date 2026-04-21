<!-- generated-by: init-project -->
---
name: push-to-github
description: >
  Stage, commit, and push changes for this project using {{STACK}} quality gates.
  Overrides the global agnostic push-to-github skill with stack-specific commands.
allowed-tools: Bash, Read, Glob, Grep
---

# push-to-github (project override — {{STACK}})

This is a project-level override of the global `push-to-github` skill.
It applies the {{STACK}}-specific quality gates for this repository.

## Workflow
1. `git status --short` — identify changed files.
2. `git rev-parse --abbrev-ref HEAD` — confirm not on a protected branch.
3. Group changes into Conventional Commit groups.
4. Run lint: `{{LINT_CMD}}` (blocking).
5. Run tests: `{{TEST_CMD}}` (blocking).
6. `git add <files>` + `git commit -m "type(scope): summary"`.
7. Final gate rerun: lint + tests.
8. `git push origin <current-branch>`.

## Quality Gates
- Lint: `{{LINT_CMD}}`
- Format: `{{FORMAT_CMD}}`
- Tests: `{{TEST_CMD}}`

## Commit Rules
- Conventional Commit format: `type(scope): summary`
- Scope must match `[a-zA-Z0-9-_]+`
- Never amend existing commits
- Never use `--no-verify`

## On failure
Report the failing command, key error lines, and fixes attempted. Do not push.
