---
name: init-project
description: >
  Initialises or upgrades a project with a multi-agent structure (agents, workflows, skills, sprints, memory, and engineering spec). Works on greenfield projects AND existing codebases. Detects stack and conventions automatically. Use when the user says "init project", "set up agents", "bootstrap this repo", or runs init-project. Optional arg: path to a vision markdown file.
allowed-tools: Read, Write, Edit, Bash(mkdir:*), Bash(cp:*), Bash(ls:*), Bash(find:*), Bash(cat:*), Bash(test:*), Bash(git:*), Bash(date:*), Bash(env:*), Bash(${CODEX_HOME:-$HOME/.codex}/agent-setup/bin/render-templates.sh:*)
---

# init-project — Multi-Agent Project Initialiser

You are setting up (or upgrading) a project with a reusable multi-agent structure. Almost all file generation is done by a shell renderer shipped with the framework. Your job is to detect context, invoke the renderer with the right env vars, and handle the small LLM-judgment pieces: vision stub, README append, and final report.

## Parameters
- `$ARGUMENTS[0]` = path to a vision markdown file (optional)

---

## ⚠️ Non-negotiable rules (read first)

1. **Citation required** — every task, epic, user story, specialised agent, or specific workflow MUST cite a section of `.project/vision.md` using `(source: vision §<section>)`. No citation → do not create.
2. **Unknown → clarify** — information not found in the vision OR detected in the codebase becomes `⚠️ TO CLARIFY: <precise question>`. Never invent.
3. **No destructive changes to existing code** — you may add files under `.claude/`, `.project/`, `AGENTS.md`, `agent-setup/`. You may NEVER modify source code or config outside those paths unless the user explicitly asks.
4. **Idempotent** — the renderer skips any target file that already exists. You must not overwrite user edits. If re-running and a file looks out of date, ask the user before overwriting.
5. **Language** — match the vision file's language for all generated content. If auto-generating the vision, match the README's language. Default: English.
6. **No inventing stack** — use only technologies that are either (a) detected in the codebase or (b) explicitly mentioned in the vision.

---

## Phase 0 — Preflight

```bash
test -x "${CODEX_HOME:-$HOME/.codex}/agent-setup/bin/render-templates.sh" \
  || { echo "Framework not installed. Run: bash bootstrap.sh (from the agent-setup repo)" >&2; exit 2; }
```

If preflight fails, STOP and print the exact install command to the user. Do NOT fall back to inline generation.

---

## Phase 1 — Detect context

Build an internal `CONTEXT` object. Every field either has a detected value or an `⚠️ TO CLARIFY` string that will be added to `clarifications_pending`.

### 1.1 — Greenfield vs existing

```bash
test -d .git && echo "git-yes" || echo "git-no"
ls -1 | head -50
```

Set `CONTEXT.project_type`:
- `greenfield` if empty or only README/LICENSE
- `existing` otherwise

### 1.2 — Stack (existing only)

Check for these files and set `CONTEXT.stack` + `CONTEXT.stack_details`:

| File present | `stack` | Refinement |
|---|---|---|
| `package.json` | `node` | read `dependencies` — look for `next`, `react`, `vue`, `nestjs`, `express` |
| `Cargo.toml` | `rust` | |
| `pyproject.toml` / `requirements.txt` | `python` | look for `fastapi`, `django`, `flask` |
| `go.mod` | `go` | |
| `Gemfile` | `ruby` | |
| `pom.xml` / `build.gradle` | `java` | |
| `composer.json` | `php` | |

Parse commands from scripts where applicable (`package.json > scripts.{lint,format,test,build,dev}`). Fallbacks when nothing is found:

| Stack | lint | test | audit |
|---|---|---|---|
| node | `npm run lint` | `npm test` | `npm audit --audit-level=high` |
| rust | `cargo clippy -- -D warnings` | `cargo test` | `cargo audit` |
| python | `ruff check . --fix` | `pytest` | `pip-audit` |
| go | `golangci-lint run` | `go test ./...` | `govulncheck ./...` |
| ruby | `bundle exec rubocop` | `bundle exec rspec` | `bundler-audit` |
| java | `mvn verify` | `mvn test` | `mvn dependency-check:check` |
| php | `vendor/bin/phpstan analyse` | `vendor/bin/phpunit` | `composer audit` |

Anything still missing → `⚠️ TO CLARIFY: <lint\|test\|...> command`.

### 1.3 — Conventions

- `.eslintrc*`, `.prettierrc*`, `ruff.toml`, `rustfmt.toml`, `.editorconfig` → `CONTEXT.linters`
- `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/` → `CONTEXT.ci` (`present`/`absent`)
- `jest.config.*`, `vitest.config.*`, `.coveragerc`, `tarpaulin.toml` → `CONTEXT.coverage_tool`

### 1.4 — Architecture hints

- `src/domain/` + `src/application/` + `src/infrastructure/` → Clean/Hexagonal
- `src/controllers/` + `src/services/` + `src/models/` → MVC-ish
- `src/features/` → feature-sliced
- `packages/` or `apps/` → monorepo

Default: `unknown`.

### 1.5 — Project name

From `package.json > name`, `Cargo.toml > package.name`, `pyproject.toml > project.name`, `composer.json > name`, or the current directory name.

---

## Phase 2 — Create directory tree

```bash
mkdir -p .claude .project/{decisions,designs,spikes,releases}
mkdir -p agent-setup/agents/{product-owner,developer,designer,analyst,qa-reviewer,tech-lead,specialized}
mkdir -p agent-setup/{workflows,skills,spec} .project/sprints
```

---

## Phase 3 — Vision handling

Three branches:

**A. `$ARGUMENTS[0]` provided** — copy it verbatim:
```bash
cp "$ARGUMENTS[0]" .project/vision.md
```
Set `VISION_MODE=verbatim`.

**B. `.project/vision.md` already exists** — leave it untouched.
Set `VISION_MODE=reinit`.

**C. Neither** — the renderer will write the auto-stub. Set `VISION_MODE=auto-stub`.
For the `{{DETECTED_FEATURES_BLOCK}}` variable, inspect actual routes/modules/entry points and produce a bulleted list of detected features with file references (one line per feature; at least 3 if any code exists; `- ⚠️ TO CLARIFY: no features detectable` otherwise). This is the ONE piece of LLM judgment inside a template.

---

## Phase 4 — Invoke the renderer

Compute every variable, then call the renderer **once**. Example for a detected node project:

```bash
env \
  PROJECT_NAME="my-app" \
  PROJECT_TYPE="existing" \
  STACK="node" \
  STACK_DETAILS="node + next" \
  ARCHITECTURE_STYLE="feature-sliced" \
  LINT_CMD="npm run lint" \
  FORMAT_CMD="npm run format" \
  TEST_CMD="npm test" \
  BUILD_CMD="npm run build" \
  DEV_CMD="npm run dev" \
  AUDIT_CMD="npm audit --audit-level=high" \
  COVERAGE_TOOL="vitest --coverage" \
  CI_STATUS="present" \
  LINTERS="eslint, prettier" \
  TODAY_ISO="$(date -u +%Y-%m-%d)" \
  TODAY_PLUS_14="$(date -u -d '+14 days' +%Y-%m-%d)" \
  VISION_MODE="auto-stub" \
  DETECTED_FEATURES_BLOCK="- Auth flow (src/features/auth/)
- Checkout (src/features/checkout/)
- Admin dashboard (src/features/admin/)" \
  CLARIFICATIONS_JSON_ARRAY='["FORMAT_CMD not detected","coverage tool not configured"]' \
  "${CODEX_HOME:-$HOME/.codex}/agent-setup/bin/render-templates.sh" "$(pwd)"
```

**Rules:**
- Every variable listed in the renderer's `VARS` array must be provided. Unknown command values → the literal string `⚠️ TO CLARIFY: <what>`.
- `CLARIFICATIONS_JSON_ARRAY` must be a **valid JSON array**.
- `DETECTED_FEATURES_BLOCK` supports newlines.
- Multi-line values are fine.

**Check exit code:**
- `0` — success
- `2` — template missing (framework install broken → run bootstrap.sh)
- `3` — unresolved `{{VAR}}` placeholder — stderr lists the missing vars; fix and re-run
- `4` — write failure (permissions, disk)

Surface stderr verbatim to the user on any non-zero exit, then STOP.

---

## Phase 5 — README append

```bash
if [ -f README.md ]; then
    if ! grep -qE '<!-- generated-by: /(init|init-project) -->' README.md; then
        sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
            "${CODEX_HOME:-$HOME/.codex}/agent-setup/templates/readme-append.md.tpl" \
            >> README.md
    fi
else
    printf '# %s\n\n' "$PROJECT_NAME" > README.md
    sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        "${CODEX_HOME:-$HOME/.codex}/agent-setup/templates/readme-append.md.tpl" \
        >> README.md
fi
```

---

## Phase 6 — Final report

Print this to the user, substituting real values:

```
✅ <greenfield | existing | re-init> project initialised.

Detected:
  Stack: <CONTEXT.stack>
  Architecture: <CONTEXT.architecture_style>
  Lint: <cmd or ⚠️>
  Test: <cmd or ⚠️>
  CI: <present/absent>

Created:
  AGENTS.md
  .claude/CLAUDE.md
  .project/vision.md                    (<verbatim | auto-stub | kept>)
  .project/state.json
  agent-setup/spec/engineering-standards.md
  agent-setup/agents/<6 roles>/{agent.md, memory.md}
  agent-setup/workflows/<4 files>
  agent-setup/skills/<5 files>
  .project/sprints/{backlog.md, sprint-001.md}

⚠️  Clarifications pending (<N> items):
  - <list>

▶️  Recommended next actions:
  1. Review `.project/vision.md` (especially if auto-stub)
  2. Fill any ⚠️ TO CLARIFY commands in `AGENTS.md` and `.claude/CLAUDE.md`
  3. Review `agent-setup/spec/engineering-standards.md` thresholds
  4. Review `.project/sprints/sprint-001.md`
  5. Run: sprint 001 product-owner spike-research US-001
```

---

## Final self-check (before reporting done)

- [ ] Preflight passed (renderer present)
- [ ] No file created outside the allowed directories
- [ ] `.project/vision.md` exists (verbatim / auto-stub / kept)
- [ ] Renderer exited 0 (any other exit = surface stderr and stop)
- [ ] `state.json` parses as valid JSON (`jq . .project/state.json`)
- [ ] Every `⚠️ TO CLARIFY` collected is in `state.json > clarifications_pending`
- [ ] README has a generated marker exactly once
