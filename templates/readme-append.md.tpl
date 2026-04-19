<!-- generated-by: /init-project -->
## Multi-Agent Workflow

This project uses an agent-driven workflow. See:
- `.claude/CLAUDE.md` — entry point for Claude Code sessions
- `AGENTS.md` — entry point for Codex CLI sessions
- `agent-setup/spec/engineering-standards.md` — non-negotiable engineering rules
- `agent-setup/agents/<role>/` — agent definitions and memory
- `agent-setup/workflows/` — named workflow definitions
- `.project/sprints/` — backlog and sprint files
- `.project/workflows/` — persisted workflow-run artifacts and handoffs

Run sprint-scoped orchestration:
```text
/sprint 001
/sprint 001 US-001
```

Run direct workflow orchestration:
```text
/run-workflow analyze-design-dev-review US-001
```
