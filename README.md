# Multi-Agent Project Orchestrator for Claude Code and Codex CLI

A two-layer system with dual CLI support:

- `bootstrap.sh` installs the reusable framework globally into `~/.claude/` and `~/.codex/`.
- `init-project` initializes one specific repository by generating a local project workspace around your vision file.
- `sprint` runs an agent on a sprint task.
- `run-agent` runs an agent on an ad hoc task, with or without a workflow.

## Install Once

```bash
bash bootstrap.sh
bash bootstrap.sh --force
bash bootstrap.sh --dry-run
```

Installs to `~/.claude/` and `~/.codex/` (or `$CLAUDE_HOME` / `$CODEX_HOME` if set):

```text
~/.claude/
├── skills/{init-project,sprint,run-agent}/SKILL.md
└── agent-setup/{VERSION,bin/,templates/}

~/.codex/
├── skills/{init-project,sprint,run-agent}/SKILL.md
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

- Claude uses slash commands: `/init-project`, `/sprint`, `/run-agent`
- Codex uses skills: `$init-project`, `$sprint`, `$run-agent`

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
│   └── sprints/
│       ├── backlog.md
│       └── sprint-001.md
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

- `.project/` keeps product/project state together, including sprints.
- `agent-setup/` groups the operational workspace generated for agents.
- the project root stays cleaner.

## Run A Sprint Task

Use `sprint` when the task exists in `.project/sprints/sprint-NNN.md`.

```text
sprint <sprint-number> <agent> <workflow> <task-id|all>
```

Claude examples:

```bash
/sprint 001 developer analyze-design-dev-review US-001
/sprint 001 qa-reviewer analyze-design-dev-review US-001
/sprint 001 developer analyze-design-dev-review all
```

Codex example:

```text
$sprint 001 developer analyze-design-dev-review US-001
```

## Run An Ad Hoc Task Outside Sprints

Use `run-agent` when the task is not tied to `.project/sprints/sprint-NNN.md`.

```text
run-agent <agent> [workflow] <task text>
```

With a workflow:

Claude:

```bash
/run-agent developer analyze-design-dev-review "Fix checkout race condition"
/run-agent analyst spike-research "Compare SSO providers for B2B customers"
```

Codex:

```text
$run-agent developer analyze-design-dev-review Fix checkout race condition
```

Without a workflow:

Claude:

```bash
/run-agent qa-reviewer "Review recent checkout changes for regressions"
```

Codex:

```text
$run-agent qa-reviewer Review recent checkout changes for regressions
```

`run-agent` loads the same project context as `sprint`, but it does not require a sprint number, does not require a task ID, and does not update sprint files.

## Memory Protocol

Every agent, before acting:

1. Reads `AGENTS.md` or `.claude/CLAUDE.md`
2. Reads its own `agent-setup/agents/<role>/memory.md`
3. Reads `agent-setup/spec/engineering-standards.md`
4. Reads the relevant sprint file under `.project/sprints/` when the task is sprint-based

After acting, the agent appends a dated entry to its memory file.

## Updating

```bash
bash bootstrap.sh --force
```

## Uninstall

```bash
rm -rf ~/.claude/agent-setup ~/.claude/skills/init-project ~/.claude/skills/sprint ~/.claude/skills/run-agent
rm -rf ~/.codex/agent-setup ~/.codex/skills/init-project ~/.codex/skills/sprint ~/.codex/skills/run-agent
```
