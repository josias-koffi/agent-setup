---
name: documentation-from-commits
version: 1.0.0
description: >
  Create and maintain high-quality technical documentation from Git commit history for a
  day or custom period. Trigger on: "generate docs from commits", "update architecture
  docs", "document what changed", "create changelog", "technical documentation from git
  history", "update the docs", "write docs for today's changes", "produce a period report",
  "document this sprint". Use when teams need architecture-level docs (entities, modules,
  flows, API contracts, operations) with controlled updates that modify only sections
  impacted by changes in the selected period.
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
---

# documentation-from-commits

## Goal
Produce technical documentation that is architecture-focused and auditable, not only a narrative changelog.

## Workflow
1. Ensure `docs/` exists (create it if missing).
2. Resolve period:
   - Default: current day
   - Custom: user-provided `since` / `until`
3. Collect commits and changed files in period.
4. Build an impact map: changed paths → documentation sections impacted.
5. Create missing technical docs baseline if absent.
6. Update only impacted sections in existing docs.
7. Keep unchanged sections untouched to preserve clean diffs.

## Required Documentation Set
Maintain these files under `docs/`:
- `docs/architecture.md`
- `docs/domain-model.md`
- `docs/api-contract.md`
- `docs/quality-and-operations.md`
- `docs/changelog/reports/_template.md` (canonical template for period reports)
- `docs/changelog/` reports (`daily` or period)
- `docs/README.md` index

## Technical Structure Requirements

### `docs/architecture.md`
- System context and boundaries
- Module/package structure
- Runtime components and interactions
- Data flow and integration points

### `docs/domain-model.md`
- Entities and responsibilities
- Enums and domain constraints
- Relationships and cardinalities
- Persistence/migration notes

### `docs/api-contract.md`
- Exposed resources/endpoints
- Filters, identifiers, pagination, formats
- Security/access rules
- Breaking change notes

### `docs/quality-and-operations.md`
- Test strategy and evidence
- Static analysis/linting status
- Environment/runtime assumptions
- Risks, mitigations, and monitoring points

### `docs/changelog/*`
- Period summary
- Traceability to commits
- Scope and impacted modules

### `docs/changelog/reports/_template.md`
Must exist and remain stable as the canonical report skeleton. Required sections:
- Summary
- Architecture and Runtime
- Domain Model Changes
- API and Tests
- Quality Gates and Fixes
- Risks and Follow-ups
- Traceability

## Impact-Based Update Rules
Use changed files to decide what to update:
- `src/Entity/*`, `src/Enum/*`, `migrations/*` → `domain-model.md`
- `src/Filter/*`, API resource metadata/config routes → `api-contract.md`
- `docker/*`, runtime configs, infra scripts → `architecture.md` and `quality-and-operations.md`
- test/config quality files → `quality-and-operations.md`

Rules:
- If a section is not impacted by period changes: do not rewrite it.
- If no meaningful code/config change in period: only update changelog (or no-op if requested).
- For each new period report, create from `_template.md` and fill only impacted sections.

## Data Collection Commands
- Commit list:
  ```
  git log --since='<since>' --until='<until>' --pretty=format:'%H|%ad|%an|%s' --date=iso
  ```
- Commit details and file impact:
  ```
  git show --name-status --pretty=format:'%H|%ad|%an|%s%n%b' --date=iso <sha>
  ```

## Standards
- Professional technical writing, concise and precise.
- Strong section hierarchy and stable headings.
- Clear fact/assumption separation.
- Traceability (commit refs, command evidence when available).
- Idempotent updates and minimal diffs.

## Failure Handling
Stop only when blocked by invalid period input or missing repository history/data.
