---
name: init
description: >
  Initialises or upgrades a project with a multi-agent structure (agents, workflows, skills, sprints, memory, and engineering spec). Works on greenfield projects AND existing codebases. Detects stack and conventions automatically. Use when the user says "init project", "set up agents", "bootstrap this repo", or runs /init. Optional arg: path to a vision markdown file.
allowed-tools: Read, Write, Bash(mkdir:*), Bash(cp:*), Bash(ls:*), Bash(find:*), Bash(cat:*), Bash(test:*), Bash(git:*)
---

# /init — Multi-Agent Project Initialiser

You are setting up (or upgrading) a project with a reusable multi-agent structure, persistent memory, and enforced engineering standards.

## Parameters
- `$ARGUMENTS[0]` = path to vision markdown file (optional)

If no argument is provided, you will generate a vision stub from the existing codebase and README.

---

## ⚠️ Non-negotiable rules (read first)

1. **Citation required** — Every task, epic, user story, specialised agent, or specific workflow MUST cite a section of `.project/vision.md` using `(source: vision §<section>)`. No citation → do not create.
2. **Unknown → clarify** — Information not found in the vision OR detected in the codebase becomes `⚠️ TO CLARIFY: <precise question>`. Never invent.
3. **No destructive changes to existing code** — You may add files under `.claude/`, `.project/`, `agents/`, `workflows/`, `skills/`, `sprints/`, `spec/`. You may NEVER modify source code, config files, or anything outside those directories unless the user explicitly asks.
4. **Idempotent** — If a file already exists at a target path, read it first. Preserve user edits. Only overwrite if you detect it is an unmodified template from a previous `/init` run (check for the `<!-- generated-by: /init -->` marker).
5. **Language** — Match the language of the vision file for all generated content. If the vision is auto-generated, match the language of the README. Default: English.
6. **No inventing stack** — Use only technologies that are either (a) detected in the codebase or (b) explicitly mentioned in the vision.

---

## Phase 0 — Detect context

Run these checks before writing anything. Build an internal `CONTEXT` object.

### 0.1 — Is it a greenfield or existing project?

```bash
test -d .git && echo "git-yes" || echo "git-no"
ls -1 | head -50
```

Mark `CONTEXT.project_type` as:
- `greenfield` if the directory is empty or only has README/LICENSE
- `existing` otherwise

### 0.2 — Detect stack (existing projects only)

Check for these files and set `CONTEXT.stack`:

| File / Folder present | Stack label |
|---|---|
| `package.json` | `node` — then read it to refine: look for `next`, `react`, `vue`, `nestjs`, `express` in deps |
| `Cargo.toml` | `rust` |
| `pyproject.toml` or `requirements.txt` | `python` — look for `fastapi`, `django`, `flask` |
| `go.mod` | `go` |
| `Gemfile` | `ruby` |
| `pom.xml` or `build.gradle` | `java` |
| `composer.json` | `php` |

Record commands found:
- Lint: parse `package.json > scripts.lint` etc.
- Test: parse `package.json > scripts.test` etc.
- Build: parse `package.json > scripts.build` etc.
- Dev: parse `package.json > scripts.dev` or `start`

If not found → mark `⚠️ TO CLARIFY: lint command`, same for test/build/dev.

### 0.3 — Detect conventions

- Check for `.eslintrc*`, `.prettierrc*`, `ruff.toml`, `rustfmt.toml`, `.editorconfig` → record in `CONTEXT.linters`.
- Check for `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/` → record `CONTEXT.ci`.
- Check branching:
  ```bash
  git branch -a 2>/dev/null | head -20
  ```
  If only `main` or `main` + short-lived branches → trunk-based. Otherwise flag for review.
- Check test coverage config: `jest.config.*`, `vitest.config.*`, `.coveragerc`, `tarpaulin.toml` → record `CONTEXT.coverage_config`.

### 0.4 — Detect architecture hints

Look for directories suggesting architecture style:
- `src/domain/`, `src/application/`, `src/infrastructure/` → Clean / Hexagonal
- `src/controllers/`, `src/services/`, `src/models/` → MVC-ish
- `src/features/` → feature-sliced
- `packages/` or `apps/` → monorepo

Record `CONTEXT.architecture_style` or mark `unknown`.

### 0.5 — Vision file

- If `$ARGUMENTS[0]` is provided → confirm it exists and is readable.
- If no argument AND `.project/vision.md` already exists → use it (re-init mode).
- Otherwise → flag `CONTEXT.needs_vision_stub = true`.

---

## Phase 1 — Create directory tree

```bash
mkdir -p .claude
mkdir -p .project/decisions
mkdir -p .project/designs
mkdir -p .project/spikes
mkdir -p .project/releases
mkdir -p agents/product-owner
mkdir -p agents/developer
mkdir -p agents/designer
mkdir -p agents/analyst
mkdir -p agents/qa-reviewer
mkdir -p agents/tech-lead
mkdir -p agents/specialized
mkdir -p workflows
mkdir -p skills
mkdir -p sprints
mkdir -p spec
```

Each base agent has its own directory to hold both its definition (`agent.md`) and its memory (`memory.md`).

---

## Phase 2 — Write or copy the vision

### If vision file provided (`$ARGUMENTS[0]`):
Copy it verbatim to `.project/vision.md`. No summarisation.

### If `.project/vision.md` already exists:
Leave it untouched. Record in the final report that re-init mode was used.

### If neither — auto-generate from codebase + README:

Read any of: `README.md`, `README.txt`, `package.json > description`, top-level comments in main entry files.

Write `.project/vision.md` using this template:

```markdown
<!-- generated-by: /init | mode: auto-stub | needs-review: true -->

# Product Vision — <project name from detection>

> ⚠️ This vision was auto-generated from the existing codebase and README.
> Review, correct, and expand it before running sprints.

## Product goal
<single sentence extracted from README intro, or ⚠️ TO CLARIFY>

## Personas
- ⚠️ TO CLARIFY: personas not explicitly defined — extract from user-facing features

## Main features (detected)
- <feature inferred from directory or route structure, with file reference>
- ...

## Technical context (detected)
- Stack: <CONTEXT.stack>
- Architecture style: <CONTEXT.architecture_style>
- CI: <CONTEXT.ci or none>
- Linters: <CONTEXT.linters or none>

## Success metrics
- ⚠️ TO CLARIFY: no metrics detected — define KPIs per epic

## Out of scope
- ⚠️ TO CLARIFY
```

Add every `⚠️ TO CLARIFY` to `.project/state.json > clarifications_pending`.

---

## Phase 3 — Write `.claude/CLAUDE.md` (project memory root)

This file is loaded by Claude Code at every session start. Keep it short and actionable.

```markdown
<!-- generated-by: /init -->
# CLAUDE.md — <PROJECT_NAME>

> Auto-loaded by Claude Code every session. Keep this file short. Long content goes in spec/, agents/<role>/, or .project/.

## Project
- Name: <PROJECT_NAME>
- Vision: `.project/vision.md` (source of truth, never auto-edit)
- State: `.project/state.json`
- Engineering spec: `spec/engineering-standards.md` (read before coding)

## Stack (detected)
- <CONTEXT.stack details>
- Architecture: <CONTEXT.architecture_style>

## Commands
- Lint: `<detected-lint-cmd or ⚠️ TO CLARIFY>`
- Format: `<detected-format-cmd or ⚠️ TO CLARIFY>`
- Test: `<detected-test-cmd or ⚠️ TO CLARIFY>`
- Build: `<detected-build-cmd or ⚠️ TO CLARIFY>`
- Dev: `<detected-dev-cmd or ⚠️ TO CLARIFY>`

## Agents — one per role, with own memory
- Product Owner → `agents/product-owner/agent.md` + `memory.md`
- Developer → `agents/developer/agent.md` + `memory.md`
- Designer → `agents/designer/agent.md` + `memory.md`
- Analyst → `agents/analyst/agent.md` + `memory.md`
- QA Reviewer → `agents/qa-reviewer/agent.md` + `memory.md`
- Tech Lead → `agents/tech-lead/agent.md` + `memory.md`
- Specialised (project-specific) → `agents/specialized/`

## Memory protocol (strict)
Before any substantial action, every agent MUST:
1. Read `.claude/CLAUDE.md` (this file)
2. Read `agents/<own-role>/memory.md`
3. Read `spec/engineering-standards.md`
4. Read the relevant sprint file under `sprints/`

After completing a task, every agent MUST append a dated entry to its own `memory.md` covering: what was done, why, what it learned, and open questions.

## Enforcement policy
- **Blocking** (refuse commit/merge): failing tests, coverage below threshold in `spec/engineering-standards.md`, secrets detected, critical dependency vulnerabilities, missing ADR for stack changes.
- **Advisory** (warn but allow): style/naming nits, documentation gaps, non-critical TODOs.

See `spec/engineering-standards.md` for full rules.

## Hard rules
- Never modify `.project/vision.md`
- Never check a sprint task box unless every acceptance criterion is verified
- Never add features absent from `.project/vision.md` without explicit user approval
- Never introduce a new framework without an ADR in `.project/decisions/`

## Run a sprint
```
/sprint <sprint-number> <agent> <workflow> <task-id|all>
/sprint 001 developer analyze-design-dev-review US-001
```
```

---

## Phase 4 — Write `spec/engineering-standards.md`

This is **the** reference document agents consult before writing or reviewing code. Adapted to the detected stack where possible.

```markdown
<!-- generated-by: /init | adapt to detected stack when possible -->
# Engineering Standards

> Non-negotiable standards for this project. Agents refuse to ship code that violates blocking rules.
> Last updated: <ISO date>

## 1. Clean Architecture (blocking)

**Rule**: Dependencies point inward. Outer layers depend on inner layers, never the reverse.

Layers (adapted to <CONTEXT.stack>):
- **Domain** — pure business logic, no framework imports
- **Application** — use cases, orchestrates domain
- **Infrastructure** — DB, HTTP clients, external APIs
- **Interface** — controllers, CLI, UI adapters

Enforcement:
- Domain must not import from Application, Infrastructure, or Interface
- Application must not import from Infrastructure or Interface
- Violations are blocking — QA Reviewer refuses the PR

If the project already uses a different architecture, document it here and keep the dependency-rule principle.

## 2. Test coverage (blocking)

- Minimum line coverage: **80%**
- Minimum branch coverage: **70%**
- New code in a PR: **90%** line coverage minimum
- Coverage drop vs main: **blocks** the PR

Measured with: `<detected-coverage-tool or ⚠️ TO CLARIFY>`

## 3. Conventional Commits + SemVer (blocking on commit)

Format: `<type>(<scope>): <description>`

Allowed types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `style`, `perf`, `ci`, `build`.

Examples:
- `feat(auth): add passwordless login`
- `fix(billing): correct VAT calculation for EU customers`

Versioning:
- `feat` → minor bump
- `fix` → patch bump
- Breaking change (`!` after type or `BREAKING CHANGE:` in body) → major bump

## 4. Trunk-based branching (blocking)

- One long-lived branch: `main` (always deployable)
- Short-lived feature branches: max **2 days** before merge
- PRs: max **400 lines** of diff (hard review limit)
- Feature flags for incomplete features merged to main

## 5. ADRs for stack changes (blocking)

Required when: adding a new library (non-patch), changing data store, changing architecture style, changing auth provider, changing deployment target.

Location: `.project/decisions/ADR-NNN-<slug>.md`

Template:
```
# ADR-NNN: <title>
Date: <date>
Status: proposed | accepted | superseded

## Context
## Decision
## Consequences
## Alternatives considered
```

## 6. Accessibility (blocking for UI work)

- WCAG 2.1 AA for all user-facing interfaces
- All interactive elements keyboard-accessible
- All images have meaningful `alt` text (or `alt=""` if decorative)
- Colour contrast ratio ≥ 4.5:1 for text, ≥ 3:1 for large text/UI
- Form inputs have associated labels
- Semantic HTML (headings in order, landmark roles)

Tested with: axe-core or equivalent in CI.

## 7. Security baseline (blocking)

- **No secrets in code** — enforced by pre-commit hook + CI secret scanning
- **Dependency audit** on every PR — no critical or high vulnerabilities
- **OWASP Top 10** reviewed for every user-input surface:
  - Injection (validate + parameterise)
  - Broken auth (MFA option, secure sessions)
  - Sensitive data (TLS, encryption at rest for PII)
  - XXE / SSRF (disable external entities, allowlist hosts)
  - Broken access control (authorisation on every protected route)
  - Misconfig (hardened defaults, no debug in prod)
  - XSS (escape output, CSP)
  - Insecure deserialisation
  - Known vulns (automated audit)
  - Insufficient logging (see §8)

## 8. Observability (blocking for new services)

- **Structured logs**: JSON, one event per log line
- **Required fields**: timestamp (ISO 8601), level, service, trace_id, message, context
- **Error tracking**: every unhandled exception → tracker (e.g. Sentry)
- **Metrics**: request rate, error rate, p50/p95/p99 latency per endpoint
- **Health endpoints**: `/health` (liveness) and `/ready` (readiness)

## 9. Advisory standards (non-blocking)

These are enforced by the QA Reviewer in a warning mode. Agents should fix them but a single advisory failure does not block the PR.

- Naming: `camelCase` for variables/functions, `PascalCase` for types/classes, `SCREAMING_SNAKE` for constants
- Max function length: 50 lines (warning beyond)
- Max file length: 400 lines (warning beyond)
- Documentation: every exported symbol has a docstring/JSDoc
- Magic numbers: replace with named constants

## Enforcement summary

| Rule | Mode | Gate |
|---|---|---|
| Clean architecture | Blocking | Pre-commit, PR review |
| Test coverage (80% / 90% new) | Blocking | CI |
| Conventional Commits | Blocking | commit-msg hook |
| Trunk-based + PR size | Blocking | PR review |
| ADR for stack changes | Blocking | PR review |
| Accessibility (WCAG AA) | Blocking (UI) | CI (axe) |
| Security baseline | Blocking | CI + pre-commit |
| Observability | Blocking (services) | PR review |
| Naming / length / docs | Advisory | PR review |
```

---

## Phase 5 — Write the 6 base agents

For each of `product-owner`, `developer`, `designer`, `analyst`, `qa-reviewer`, `tech-lead`:

Write `agents/<role>/agent.md` using the template below.
Write `agents/<role>/memory.md` as an empty journal (template below).

### Agent template (`agents/<role>/agent.md`)

```markdown
<!-- generated-by: /init -->
# Agent: <Role Title>

## Role
<one precise sentence>

## Before any action (memory protocol)
1. Read `.claude/CLAUDE.md`
2. Read `agents/<role>/memory.md`
3. Read `spec/engineering-standards.md`
4. Read the active sprint file under `sprints/`

## Responsibilities
- <3 to 6 items>

## Inputs
- <what files/data the agent reads>

## Outputs
- <what files/data the agent writes>

## Workflows this agent can run
- <workflow-id>: <when>

## Skills this agent can use
- <skill-id>: <when>

## Definition of Done (per task)
- [ ] All acceptance criteria verified
- [ ] Relevant spec rules (spec/engineering-standards.md) satisfied
- [ ] Memory updated (agents/<role>/memory.md)

## Guardrails (hard refusals)
- <3 to 5 refusals, including spec-blocking rules>

## After every action (memory update)
Append to `agents/<role>/memory.md`:
```
## <ISO date> — <task-id or short title>
- **Did**: <what was done>
- **Why**: <reason>
- **Learned**: <insight>
- **Open**: <unresolved questions>
```
```

### Specific content per role

**Product Owner** — role: owns backlog and vision alignment. Guardrails include: never adds features absent from vision without explicit user approval.

**Developer** — role: implements sprint tasks. Guardrails: never commits with failing tests; never bypasses lint; coverage on new code ≥ 90%; must create ADR before introducing a new library.

**Designer** — role: mockups, design system, journey maps. Guardrails: must verify WCAG AA compliance; never designs for personas absent from vision.

**Analyst** — role: KPIs, data analysis, user research. Guardrails: never invents metrics; every epic must have at least one measurable KPI.

**QA Reviewer** — role: validates PRs against acceptance criteria AND engineering spec. Guardrails: blocks PR on any blocking spec rule violation; runs tests, lint, coverage, dependency audit, accessibility check; advisory rules get warning comments.

**Tech Lead** — role: architecture decisions, tech debt, ADRs. Guardrails: refuses new framework without ADR; enforces clean architecture dependency rule; approves release gates.

### Memory template (`agents/<role>/memory.md`)

```markdown
<!-- generated-by: /init -->
# Memory — <Role Title>

> Append-only journal. Most recent entry at the bottom.
> Every agent action writes here per the memory protocol in CLAUDE.md.

## <ISO date> — init
- **Did**: Initialised agent definition and empty memory.
- **Why**: Project bootstrap.
- **Learned**: Stack detected as <CONTEXT.stack>. Architecture: <CONTEXT.architecture_style>.
- **Open**: See `.project/state.json > clarifications_pending`.
```

---

## Phase 6 — Write the 4 base workflows

File: `workflows/<n>.md`

### `workflows/analyze-design-dev-review.md`

```markdown
<!-- generated-by: /init -->
# Workflow: Analyze → Design → Dev → Review

## Trigger
A task moves to "In Progress" in the active sprint file.

## Steps

1. **Analyze** (`product-owner`)
   - Read task. Verify acceptance criteria complete (≥ 2 verifiable items).
   - Output: confirmation note in sprint file.
   - Pass: criteria confirmed.

2. **Design** (`designer`) — skip if non-UI
   - Produce mockup/journey in `.project/designs/<task-id>.md`.
   - Verify WCAG AA compliance upfront.
   - Pass: developer acknowledges design.

3. **Implement** (`developer`)
   - Read `spec/engineering-standards.md`. Honour clean architecture.
   - Write code + tests (new code coverage ≥ 90%).
   - Skills: `lint-and-format`, `run-tests`.
   - Pass: lint green, tests green, coverage ≥ threshold.

4. **Commit & PR** (`developer`)
   - Skills: `git-push-safe`, `create-pr`.
   - Pass: conventional commit format, PR ≤ 400 lines, PR description complete.

5. **Review** (`qa-reviewer`)
   - Run tests, check coverage, run dependency audit, check accessibility (if UI).
   - Verify every acceptance criterion line by line.
   - Verdict: ✅ (all blocking rules pass) or ❌ (any blocking rule fails — back to step 3).
   - Advisory findings → warning comments, do not block.

## Rollback point
Step 3 on ❌ from step 5.

## State logs
- `last_workflow_run`: "analyze-design-dev-review"
- `last_task_completed`: "<task-id>"
```

### `workflows/bug-triage.md`

```markdown
<!-- generated-by: /init -->
# Workflow: Bug Triage

## Trigger
Defect reported during sprint.

## Steps
1. **Reproduce** (`developer`) — document steps + expected/actual. Pass: consistently reproducible OR "cannot reproduce" marked.
2. **Categorise** (`tech-lead`) — severity P0/P1/P2, root cause area. Pass: severity assigned.
3. **Prioritise** (`product-owner`) — add to backlog with severity, decide sprint inclusion. Pass: backlog entry exists.
4. **Assign** (`product-owner`) — if P0/P1 add to current sprint, acceptance criteria = "bug fixed + regression test added".

## Rollback
Step 1 if root cause changes after failed fix.

## State logs
- `bugs_triaged`: increment
```

### `workflows/spike-research.md`

```markdown
<!-- generated-by: /init -->
# Workflow: Spike Research

## Trigger
A question cannot be answered with current knowledge and needs time-boxed investigation.

## Steps
1. **Frame** (`tech-lead` or `analyst`) — write question + time-box (max hours) in `.project/spikes/SPIKE-NNN.md`. Pass: question specific.
2. **Investigate** (`developer` or `analyst`) — research inside time-box, document findings, no implementation. Pass: time-box respected, findings written.
3. **Decide** (`tech-lead`) — proceed/reject/defer with rationale + ADR if architectural. Pass: decision unambiguous.

## Rollback
None — spikes are exploratory; stop and report if time-box exceeded.
```

### `workflows/release.md`

```markdown
<!-- generated-by: /init -->
# Workflow: Release

## Trigger
Sprint DoD fully met and release approved.

## Steps
1. **Freeze** (`tech-lead`) — confirm sprint DoD ticks. Pass: all tasks ✅.
2. **Regression** (`qa-reviewer`) — skill `run-tests` full suite. Pass: 100% green.
3. **Dep audit** (`tech-lead`) — skill `dependency-audit`. Pass: 0 critical, 0 high, no licence violations.
4. **Tag & changelog** (`developer`) — semver tag, generate changelog from conventional commits.
5. **Deploy** (`developer`) — run deploy command from `.claude/CLAUDE.md`.
6. **Release note** (`product-owner`) — write `.project/releases/vX.Y.Z.md` summarising delivered value per epic.

## Rollback
Step 2 if regression fails post-deploy; revert tag.

## State logs
- `releases`: append `{version, date}`
```

---

## Phase 7 — Write the 5 base skills

Adapt commands to detected stack. If undetected, use placeholder and add `⚠️ TO CLARIFY`.

### `skills/git-push-safe.md`

```markdown
<!-- generated-by: /init -->
# Skill: git-push-safe

## Objective
Commit and push only after quality gates pass, using Conventional Commits.

## Preconditions
- [ ] Lint passed (`lint-and-format`)
- [ ] Tests passed (`run-tests`)
- [ ] Coverage ≥ threshold in spec
- [ ] Commit message matches `^(feat|fix|chore|docs|refactor|test|style|perf|ci|build)(\(.+\))?(!)?: .{10,}$`

## Procedure
1. `git status` — confirm staged files are task-related only.
2. `git diff --stat HEAD`.
3. Run lint (blocking on failure).
4. Run tests (blocking on failure).
5. `git add <files>` (preferably interactive).
6. `git commit -m "<type>(<scope>): <description>"`.
7. `git push origin <branch>`.

## Checks
- [ ] Lint exit 0
- [ ] Tests exit 0
- [ ] Coverage ≥ threshold
- [ ] Commit message valid

## On failure
Report exact failure, do not commit. Return to developer.

## Output
Commit SHA + push confirmation, or error detail.
```

### `skills/lint-and-format.md`, `skills/run-tests.md`, `skills/create-pr.md`, `skills/dependency-audit.md`

Write these following the same structure, with commands adapted to `CONTEXT.stack`:

| Stack | lint | test | audit |
|---|---|---|---|
| node | `npm run lint` / `pnpm lint` | `npm test` | `npm audit --audit-level=high` |
| rust | `cargo clippy -- -D warnings` | `cargo test` | `cargo audit` |
| python | `ruff check . --fix` | `pytest` | `pip-audit` |
| go | `golangci-lint run` | `go test ./...` | `govulncheck ./...` |

Each skill file uses this template:

```markdown
<!-- generated-by: /init -->
# Skill: <n>

## Objective
<one sentence>

## Preconditions
- [ ] ...

## Procedure (strict order)
1. ...

## Checks
- [ ] ...

## On failure
...

## Output
...
```

---

## Phase 8 — Install the project-local `/sprint` command

Write `.claude/skills/sprint/SKILL.md`:

```markdown
---
name: sprint
description: >
  Runs a specific agent on an active sprint task using a named workflow. Args: sprint-number agent workflow task-id|all.
allowed-tools: Read, Write, Bash(git:*), Bash(npm:*), Bash(cargo:*), Bash(pytest:*), Bash(go:*)
---

# /sprint runner

## Arguments
- $ARGUMENTS[0] = sprint number, zero-padded (e.g. "001")
- $ARGUMENTS[1] = agent name (e.g. "developer")
- $ARGUMENTS[2] = workflow name (e.g. "analyze-design-dev-review")
- $ARGUMENTS[3] = task ID or "all"

## Strict sequence

### 1. Load context
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
```

---

## Phase 9 — Write `.project/state.json`

```json
{
  "project_name": "<PROJECT_NAME>",
  "project_type": "<greenfield|existing>",
  "stack": "<CONTEXT.stack>",
  "architecture_style": "<CONTEXT.architecture_style>",
  "vision_source": ".project/vision.md",
  "vision_auto_generated": <true|false>,
  "engineering_spec": "spec/engineering-standards.md",
  "current_sprint": 1,
  "completed_sprints": [],
  "active_agents": [],
  "specialized_agents": [],
  "specialized_workflows": [],
  "specialized_skills": [],
  "clarifications_pending": [ "<every ⚠️ TO CLARIFY collected so far>" ],
  "last_updated": "<ISO 8601>",
  "last_workflow_run": null,
  "last_task_completed": null
}
```

---

## Phase 10 — Write `sprints/backlog.md` and `sprints/sprint-001.md`

### Backlog

```markdown
<!-- generated-by: /init -->
# Product Backlog

> Source of truth: .project/vision.md

## Epics
- [ ] **E1** — <name> (source: vision §<section>)

## User Stories
| ID | Story | Epic | Est. | Priority | Source |
|----|-------|------|------|----------|--------|
| US-001 | As a <persona> I want <action> so that <benefit> | E1 | ? | P0 | §X |

## ⚠️ To Clarify
- <list every open clarification>
```

If the vision is auto-generated, the backlog will be mostly `⚠️ TO CLARIFY` — that is expected and correct. Do not fabricate user stories.

### Sprint 001

Only create with tasks if the vision has enough signal. Otherwise, create a minimal sprint 001 whose single task is "clarify vision":

```markdown
<!-- generated-by: /init -->
# Sprint 001

## 🎯 Sprint Goal
<derived from top-priority epic OR "Clarify vision and engineering baseline" if auto-stub>

## 📅 Period
- Start: <today>
- End: <today + 14 days>

## ✅ Tasks (3–8 max)
- [ ] **[US-001]** <title>
  - Agent: `developer` (or `product-owner` for clarification tasks)
  - Workflow: `analyze-design-dev-review` (or `spike-research`)
  - Acceptance criteria:
    - [ ] <verifiable>
    - [ ] <verifiable>
  - Source: vision §<section>

## 📊 Sprint DoD
- [ ] All tasks ticked
- [ ] All acceptance criteria verified
- [ ] `run-tests` green
- [ ] Coverage ≥ spec threshold
- [ ] QA review ✅

## 🚧 Risks
- <risk> → <mitigation>

## ⚠️ To Clarify (sprint blockers)
- <list>
```

---

## Phase 11 — Write `README.md` section (append, don't overwrite)

If README exists → **do not overwrite**. Append a section:

```markdown
<!-- generated-by: /init -->
## Multi-Agent Workflow

This project uses an agent-driven workflow. See:
- `.claude/CLAUDE.md` — entry point for Claude Code sessions
- `spec/engineering-standards.md` — non-negotiable engineering rules
- `agents/<role>/` — agent definitions and memory
- `workflows/` — named workflows (analyze-design-dev-review, bug-triage, spike-research, release)
- `sprints/` — backlog and active sprint files

Run a sprint:
```
/sprint 001 developer analyze-design-dev-review US-001
```
```

If no README → create minimal one with same content plus project name.

---

## Phase 12 — Final report

Print to user:

```
✅ <greenfield | existing | re-init> project initialised.

Detected:
  Stack: <CONTEXT.stack>
  Architecture: <CONTEXT.architecture_style>
  Lint: <cmd or ⚠️>
  Test: <cmd or ⚠️>
  CI: <present/absent>

Created:
  .claude/CLAUDE.md
  .claude/skills/sprint/SKILL.md        (/sprint command, project-local)
  .project/vision.md                    (<verbatim | auto-stub>)
  .project/state.json
  spec/engineering-standards.md
  agents/<6 roles>/agent.md + memory.md
  workflows/<4 files>
  skills/<5 files>
  sprints/backlog.md + sprint-001.md

⚠️  Clarifications pending (<N> items):
  - <list>

▶️  Recommended next actions:
  1. Review and correct `.project/vision.md` <if auto-stub>
  2. Fill ⚠️ TO CLARIFY commands in `.claude/CLAUDE.md`
  3. Review `spec/engineering-standards.md` and adjust thresholds if needed
  4. Review `sprints/sprint-001.md` and confirm tasks
  5. Run: `/sprint 001 developer analyze-design-dev-review US-001`
```

---

## Final self-check (before reporting done)

- [ ] No file created outside the allowed directories
- [ ] `.project/vision.md` exists (verbatim copy OR auto-stub with `needs-review: true` marker)
- [ ] `spec/engineering-standards.md` exists with all 9 sections
- [ ] Every agent directory has both `agent.md` and `memory.md`
- [ ] `.claude/CLAUDE.md` references every key path
- [ ] `.claude/skills/sprint/SKILL.md` installed for local `/sprint` command
- [ ] `state.json` is valid JSON
- [ ] Every `⚠️ TO CLARIFY` is also in `state.json > clarifications_pending`
- [ ] No source code or config file outside `.claude/`, `.project/`, `agents/`, `workflows/`, `skills/`, `sprints/`, `spec/` was modified
- [ ] Final report printed with clarifications and next actions
