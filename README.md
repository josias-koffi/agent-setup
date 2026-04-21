# Multi-Agent Project Orchestrator for Claude Code and Codex CLI

A two-layer system with dual CLI support:

- `bootstrap.sh` installs the reusable framework globally into `~/.claude/` and `~/.codex/`.
- `init-project` initializes one specific repository by generating a local project workspace around your vision file.
- `sprint` is the sprint-scoped entrypoint and follows the workflow declared by each sprint task.
- `run-agent` runs an ad hoc task as a single-agent execution.
- `run-workflow` orchestrates a staged multi-agent workflow directly, outside the sprint entrypoint. Accepts a pre-built workflow name or a dynamic agent chain.
- `upgrade-project` safely migrates previously initialized projects to the latest generated format.

## Install Once

```bash
bash bootstrap.sh
bash bootstrap.sh --force
bash bootstrap.sh --dry-run
```

Installs to `~/.claude/` and `~/.codex/` (or `$CLAUDE_HOME` / `$CODEX_HOME` if set):

```text
~/.claude/
├── skills/{init-project,sprint,run-agent,run-workflow,upgrade-project}/SKILL.md
└── agent-setup/{VERSION,bin/,templates/}

~/.codex/
├── skills/{init-project,sprint,run-agent,run-workflow,upgrade-project}/SKILL.md
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

- Claude uses slash commands: `/init-project`, `/sprint`, `/run-agent`, `/run-workflow`, `/upgrade-project`
- Codex uses skills: `$init-project`, `$sprint`, `$run-agent`, `$run-workflow`, `$upgrade-project`

If you do not pass a vision file, `init-project` auto-generates `.project/vision.md` from detected context.

Important: `init-project` does not overwrite existing generated files. Use `upgrade-project` to migrate older initialized projects.

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
sprint <sprint-number> <task-id> <workflow-or-chain>
```

Examples in Claude:

```bash
/sprint 001
/sprint 001 US-001
/sprint 001 US-001 analyze-design-dev-review
/sprint 001 US-001 developer-qa-reviewer-tech-lead
```

Examples in Codex:

```text
$sprint 001
$sprint 001 US-001
$sprint 001 US-001 developer-qa-reviewer
```

Behavior:
- sprint-scoped
- workflow inferred from the sprint task `Workflow:` field, with optional explicit override
- `Workflow:` can be a pre-built file name or a dynamic agent chain (e.g. `analyst-tech-lead`)
- multi-agent orchestration with handoff artifacts persisted under `.project/workflows/<run-id>/`
- sprint task checkboxes updated only after explicit acceptance verification

### `run-agent`

Use `run-agent` for an ad hoc task outside sprint files.

```text
run-agent <agent> <task text>
```

Examples in Claude:

```bash
/run-agent developer "Fix checkout race condition"
/run-agent qa-reviewer "Review recent checkout changes for regressions"
```

Examples in Codex:

```text
$run-agent developer Fix checkout race condition
$run-agent qa-reviewer Review recent checkout changes for regressions
```

Behavior:
- ad hoc
- single-agent only
- no workflow argument
- no persisted multi-agent handoffs

### `upgrade-project`

Use `upgrade-project` for repositories already initialized by an older framework version.

```text
upgrade-project
```

Examples in Claude:

```bash
/upgrade-project
```

Examples in Codex:

```text
$upgrade-project
```

Behavior:
- preview-first migration
- targets only core generated files
- creates dated backups under `.project/upgrades/<timestamp>/` before overwrite
- updates workflows, session entry docs, state fields, and the generated README block when needed
- asks before replacing ambiguous or user-modified files

### `run-workflow`

Use `run-workflow` for direct multi-agent orchestration outside the sprint entrypoint.

```text
run-workflow <workflow-or-chain> <task-id|task-text>
```

Examples in Claude:

```bash
/run-workflow analyze-design-dev-review US-005
/run-workflow analyze-design-dev-review "fix auth error when using social auth"
/run-workflow spike-research "Compare hosting options for the API"
/run-workflow developer-qa-reviewer US-012
/run-workflow analyst-tech-lead-developer "spike on caching strategy"
```

Examples in Codex:

```text
$run-workflow analyze-design-dev-review US-005
$run-workflow developer-qa-reviewer fix checkout race condition
$run-workflow analyst-tech-lead spike on caching strategy
```

Behavior:
- staged multi-agent execution
- accepts either a sprint task ID or a free-form task text
- first argument is resolved as a **pre-built workflow file** or a **dynamic agent chain** (see Workflow Format)
- persists handoff artifacts under `.project/workflows/<run-id>/`
- updates workflow run state in `.project/state.json`
- stops on blocking stage failures

## Workflow Format

### Pre-built workflows

Static workflow definitions live at `agent-setup/workflows/<name>.md`.
Each stage must declare these fields explicitly:

- `Agent:`
- `Inputs:`
- `Outputs:`
- `Pass:`
- `OnFailure:`

This explicit format is required for both `sprint` and `run-workflow`. Prose-only workflow files are not orchestration-safe.

### Dynamic agent chains

Instead of a pre-built workflow file, pass a hyphen-separated list of agent names:

```text
agent1-agent2-agentN
```

The orchestrator resolves each segment to `agent-setup/agents/<segment>/agent.md` and constructs stages at runtime. Each stage writes `NN-<agentname>.md` and the next agent reads all prior artifacts before acting.

```text
developer-qa-reviewer             → 2-stage chain
analyst-tech-lead-developer       → 3-stage chain
product-owner-designer-developer-qa-reviewer  → 4-stage chain
```

The run directory is named `<chain>-<timestamp>` for traceability. There is no limit on chain length. Any combination of the built-in agents (`product-owner`, `developer`, `designer`, `analyst`, `qa-reviewer`, `tech-lead`) and any specialized agents added under `agent-setup/agents/specialized/` can be used.

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

For older initialized projects:

```bash
/upgrade-project
```

or in Codex:

```text
$upgrade-project
```

## Uninstall

```bash
rm -rf ~/.claude/agent-setup ~/.claude/skills/init-project ~/.claude/skills/sprint ~/.claude/skills/run-agent ~/.claude/skills/run-workflow ~/.claude/skills/upgrade-project
rm -rf ~/.codex/agent-setup ~/.codex/skills/init-project ~/.codex/skills/sprint ~/.codex/skills/run-agent ~/.codex/skills/run-workflow ~/.codex/skills/upgrade-project
```
