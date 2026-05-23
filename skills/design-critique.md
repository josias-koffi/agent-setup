---
name: design-critique
version: 1.0.0
description: >
  Run a structured Impeccable design critique on a target file or URL. Trigger on:
  "/critique", "critique this design", "audit the UI", "review this interface",
  "check for anti-patterns", "design feedback". Uses Impeccable's 29-rule anti-pattern
  scanner plus persona-based critique. Outputs a structured Verdict/Findings/Next-action
  report aligned with the designer agent format.
allowed-tools: Bash, Read, Glob, Grep
---

# design-critique

## Purpose

Run an Impeccable-backed critique on a design file, a running page, or component source
code, then return a structured report the designer agent can act on directly.

## Trigger phrases

- `/critique [target]`
- "critique this design"
- "audit the UI"
- "check for anti-patterns"
- "design feedback on <file or URL>"

## Workflow

### Step 1 — Load design context

Load in order (skip silently if file absent):

1. `PRODUCT.md` — brand voice, target audience, anti-references
2. `DESIGN.md` — spec, tokens, component constraints

If neither file exists, note `⚠️ No Impeccable context files found. Run /impeccable teach first.`
and continue with generic design principles.

### Step 2 — Identify the target

- If `$ARGUMENTS` contains a file path → use that file as the target.
- If `$ARGUMENTS` contains a URL → use that URL.
- Otherwise → scan for the most recently modified file matching
  `.project/designs/*.md` or common UI paths (`src/**/*.tsx`, `src/**/*.vue`,
  `templates/**/*.html`, `app/**/*.jsx`). Pick the most recent one and confirm
  with the user before proceeding.

### Step 3 — Anti-pattern scan (deterministic)

If Impeccable CLI is available (`npx impeccable detect --version` exits 0):

```bash
npx impeccable detect <target>
```

Capture output. Map each flagged rule to a severity:
- Rules tagged `[critical]` → `[BLOCKING]`
- Rules tagged `[warning]` → `[ADVISORY]`

If CLI is not available, skip this step and note `ℹ️ Install Impeccable for deterministic
scan: npx skills add pbakaus/impeccable`

### Step 4 — Qualitative critique

Using the loaded `PRODUCT.md` / `DESIGN.md` context, evaluate the target against:

| Axis | Key questions |
|---|---|
| **Hierarchy** | Is the visual weight guiding the eye correctly? |
| **Typography** | Scale, line-height, contrast — does it follow the spec? |
| **Color** | Consistent with the palette? Any low-contrast pairs? |
| **Spacing** | Is spacing rhythmic and intentional, not arbitrary? |
| **WCAG 2.1 AA** | Contrast ≥ 4.5:1 (text), ≥ 3:1 (UI), keyboard path, alt text |
| **Anti-patterns** | Purple gradients, nested cards, icon-only actions, decoration-as-content |
| **Brand alignment** | Does it match the voice and audience from `PRODUCT.md`? |

### Step 5 — Produce the report

Output the following structure (omit empty sections):

```
### Verdict: [PASS|FAIL|BLOCKED]
### Summary (≤ 100 words)
<what the critique found overall>
### Findings
- [BLOCKING] <specific issue — location + rule>
- [ADVISORY] <specific issue — location + rule>
### Impeccable commands to apply
- `/impeccable <command>` — <what it fixes>
### Next action
<one sentence>
```

Map Impeccable commands to findings:

| Finding type | Suggested command |
|---|---|
| Typography issues | `/impeccable typeset` |
| Color / contrast | `/impeccable colorize` |
| Spacing / layout | `/impeccable layout` |
| Feels flat / generic | `/impeccable delight` |
| Too heavy visually | `/impeccable quieter` |
| Too weak visually | `/impeccable bolder` |
| General polish | `/impeccable polish` |
| Animation needed | `/impeccable animate` |

## Failure modes

- **Target not found**: report the search paths checked, stop.
- **Impeccable CLI failure**: include stderr in the Findings as `[ADVISORY]`, continue
  with qualitative critique.
- **No design context**: complete the critique with generic principles, flag missing
  `PRODUCT.md` / `DESIGN.md` in Next action.
