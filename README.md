# Multi-Agent Project Orchestrator for Claude Code and Codex CLI

A two-layer system with dual CLI support:

- `bootstrap.sh` installs the reusable framework globally into `~/.claude/` and `~/.codex/`.
- `init-project` initializes one specific repository by generating a local project workspace around your vision file.
- `sprint` is the sprint-scoped entrypoint and follows the workflow declared by each sprint task.
- `run-agent` runs an ad hoc task as a single-agent execution.
- `run-workflow` orchestrates a staged multi-agent workflow directly, outside the sprint entrypoint. Accepts a pre-built workflow name or a dynamic agent chain.
- `upgrade-project` safely migrates previously initialized projects to the latest generated format.
- `reload-projects` probes repos registered in `state.json.repos`, auto-fills missing metadata, and syncs the repos list to every sibling project.
- `migrate` moves all project knowledge artifacts (vision, sprints, agents, workflows, spec) from the repo into a centralized Obsidian vault, leaving only `state.json` and `.claude/` in the repo.

## Install Once

```bash
bash bootstrap.sh
bash bootstrap.sh --force     # back up current install, then reinstall
bash bootstrap.sh --dry-run   # print what would happen, no writes
bash bootstrap.sh --no-mcp    # skip the local CVE MCP server install
```

Installs to `~/.claude/` and `~/.codex/` (or `$CLAUDE_HOME` / `$CODEX_HOME` if set):

```text
~/.claude/
├── skills/{init-project,sprint,run-agent,run-workflow,upgrade-project,reload-projects,migrate}/SKILL.md
└── agent-setup/{VERSION,bin/,templates/}

~/.codex/
├── skills/{init-project,sprint,run-agent,run-workflow,upgrade-project,reload-projects,migrate}/SKILL.md
└── agent-setup/{VERSION,bin/,templates/}

~/.agent-setup/
└── vendor/
    ├── cve-mcp-server/          # cloned + pip-installed in a local venv
    └── manifest.json            # paths consumed by render-templates.sh
```

`bootstrap.sh` additionally clones [`mukul975/cve-mcp-server`](https://github.com/mukul975/cve-mcp-server) into `~/.agent-setup/vendor/cve-mcp-server/`, creates a Python venv inside it, and runs `pip install -e .`. Requires `git` and `python3` ≥ 3.10. If either is missing, bootstrap continues with a warning. Pass `--no-mcp` to skip.

## Default MCP Servers

Every project initialized by `init-project` (≥ v1.9.0) gets two MCP servers wired automatically, mirrored across both runtimes:

| File | Runtime | Servers |
|------|---------|---------|
| `.mcp.json` | Claude Code | `context7`, `cve-mcp` |
| `.codex/config.toml` | Codex CLI (project-local, trusted projects only) | `context7`, `cve-mcp` |

**`context7`** — up-to-date library/framework documentation via [`@upstash/context7-mcp`](https://github.com/upstash/context7). Spawned with `npx -y` (no install). Optional env var `CONTEXT7_API_KEY` for higher rate limits ([dashboard](https://context7.com/dashboard)).

**`cve-mcp`** — 27 security tools across 21 APIs ([`mukul975/cve-mcp-server`](https://github.com/mukul975/cve-mcp-server)): CVE lookup, EPSS scoring, CISA KEV, MITRE ATT&CK, OSV.dev dependency scan, GitHub Security Advisories, Shodan, VirusTotal, AbuseIPDB, GreyNoise, urlscan. Vendored at `~/.agent-setup/vendor/cve-mcp-server/` by `bootstrap.sh`. Works without API keys; set any of these env vars for higher quotas: `NVD_API_KEY`, `GITHUB_TOKEN`, `ABUSEIPDB_KEY`, `GREYNOISE_API_KEY`, `SHODAN_KEY`.

### How it runs

MCP servers are **not daemons**. They are started on demand by the CLI:

1. `cd ~/your-project && claude` (or `codex`)
2. The CLI reads `.mcp.json` / `.codex/config.toml` and forks a stdio sub-process per server
3. The servers stay connected for the lifetime of the CLI session — Claude/Codex calls their tools as needed
4. When the session ends, the sub-processes are killed

No auto-start on reboot is needed; no port is opened; nothing runs in the background between sessions.

### Example usage

Inside a Claude or Codex session, the model picks tools automatically. You can also force them:

```text
Use context7 to fetch the latest fastapi docs and tell me the recommended dependency pattern in 0.115.
Use cve-mcp to scan requirements.txt and list the top 5 vulnerable packages by EPSS score.
Use cve-mcp to check whether CVE-2024-3094 (xz-utils) affects any package in our lockfile.
```

### Skipping or removing

- Install without CVE MCP: `bash bootstrap.sh --no-mcp` → then delete the `cve-mcp` block from each project's `.mcp.json` and `.codex/config.toml`.
- Refresh the CVE MCP install (pull latest + reinstall deps): `bash bootstrap.sh --force`.
- Override install location: `AGENT_SETUP_VENDOR=/custom/path bash bootstrap.sh`.

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

- Claude uses slash commands: `/init-project`, `/sprint`, `/run-agent`, `/run-workflow`, `/upgrade-project`, `/reload-projects`, `/migrate`
- Codex uses skills: `$init-project`, `$sprint`, `$run-agent`, `$run-workflow`, `$upgrade-project`, `$reload-projects`, `$migrate`

If you do not pass a vision file, `init-project` auto-generates the vision from detected context.

**Obsidian vault mode**: pass `vault_path=/abs/path` to store all knowledge files (agents, workflows, sprints, vision) in an Obsidian vault instead of the repo:
```bash
/init-project ./vision.md vault_path=~/my-vault
```

Important: `init-project` does not overwrite existing generated files. Use `upgrade-project` to migrate older initialized projects.

## Obsidian Vault (centralized knowledge)

All project knowledge files (vision, sprints, agents, workflows, spec, decisions) can live in a shared Obsidian vault instead of each repo. Only `.project/state.json` and `.claude/` stay in the repo.

### New project with vault

```bash
/init-project ./vision.md vault_path=~/my-vault
```

The vault is created if it does not exist. A `<project-name>/` folder is created inside.

### Migrate existing project to vault

```bash
/migrate vault_path=~/my-vault
```

Migrates `.project/` and `agent-setup/` content to the vault. Shows a preview and asks for confirmation before moving any files. Creates a backup in `.project/upgrades/<timestamp>/`.

### Vault structure

```text
~/my-vault/
├── .obsidian/app.json
├── _index.md                  # all projects index
└── <project-name>/
    ├── _README.md             # wikilinks overview
    ├── vision.md
    ├── spec/engineering-standards.md
    ├── agents/<role>/{agent.md,memory.md}
    ├── workflows/definitions/  # workflow definitions
    ├── workflows/runs/         # execution artifacts
    ├── sprints/{backlog.md,sprint-NNN.md}
    ├── decisions/
    ├── designs/
    ├── spikes/
    └── releases/
```

All skills (`sprint`, `run-agent`, `run-workflow`) automatically resolve paths through `vault_project_path` stored in `.project/state.json`.

## Multi-Repo Projects

A product often spans multiple repositories — a backend API, a frontend app, a mobile app, shared libraries. The framework supports this through a `repos` registry in `.project/state.json`.

### Register repos

After running `init-project`, open `.project/state.json` and add an entry for each sibling repo. Only `path` is required:

```json
"repos": [
  { "path": "/absolute/path/to/backend" },
  { "path": "/absolute/path/to/frontend" },
  { "path": "/absolute/path/to/mobile" }
]
```

Then run `/reload-projects` to auto-detect and fill the remaining fields:

```bash
/reload-projects
```

Claude reads each repo's manifest (`package.json`, `Cargo.toml`, `go.mod`, etc.) and writes back:

```json
"repos": [
  {
    "path": "/absolute/path/to/backend",
    "name": "my-api",
    "stack": "go",
    "description": "REST API and auth service",
    "role": "backend"
  },
  {
    "path": "/absolute/path/to/frontend",
    "name": "my-dashboard",
    "stack": "node",
    "description": "React dashboard",
    "role": "frontend"
  }
]
```

The updated `repos` array is automatically synced to every sibling repo's `.project/state.json`, so all projects always carry the full picture.

### How agents use repos

Every `sprint`, `run-workflow`, and `run-agent` call automatically injects a compact repos block into the task context:

```
## Available Repositories (2)
- backend [go] my-api at /path/to/backend — REST API and auth service
- frontend [node] my-dashboard at /path/to/frontend — React dashboard
```

The **developer agent** uses the absolute paths to navigate and modify files across repos. It declares which repos it changed in its output artifact.

### Cross-repo sprint tasks

When a feature requires work in multiple repos, the **product owner** creates one task per affected repo, each in that repo's own sprint file. Use the optional `Repos:` and `Depends-on:` fields:

```markdown
# backend/.project/sprints/sprint-001.md
### US-005 — Add health check endpoint
**Priority**: High
**Workflow**: developer-qa-reviewer
**Repos**: backend
**Acceptance Criteria**:
- [ ] GET /health returns 200 with status payload
```

```markdown
# frontend/.project/sprints/sprint-001.md
### US-006 — Integrate health check in dashboard
**Priority**: High
**Workflow**: developer-qa-reviewer
**Repos**: frontend
**Depends-on**: backend/US-005
**Acceptance Criteria**:
- [ ] Dashboard polls /health and displays status
```

Developers in each repo run `/sprint 001` independently and in parallel. When `Depends-on:` is set, the sprint runner warns (but does not block) if the referenced task is not yet complete.

### `reload-projects`

Use `reload-projects` any time you add a new repo path or want to force a re-sync:

```bash
/reload-projects      # Claude
$reload-projects      # Codex
```

It skips repos that already have all fields populated (idempotent) and reports a sync table showing which sibling projects were updated.

> **Tip**: `reload-projects` is also triggered automatically inside `sprint`, `run-workflow`, and `run-agent` whenever it finds a repo entry with missing fields — so you never have to run it manually if you forget.

## Project Layout

```text
your-project/
├── AGENTS.md
├── .mcp.json                    # MCP servers for Claude Code (context7, cve-mcp)
├── .claude/
│   └── CLAUDE.md
├── .codex/
│   └── config.toml              # MCP servers for Codex CLI (mirror of .mcp.json)
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
bash bootstrap.sh --force        # refreshes framework + pulls latest CVE MCP and reinstalls its venv
```

For older initialized projects (adds `.mcp.json` and `.codex/config.toml` when missing, with confirmation if they already exist):

```bash
/upgrade-project        # Claude
$upgrade-project        # Codex
```

## Uninstall

```bash
rm -rf ~/.claude/agent-setup ~/.claude/skills/{init-project,sprint,run-agent,run-workflow,upgrade-project,reload-projects,migrate,push-to-github,create-pr,documentation-from-commits}
rm -rf ~/.codex/agent-setup  ~/.codex/skills/{init-project,sprint,run-agent,run-workflow,upgrade-project,reload-projects,migrate,push-to-github,create-pr,documentation-from-commits}
rm -rf ~/.agent-setup    # vendored MCP servers (CVE MCP clone + venv)
```

## Changelog Highlights

- **v1.9.0** — `bootstrap.sh` now installs the **CVE MCP server** locally (`mukul975/cve-mcp-server`) into `~/.agent-setup/vendor/cve-mcp-server/` with its own Python venv. `init-project` generates `.mcp.json` and `.codex/config.toml` wiring both `context7` and `cve-mcp` automatically. New flag: `bash bootstrap.sh --no-mcp`.
- **v1.8.0** — Default MCP servers framework: shared templates `.mcp.json` (Claude) + `.codex/config.toml` (Codex), Context7 by default.
- **v1.7.0** — Active refactoring promoted to core engineering principle (`spec/engineering-standards.md §9`). Developer/QA agent templates updated.
- **v1.6.0** — Obsidian-aware skills: `migrate` skill, vault-mode workflows.
- **v1.5.0** — Obsidian vault integration (`vault_path=` arg on `init-project`).
