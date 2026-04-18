# Multi-Agent Project Orchestrator for Claude Code

A single `/init` command that bootstraps any project — greenfield or existing — with:

- **6 base agents** (product-owner, developer, designer, analyst, qa-reviewer, tech-lead), each with its own memory file
- **4 workflows** (analyze-design-dev-review, bug-triage, spike-research, release)
- **5 skills** (git-push-safe, lint-and-format, run-tests, create-pr, dependency-audit) adapted to your detected stack
- **Engineering spec** enforcing Clean Architecture, 80% test coverage, Conventional Commits, trunk-based branching, ADRs, WCAG AA, OWASP baseline, and structured observability
- **Project memory** in `CLAUDE.md` + per-agent `memory.md` journals
- **Blocking vs advisory enforcement** — tests/security/coverage are blocking; style is advisory
- **Project-local `/sprint` command** for running agent + workflow on a task

## Install

```bash
bash bootstrap.sh
```

One skill file goes to `~/.claude/skills/init/SKILL.md`. That's it.

## Use

```bash
cd ~/your-project
claude

# Greenfield with a vision file:
/init ./vision.md

# Existing codebase — auto-detects stack, auto-generates vision stub from README:
/init

# Re-run safely at any time — idempotent, preserves your edits.
```

After `/init` completes:

```bash
# Run the developer agent on a task using a workflow
/sprint 001 developer analyze-design-dev-review US-001

# Run all sprint tasks
/sprint 001 developer analyze-design-dev-review all

# QA review pass
/sprint 001 qa-reviewer analyze-design-dev-review US-001

# Release gate
/sprint 001 tech-lead release all
```

## What gets created

```
your-project/
├── .claude/
│   ├── CLAUDE.md                         # auto-loaded every session
│   └── skills/sprint/SKILL.md            # /sprint command, project-local
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

## Anti-hallucination guarantees

- Every generated task, epic, user story, and specialised agent cites the vision: `(source: vision §<section>)`
- Missing information becomes `⚠️ TO CLARIFY: <question>` — never invented
- Vision file is copied verbatim, never summarised
- Sprints are capped at 3–8 real tasks, never padded
- Files are marked with `<!-- generated-by: /init -->` so re-running preserves your edits

## Memory protocol

Every agent, before acting:
1. Reads `.claude/CLAUDE.md`
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
