<!-- generated-by: /init-project -->
<!-- vars: ROLE_TITLE, STACK, ARCHITECTURE_STYLE, TODAY_ISO -->
---
tags: [agent/memory, agent/{{ROLE_SLUG}}]
agent: "[[agents/{{ROLE_SLUG}}/agent]]"
parent: "[[_README]]"
---
# Memory — {{ROLE_TITLE}}

> Append-only journal. Most recent entry at the bottom.
> Every agent action writes here per the memory protocol in CLAUDE.md.
> **Compaction**: when entries exceed 20, collapse the oldest (keeping the last 10) into a `## Compacted summary — <date-range>` block at the top.

## Entry format
Each entry MUST include wikilinks back to the triggering context so a graph traversal recovers the full history:
```
## YYYY-MM-DD — <task-id or short title>
- **Context**: [[sprints/sprint-NNN#US-XXX]] · [[workflows/runs/<run-id>]] · stage [[workflows/runs/<run-id>/NN-<agent>]]
- **Did**: <what was done>
- **Why**: <reason>
- **Learned**: <insight>
- **Refactor debt cleared**: <touched file(s) + short summary>   <!-- omit if none -->
- **Open**: <unresolved questions, link to [[decisions/ADR-...]] or [[spikes/SPIKE-...]] if applicable>
```

## {{TODAY_ISO}} — init
- **Context**: project bootstrap (no sprint yet)
- **Did**: Initialised agent definition and empty memory.
- **Why**: Project bootstrap.
- **Learned**: Stack detected as {{STACK}}. Architecture: {{ARCHITECTURE_STYLE}}.
- **Open**: See `.project/state.json > clarifications_pending`.
