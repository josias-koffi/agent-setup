---
name: init-project
description: >
  Initialises a project with a multi-agent structure (agents, workflows, skills, sprints, memory, and engineering spec). Works on greenfield projects AND existing codebases. Detects stack and conventions automatically. Use when the user says "init project", "set up agents", "bootstrap this repo", or runs /init-project. Optional arg: path to a vision markdown file. Optional named arg: vault_path=/abs/path to enable Obsidian vault mode.
allowed-tools: Read, Write, Edit, Bash(mkdir:*), Bash(cp:*), Bash(ls:*), Bash(find:*), Bash(cat:*), Bash(test:*), Bash(git:*), Bash(date:*), Bash(env:*), Bash($HOME/.claude/agent-setup/bin/render-templates.sh:*)
---

# init-project — Multi-Agent Project Initialiser

You are setting up a project with a reusable multi-agent structure. Almost all file generation is done by a shell renderer shipped with the framework. Your job is to detect context, invoke the renderer with the right env vars, and handle the small LLM-judgment pieces: vision stub, README append, and final report.

## Parameters
- `$ARGUMENTS[0]` = path to vision markdown file (optional)
- Named arg `vault_path=<abs-path>` = absolute path to the Obsidian vault (optional; enables vault mode)

## Non-negotiable rules

1. Every task, epic, user story, specialised agent, or specific workflow must cite the vision file with `(source: vision section)`.
2. Unknown information becomes `TO CLARIFY`. Never invent.
3. Only add files under `.claude/`, `.project/`, `AGENTS.md`, `agent-setup/`, and (in vault mode) the vault project directory.
4. Be idempotent. Never overwrite existing generated files unless the user explicitly asks. Existing projects that need generated-file migration must use `upgrade-project` or `migrate`.
5. Match the language of the vision file or README.
6. Use only technologies detected in the codebase or explicitly stated in the vision.

## Phase 0 — Preflight

```bash
test -x "${CLAUDE_HOME:-$HOME/.claude}/agent-setup/bin/render-templates.sh" \
  || { echo "Framework not installed. Run: bash bootstrap.sh (from the agent-setup repo)" >&2; exit 2; }
```

If preflight fails, stop and report the install command. Do not fall back to inline generation.

## Phase 1 — Detect context

Build an internal context object. Each field must be either detected or marked `TO CLARIFY`.

### 1.1 — Parse arguments

Scan `$ARGUMENTS` for a named arg of the form `vault_path=<value>`. Extract the value as `VAULT_PATH`. The remaining positional argument (if any) is the vision file path.

### 1.2 — Greenfield vs existing

```bash
test -d .git && echo "git-yes" || echo "git-no"
ls -1 | head -50
```

Set `project_type`:
- `greenfield` if the repo is effectively empty
- `existing` otherwise

### 1.3 — Stack

Detect from standard manifest files and scripts. Unknown commands must remain literal `TO CLARIFY` strings.

### 1.4 — Conventions

Inspect linters, CI config, and coverage tooling.

### 1.5 — Architecture hints

Use common directory heuristics such as clean architecture, MVC-ish, feature-sliced, or monorepo. Default to `unknown`.

### 1.6 — Project name

Infer from the primary manifest file or the current directory name.

## Phase 2 — Vault setup

### If vault_path is provided (vault mode)

Compute:
- `VAULT_PATH` = value provided
- `VAULT_PROJECT_PATH` = `$VAULT_PATH/$PROJECT_NAME`

Check vault state:
- `$VAULT_PATH` does not exist → will be created (fresh vault)
- `$VAULT_PATH` exists but `$VAULT_PROJECT_PATH` does not exist → will add project to vault
- `$VAULT_PATH` exists and `$VAULT_PROJECT_PATH` exists → stop and report: "Project already exists in vault. Use /migrate or /upgrade-project."

Create repo directory structure (minimal):
```bash
mkdir -p .claude .project
```

### If no vault_path (legacy mode)

Set `VAULT_PATH=""` and `VAULT_PROJECT_PATH=""`.

Create full repo directory structure:
```bash
mkdir -p .claude .project/{decisions,designs,spikes,releases,sprints,workflows}
mkdir -p agent-setup/agents/{product-owner,developer,test-writer,designer,analyst,qa-reviewer,tech-lead,specialized}
mkdir -p agent-setup/{workflows,skills,spec}
```

## Phase 3 — Vision handling

Three branches:

A. If the vision file path argument is provided, copy it verbatim to the vision destination and set `VISION_MODE=verbatim`.
   - Vault mode: destination = `$VAULT_PROJECT_PATH/vision.md`
   - Legacy mode: destination = `.project/vision.md`

B. If the vision file already exists at the destination, leave it untouched and set `VISION_MODE=reinit`.

C. Otherwise set `VISION_MODE=auto-stub` and let the renderer create the vision stub. Build `DETECTED_FEATURES_BLOCK` from actual routes, modules, and entry points.

## Phase 4 — Invoke the renderer

Compute every required variable and call the renderer once. Export all vars before calling.

Required env vars for the renderer:
- `PROJECT_NAME`, `PROJECT_TYPE`, `STACK`, `STACK_DETAILS`, `ARCHITECTURE_STYLE`
- `LINT_CMD`, `FORMAT_CMD`, `TEST_CMD`, `BUILD_CMD`, `DEV_CMD`, `AUDIT_CMD`
- `COVERAGE_TOOL`, `CI_STATUS`, `LINTERS`
- `TODAY_ISO`, `TODAY_PLUS_14`
- `VISION_MODE`, `DETECTED_FEATURES_BLOCK`, `CLARIFICATIONS_JSON_ARRAY`
- `VAULT_PATH`, `VAULT_PROJECT_PATH` (empty strings in legacy mode)

Optional MCP env vars (defaulted by the renderer to `$HOME/.agent-setup/vendor/cve-mcp-server` when unset, matching `bootstrap.sh` install layout):
- `CVE_MCP_HOME`, `CVE_MCP_PYTHON` — override only when CVE MCP is installed at a non-default path.

If the user passed `bash bootstrap.sh --no-mcp`, warn that `.mcp.json` and `.codex/config.toml` will still reference `cve-mcp` and instruct removal of those blocks after init.

Rules:
- Every renderer variable must be provided.
- `CLARIFICATIONS_JSON_ARRAY` must be valid JSON.
- Surface renderer stderr verbatim on any non-zero exit and stop.

## Phase 4b — Install project skill overrides

After the renderer exits 0, install each generated project skill so it takes precedence over the global agnostic version in both runtimes:

```bash
for skill_file in agent-setup/skills/*.md; do
  skill_name="$(basename "$skill_file" .md)"
  mkdir -p ".claude/skills/$skill_name"
  cp "$skill_file" ".claude/skills/$skill_name/SKILL.md"
  mkdir -p ".codex/skills/$skill_name"
  cp "$skill_file" ".codex/skills/$skill_name/SKILL.md"
done
```

This gives each project a stack-specific override that both Claude Code and Codex CLI will prefer over `~/.claude/skills/` and `~/.codex/skills/`.

## Phase 4c — Impeccable install (UI projects)

Run only when the detected stack is `Next.js`, `Node/JS`, or any stack where a
`package.json` with front-end dependencies is present (`react`, `vue`, `svelte`,
`angular`, `solid`, `@angular`).

```bash
# Impeccable — anti-pattern scanner + quality gate
test -f ".claude/skills/impeccable/SKILL.md" \
  || npx --yes skills add pbakaus/impeccable

# frontend-design (Anthropic) — aesthetic direction + Design Thinking scaffolding
test -f ".claude/skills/frontend-design/SKILL.md" \
  || npx --yes skills add anthropics/claude-code#plugins/frontend-design
```

After install, generate the Impeccable context files:

1. **`PRODUCT.md`** — If `vision.md` exists, extract:
   - Target audience / personas → _Who we're designing for_
   - Brand voice → _Tone and personality_
   - Known anti-references (competitors, visual styles to avoid)

   Write `PRODUCT.md` with this structure:
   ```markdown
   # Product Design Context

   ## Who we're designing for
   <extracted from vision.md personas, or TO CLARIFY>

   ## Brand voice
   <extracted from vision.md, or TO CLARIFY>

   ## Anti-references (styles to avoid)
   <extracted or TO CLARIFY>
   ```

2. **`DESIGN.md`** — Create a minimal stub (full generation happens via `/impeccable document`):
   ```markdown
   # Design Spec

   > Generated stub — run `/impeccable document` to build the full spec.

   ## Design system
   TO CLARIFY

   ## Color tokens
   TO CLARIFY

   ## Typography scale
   TO CLARIFY
   ```

If `npx skills add` is unavailable or fails, note the manual install command in the
final report: `npx skills add pbakaus/impeccable` and skip without error.

## Phase 5 — README append

Append the generated snippet only once, using the existing generated marker.

## Phase 6 — Final report

Report:
- detected stack, architecture, lint/test/CI
- vault mode: vault path and project vault path (or "legacy mode")
- created files and directories
- clarification list
- recommended next actions

**Vault mode** — created structure includes:
- Repo: `AGENTS.md`, `.claude/CLAUDE.md`, `.claude/settings.json`, `.project/state.json`, `agent-setup/skills/`
- Vault: `$VAULT_PROJECT_PATH/vision.md`, `sprints/`, `agents/<6 roles>/`, `workflows/definitions/`, `spec/`

**Legacy mode** — created structure includes:
- `AGENTS.md`, `.claude/CLAUDE.md`, `.claude/settings.json`
- `.project/vision.md`, `.project/state.json`, `.project/workflows/`, `.project/sprints/`
- `agent-setup/spec/engineering-standards.md`
- `agent-setup/agents/<6 roles>/{agent.md,memory.md}`
- `agent-setup/workflows/<workflow files>`, `agent-setup/skills/<skill files>`

Recommend next actions in this order:
1. Review vision file
2. Fill any `TO CLARIFY` commands in `.claude/CLAUDE.md`
3. Review engineering-standards.md
4. Review sprint-001.md
5. *(UI projects only)* Fill `PRODUCT.md` and run `/impeccable document` to build the full `DESIGN.md`
6. If this repository was already initialized and now needs framework-managed file updates, use `upgrade-project`
7. Run `sprint 001` for sprint-scoped orchestration or `run-workflow <workflow> <task-id|task-text>` for direct staged orchestration

## Final self-check

- Preflight passed
- No file created outside the allowed directories
- Vision file exists
- Renderer exited `0`
- `.project/state.json` parses as valid JSON
- `clarifications_pending` contains every pending clarification
- README contains the generated marker exactly once
