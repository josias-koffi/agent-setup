---
name: push-to-github
version: 1.0.0
description: >
  Stage, commit, and push repository changes with quality gates. Trigger on: "push code",
  "commit and push", "push to GitHub", "ship changes", "push my work", "push to origin".
  Auto-detects the project stack and runs the appropriate gates (lint, tests, static
  analysis). Fix failures automatically when possible. Push only when every gate passes.
  Project-level overrides in agent-setup/skills/push-to-github.md replace this skill with
  a stack-specific version.
allowed-tools: Bash, Read, Glob, Grep
---

# push-to-github

## Workflow
1. Inspect Git state: `git status --short`, `git diff --name-only`, `git rev-parse --abbrev-ref HEAD`.
2. If branch is `main` or `master`, stop and request a feature branch unless user explicitly wants a direct push.
3. Detect the project stack (see Stack Detection below).
4. Group changed files into coherent commits by concern using Conventional Commits.
5. Run the pre-commit gate if `.pre-commit-config.yaml` exists: `pre-commit run --all-files`.
6. Run the stack-specific quality gates (see Stack Gates below).
7. Run the design gate if applicable (see Design Gate below).
8. On any gate failure: read the error, implement targeted fixes, retry the failing gate. Continue until pass or true blocker.
9. Create grouped Conventional Commits (`git add <files>` + `git commit -m "type(scope): summary"`).
10. Re-run all gates after committing.
11. Push: `git push origin <current-branch>`.

## Stack Detection
Detect in this order (first match wins):

| Signal | Stack |
|--------|-------|
| `composer.json` with Symfony package | PHP/Symfony |
| `turbo.json` or `package.json` with `next` dep | Next.js/Node monorepo |
| `package.json` without Next.js | Node/JS |
| `pyproject.toml` or `setup.py` or `requirements.txt` | Python |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `Makefile` or `justfile` only | Generic |

## Stack Gates

### PHP/Symfony
- `pre-commit run --all-files`
- `just test` (or `php bin/phpunit` if no justfile)
- `./vendor/bin/phpstan analyse -c phpstan.dist.neon` (if phpstan present)

### Next.js / Node monorepo
- `pre-commit run --all-files`
- `npm run check`
- `npm run check-types`
- `npm run build`
- `npm run test --workspaces --if-present` (skip if no test scripts detected)

### Node / JS
- `pre-commit run --all-files`
- `npm run lint` (if script exists)
- `npm test` (if script exists)
- `npm run build` (if script exists)

### Python
- `pre-commit run --all-files`
- `ruff check .` (if ruff present)
- `mypy .` (if mypy present)
- `pytest` (if pytest present)

### Go
- `pre-commit run --all-files`
- `go vet ./...`
- `go test ./...`

### Rust
- `pre-commit run --all-files`
- `cargo clippy -- -D warnings`
- `cargo test`

### Generic fallback
Run in order, skipping those not present:
- `pre-commit run --all-files`
- `make test` / `just test`
- `npm test`
- `pytest`
- `go test ./...`

## Design Gate

Run only when **all** of these are true:
- `npx impeccable detect --version` exits 0 (Impeccable is installed in the project)
- The changeset contains at least one file matching `*.tsx`, `*.vue`, `*.jsx`, `*.html`, `*.css`, or `*.scss`

```bash
npx impeccable detect
```

| Severity | Behaviour |
|---|---|
| `[critical]` finding | Block push — report exact findings, suggest `/impeccable` fix commands |
| `[warning]` finding | Report but do not block — append to push summary |
| No Impeccable installed | Skip silently |
| No UI files in changeset | Skip silently |

## Commit Rules
- Conventional Commit format: `type(scope): summary`
- Types: `feat`, `fix`, `docs`, `refactor`, `style`, `test`, `chore`, `ci`, `perf`, `build`, `revert`
- Scope must match `[a-zA-Z0-9-_]+` — no slashes
- **Never amend existing commits.** Always create new commits.
- Never use `--no-verify` or other hook-bypass flags.
- Pass commit messages via heredoc:
  ```
  git commit -m "$(cat <<'EOF'
  type(scope): summary
  EOF
  )"
  ```

## Auto-Resolution Policy
- On any gate failure, read the error output, implement targeted fixes, then re-run only the failing gate.
- Continue iterating until all gates pass or a true blocker is reached.
- True blockers: missing credentials, unavailable infrastructure, non-installable runtime deps, repeated non-deterministic failure after 3 retries.
- Never bypass hooks or skip gates to force a passing state.

## Failure Report Format
When blocked, return:
- Failing command
- Key error lines
- Fixes attempted
- Why unresolved
- Exact user action required

## Execution Checklist
- `git status --short`
- `git diff --name-only`
- `git rev-parse --abbrev-ref HEAD`
- Stack detection
- Pre-commit gate (if configured)
- Stack-specific quality gates (fix + retry until pass or blocker)
- Grouped commits
- Final full gate rerun
- `git push origin <current-branch>`
