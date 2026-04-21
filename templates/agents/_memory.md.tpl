<!-- generated-by: /init-project -->
<!-- vars: ROLE_TITLE, STACK, ARCHITECTURE_STYLE, TODAY_ISO -->
# Memory — {{ROLE_TITLE}}

> Append-only journal. Most recent entry at the bottom.
> Every agent action writes here per the memory protocol in CLAUDE.md.
> **Compaction**: when entries exceed 20, collapse the oldest (keeping the last 10) into a `## Compacted summary — <date-range>` block at the top.

## {{TODAY_ISO}} — init
- **Did**: Initialised agent definition and empty memory.
- **Why**: Project bootstrap.
- **Learned**: Stack detected as {{STACK}}. Architecture: {{ARCHITECTURE_STYLE}}.
- **Open**: See `.project/state.json > clarifications_pending`.
