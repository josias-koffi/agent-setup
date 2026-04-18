# Multi-Agent Project Orchestrator for Claude Code and Codex CLI

A two-layer system with dual CLI support:

- **`bootstrap.sh`** — a one-time global install. Copies templates, a shell renderer, and three skills into both `~/.claude/` and `~/.codex/`. Runs in pure bash.
- **`init-project` / `/init-project`** — a thin per-project command. Detects stack + context, invokes the shell renderer, and produces a full multi-agent project structure for both Claude and Codex entrypoints.

Every project initialised with `/init-project` gets:

- **6 base agents** (product-owner, developer, designer, analyst, qa-reviewer, tech-lead), each with its own memory file
- **4 workflows** (analyze-design-dev-review, bug-triage, spike-research, release)
- **5 skills** (git-push-safe, lint-and-format, run-tests, create-pr, dependency-audit) adapted to the detected stack
- **Engineering spec** — Clean Architecture, 80% test coverage, Conventional Commits, trunk-based branching, ADRs, WCAG AA, OWASP baseline, structured observability
- **Project memory** — `CLAUDE.md` + per-agent `memory.md` journals
- **Blocking vs advisory enforcement** — tests/security/coverage are blocking; style is advisory
- **Global sprint skill/command** to run any agent + workflow against a sprint task
- **Global run-agent skill/command** to run any agent on an ad hoc task, with or without a workflow

## Install (once)

```bash
bash bootstrap.sh                 # install or upgrade
bash bootstrap.sh --force         # reinstall (backs up current templates)
bash bootstrap.sh --dry-run       # print actions without writing
```

Installs to `~/.claude/` and `~/.codex/` (or `$CLAUDE_HOME` / `$CODEX_HOME` if set):

```
~/.claude/
├── skills/{init-project,sprint,run-agent}/SKILL.md
└── agent-setup/{VERSION,bin/,templates/}

~/.codex/
├── skills/{init-project,sprint,run-agent}/SKILL.md
└── agent-setup/{VERSION,bin/,templates/}
```

## Use

```bash
cd ~/your-project
claude

# Greenfield with a vision file:
/init-project ./vision.md

# Existing codebase — auto-detects stack, auto-generates vision stub from README:
/init-project

# Re-run safely at any time — the renderer skips files that already exist.
```

After `/init-project` completes, `/sprint` is already available (installed globally by `bootstrap.sh`):

```bash
/sprint 001 developer    analyze-design-dev-review US-001
/sprint 001 developer    analyze-design-dev-review all
/sprint 001 qa-reviewer  analyze-design-dev-review US-001
/sprint 001 tech-lead    release all
```

Codex CLI can use the same generated project with skills invoked via `$...`:

```text
$init-project ./vision.md
$sprint 001 developer analyze-design-dev-review US-001
```

Important:

- Claude uses slash commands: `/init-project`, `/sprint`, `/run-agent`
- Codex uses skills: `$init-project`, `$sprint`, `$run-agent`

## Run A Specific Agent On A Task

Once a project has been initialised, use the global `sprint` skill/command to run one agent on one task:

```text
sprint <sprint-number> <agent> <workflow> <task-id|all>
```

Meaning:

- `sprint-number` — sprint file to use, for example `001`
- `agent` — one of `product-owner`, `developer`, `designer`, `analyst`, `qa-reviewer`, `tech-lead`
- `workflow` — one of `analyze-design-dev-review`, `bug-triage`, `spike-research`, `release`
- `task-id` — a task identifier from `sprints/sprint-NNN.md`, or `all`

Examples:

```bash
# Run the developer on task US-001 in sprint 001
/sprint 001 developer analyze-design-dev-review US-001

# Run the QA reviewer on the same task
/sprint 001 qa-reviewer analyze-design-dev-review US-001

# Run the product owner on a clarification/research task
/sprint 001 product-owner spike-research US-001

# Run one agent on every task in the sprint
/sprint 001 developer analyze-design-dev-review all
```

Codex CLI uses the same arguments through the `$sprint` skill:

```text
$sprint 001 developer analyze-design-dev-review US-001
```

The command will load the project context (`AGENTS.md`, `.claude/CLAUDE.md`, vision, sprint, agent memory, workflow), validate that the task exists, then run the selected agent against that task only.

## Run An Agent Outside Sprints

Use `run-agent` when the work is project-scoped but not attached to `sprints/sprint-NNN.md`.

```text
run-agent <agent> [workflow] <task text>
```

Modes:

- With a workflow: `run-agent developer analyze-design-dev-review Fix checkout race condition`
- Without a workflow: `run-agent qa-reviewer Review recent checkout changes for regressions`

Claude examples:

```bash
/run-agent developer analyze-design-dev-review "Fix checkout race condition"
/run-agent analyst spike-research "Compare SSO providers for B2B customers"
/run-agent qa-reviewer "Review recent checkout changes for regressions"
```

Codex CLI examples:

```text
$run-agent developer analyze-design-dev-review Fix checkout race condition
$run-agent qa-reviewer Review recent checkout changes for regressions
```

`run-agent` loads the same project context as `sprint`, but it does not require a sprint number, does not require a task ID in `sprints/sprint-NNN.md`, and does not update sprint files.

## What gets created in a project

```
your-project/
├── AGENTS.md                          # auto-loaded guidance for Codex CLI
├── .claude/
│   └── CLAUDE.md                         # auto-loaded every session
├── .project/
│   ├── vision.md                         # source of truth, never auto-edited
│   ├── state.json                        # current sprint + clarifications
│   ├── decisions/                        # ADRs
│   ├── designs/                          # mockups / journey maps
│   ├── spikes/                           # research notes
│   └── releases/                         # release notes
├── spec/
│   └── engineering-standards.md          # 9 sections, blocking + advisory rules
├── agents/
│   ├── product-owner/  {agent.md, memory.md}
│   ├── developer/      {agent.md, memory.md}
│   ├── designer/       {agent.md, memory.md}
│   ├── analyst/        {agent.md, memory.md}
│   ├── qa-reviewer/    {agent.md, memory.md}
│   ├── tech-lead/      {agent.md, memory.md}
│   └── specialized/                      # project-specific, only if justified by vision
├── workflows/
│   ├── analyze-design-dev-review.md
│   ├── bug-triage.md
│   ├── spike-research.md
│   └── release.md
├── skills/
│   ├── git-push-safe.md
│   ├── lint-and-format.md
│   ├── run-tests.md
│   ├── create-pr.md
│   └── dependency-audit.md
└── sprints/
    ├── backlog.md
    └── sprint-001.md
```

## How the token-savings work

Old model (single mega-skill): `/init-project` loaded ~900 lines of inline templates into context and re-typed every file. Slow, expensive, error-prone.

New model: `bootstrap.sh` installs templates as plain files under each CLI home. `/init-project` only does the work that requires judgment: stack detection, vision-stub enrichment, and clarifications. All static generation is delegated to `bin/render-templates.sh`, which reads templates, substitutes `{{VARS}}`, and writes output files.

## Anti-hallucination guarantees

- Every generated task, epic, user story, and specialised agent cites the vision: `(source: vision §<section>)`
- Missing information becomes `⚠️ TO CLARIFY: <question>` — never invented
- Vision file is copied verbatim, never summarised
- Sprints are capped at 3–8 real tasks, never padded
- Files have a generated marker; the renderer refuses to overwrite existing files

## Memory protocol

Every agent, before acting:
1. Reads `AGENTS.md` when running in Codex CLI, or `.claude/CLAUDE.md` when running in Claude Code
2. Reads its own `agents/<role>/memory.md`
3. Reads `spec/engineering-standards.md`
4. Reads the active sprint file

Every agent, after acting: appends a dated entry to its memory file with `Did / Why / Learned / Open`.

## Enforcement policy

**Blocking** (refuses commit/merge):
- Failing tests
- Coverage below 80% line / 70% branch / 90% on new code
- Secrets detected in code
- Critical or high dependency vulnerabilities
- Missing ADR for stack changes
- WCAG AA violations on UI work
- OWASP Top 10 surface issues

**Advisory** (warns but does not block):
- Naming conventions
- Function / file length
- Docstring coverage
- Magic numbers

## Updating

Pull a newer version of this repo and re-run `bash bootstrap.sh`. If the `VERSION` file changed, bootstrap rolls each installed target forward independently; `--force` backs up each existing framework tree before reinstalling.

## Uninstall

```bash
rm -rf ~/.claude/agent-setup ~/.claude/skills/init-project ~/.claude/skills/sprint
rm -rf ~/.codex/agent-setup ~/.codex/skills/init-project ~/.codex/skills/sprint
```
