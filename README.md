# Multi-Agent Project Orchestrator for Claude Code and Codex CLI

A two-layer system with dual CLI support:

- **`bootstrap.sh`** — a one-time global install. Copies templates, a shell renderer, and two skills into both `~/.claude/` and `~/.codex/`. Runs in pure bash.
- **`init` / `/init`** — a thin per-project command. Detects stack + context, invokes the shell renderer, and produces a full multi-agent project structure for both Claude and Codex entrypoints.

Every project initialised with `/init` gets:

- **6 base agents** (product-owner, developer, designer, analyst, qa-reviewer, tech-lead), each with its own memory file
- **4 workflows** (analyze-design-dev-review, bug-triage, spike-research, release)
- **5 skills** (git-push-safe, lint-and-format, run-tests, create-pr, dependency-audit) adapted to the detected stack
- **Engineering spec** — Clean Architecture, 80% test coverage, Conventional Commits, trunk-based branching, ADRs, WCAG AA, OWASP baseline, structured observability
- **Project memory** — `CLAUDE.md` + per-agent `memory.md` journals
- **Blocking vs advisory enforcement** — tests/security/coverage are blocking; style is advisory
- **Global sprint skill/command** to run any agent + workflow against a task

## Install (once)

```bash
bash bootstrap.sh                 # install or upgrade
bash bootstrap.sh --force         # reinstall (backs up current templates)
bash bootstrap.sh --dry-run       # print actions without writing
```

Installs to `~/.claude/` and `~/.codex/` (or `$CLAUDE_HOME` / `$CODEX_HOME` if set):

```
~/.claude/
├── skills/{init,sprint}/SKILL.md
└── agent-setup/{VERSION,bin/,templates/}

~/.codex/
├── skills/{init,sprint}/SKILL.md
└── agent-setup/{VERSION,bin/,templates/}
```

## Use

```bash
cd ~/your-project
claude

# Greenfield with a vision file:
/init ./vision.md

# Existing codebase — auto-detects stack, auto-generates vision stub from README:
/init

# Re-run safely at any time — the renderer skips files that already exist.
```

After `/init` completes, `/sprint` is already available (installed globally by `bootstrap.sh`):

```bash
/sprint 001 developer    analyze-design-dev-review US-001
/sprint 001 developer    analyze-design-dev-review all
/sprint 001 qa-reviewer  analyze-design-dev-review US-001
/sprint 001 tech-lead    release all
```

Codex CLI can use the same generated project with:

```text
init [optional vision path]
sprint 001 developer analyze-design-dev-review US-001
```

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

Old model (single mega-skill): `/init` loaded ~900 lines of inline templates into context and re-typed every file. Slow, expensive, error-prone.

New model: `bootstrap.sh` installs templates as plain files under each CLI home. `/init` only does the work that requires judgment: stack detection, vision-stub enrichment, and clarifications. All static generation is delegated to `bin/render-templates.sh`, which reads templates, substitutes `{{VARS}}`, and writes output files.

## Anti-hallucination guarantees

- Every generated task, epic, user story, and specialised agent cites the vision: `(source: vision §<section>)`
- Missing information becomes `⚠️ TO CLARIFY: <question>` — never invented
- Vision file is copied verbatim, never summarised
- Sprints are capped at 3–8 real tasks, never padded
- Files have a `<!-- generated-by: /init -->` marker; the renderer refuses to overwrite existing files

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
rm -rf ~/.claude/agent-setup ~/.claude/skills/init ~/.claude/skills/sprint
rm -rf ~/.codex/agent-setup ~/.codex/skills/init ~/.codex/skills/sprint
```
