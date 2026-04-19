# Multi-Agent Project Orchestrator for Claude Code and Codex CLI

A two-layer system with dual CLI support:

- `bootstrap.sh` installs the reusable framework globally into `~/.claude/` and `~/.codex/`.
- `init-project` initializes one specific repository by generating a local project workspace around your vision file.
- `sprint` is the sprint-scoped entrypoint and follows the workflow declared by each sprint task.
- `run-agent` runs an ad hoc task as a single-agent execution.
- `run-workflow` orchestrates a staged multi-agent workflow directly, outside the sprint entrypoint.

## Install Once

```bash
bash bootstrap.sh
bash bootstrap.sh --force
bash bootstrap.sh --dry-run
```

Installs to `~/.claude/` and `~/.codex/` (or `$CLAUDE_HOME` / `$CODEX_HOME` if set):

```text
~/.claude/
├── skills/{init-project,sprint,run-agent,run-workflow}/SKILL.md
└── agent-setup/{VERSION,bin/,templates/}

~/.codex/
├── skills/{init-project,sprint,run-agent,run-workflow}/SKILL.md
└── agent-setup/{VERSION,bin/,templates/}
```

## Initialize A Project

Claude:

```bash
cd ~/your-project
claude
/init-project ./vision.md
```

Codex:

```text
cd ~/your-project
codex
$init-project ./vision.md
```

Important:

- Claude uses slash commands: `/init-project`, `/sprint`, `/run-agent`, `/run-workflow`
- Codex uses skills: `$init-project`, `$sprint`, `$run-agent`, `$run-workflow`

If you do not pass a vision file, `init-project` auto-generates `.project/vision.md` from detected context.

## Project Layout

```text
your-project/
├── AGENTS.md
├── .claude/
│   └── CLAUDE.md
├── .project/
│   ├── vision.md
│   ├── state.json
│   ├── decisions/
│   ├── designs/
│   ├── spikes/
│   ├── releases/
│   ├── sprints/
│   │   ├── backlog.md
│   │   └── sprint-001.md
│   └── workflows/
│       └── <run-id>/
│           ├── task.md
│           ├── 01-*.md
│           └── final-summary.md
└── agent-setup/
    ├── spec/
    │   └── engineering-standards.md
    ├── agents/
    │   ├── product-owner/
    │   ├── developer/
    │   ├── designer/
    │   ├── analyst/
    │   ├── qa-reviewer/
    │   ├── tech-lead/
    │   └── specialized/
    ├── workflows/
    │   ├── analyze-design-dev-review.md
    │   ├── bug-triage.md
    │   ├── spike-research.md
    │   └── release.md
    └── skills/
        ├── git-push-safe.md
        ├── lint-and-format.md
        ├── run-tests.md
        ├── create-pr.md
        └── dependency-audit.md
```

Rationale:

- `.project/` keeps product state, sprint state, and workflow-run artifacts together.
- `agent-setup/` keeps reusable operational definitions together.
- the project root stays cleaner.

## Execution Modes

### `sprint`

Use `sprint` when the task exists in `.project/sprints/sprint-NNN.md`.

```text
sprint <sprint-number>
sprint <sprint-number> <task-id>
sprint <sprint-number> <task-id> <workflow>
```

Examples in Claude:

```bash
/sprint 001
/sprint 001 US-001
/sprint 001 US-001 analyze-design-dev-review
```

Examples in Codex:

```text
$sprint 001
$sprint 001 US-001
```

Behavior:
- sprint-scoped
- workflow inferred from the sprint task, with optional explicit workflow override
- multi-agent orchestration when the workflow contains multiple agent stages
- handoff artifacts persisted under `.project/workflows/<run-id>/`
- sprint task checkboxes updated only after explicit acceptance verification

### `run-agent`

Use `run-agent` for an ad hoc task outside sprint files.

```text
run-agent <agent> [workflow] <task text>
```

Examples in Claude:

```bash
/run-agent developer analyze-design-dev-review "Fix checkout race condition"
/run-agent qa-reviewer "Review recent checkout changes for regressions"
```

Examples in Codex:

```text
$run-agent developer analyze-design-dev-review Fix checkout race condition
$run-agent qa-reviewer Review recent checkout changes for regressions
```

Behavior:
- ad hoc
- single-agent only
- optional workflow guidance
- no persisted multi-agent handoffs

### `run-workflow`

Use `run-workflow` for direct multi-agent orchestration outside the sprint entrypoint.

```text
run-workflow <workflow> <task-id|task-text>
```

Examples in Claude:

```bash
/run-workflow analyze-design-dev-review US-005
/run-workflow spike-research "Compare hosting options for the API"
```

Examples in Codex:

```text
$run-workflow analyze-design-dev-review US-005
$run-workflow spike-research Compare hosting options for the API
```

Behavior:
- staged multi-agent execution
- reads explicit workflow stages from `agent-setup/workflows/*.md`
- persists handoff artifacts under `.project/workflows/<run-id>/`
- updates workflow run state in `.project/state.json`
- stops on blocking stage failures

## Workflow Format

Workflow definitions are project-level files under `agent-setup/workflows/`.
Each stage must declare these fields explicitly:

- `Agent:`
- `Inputs:`
- `Outputs:`
- `Pass:`
- `OnFailure:`

This explicit format is required for both `sprint` and `run-workflow`. Prose-only workflow files are not orchestration-safe.

## Memory Protocol

Every agent, before substantial work:

1. Reads `AGENTS.md` or `.claude/CLAUDE.md`
2. Reads its own `agent-setup/agents/<role>/memory.md`
3. Reads `agent-setup/spec/engineering-standards.md`
4. Reads the relevant sprint file when the task is sprint-based
5. Reads prior `.project/workflows/<run-id>/` artifacts when the task is workflow-orchestrated

After acting, the agent appends a dated entry to its memory file.

## Updating

```bash
bash bootstrap.sh --force
```

## Uninstall

```bash
rm -rf ~/.claude/agent-setup ~/.claude/skills/init-project ~/.claude/skills/sprint ~/.claude/skills/run-agent ~/.claude/skills/run-workflow
rm -rf ~/.codex/agent-setup ~/.codex/skills/init-project ~/.codex/skills/sprint ~/.codex/skills/run-agent ~/.codex/skills/run-workflow
```
