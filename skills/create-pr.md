---
name: create-pr
version: 1.0.0
description: >
  Prepare and open a GitHub pull request end to end. Trigger on: "create PR", "open PR",
  "make a PR", "push and open a PR", "ship this as a PR", "draft a pull request". Detects
  the base branch, ensures the branch is pushed via the push-to-github skill, then creates
  the PR with a structured body. Works on any stack — project-level push-to-github handles
  stack-specific gates.
allowed-tools: Bash, Read, Glob, Grep
---

# create-pr

## Purpose
End-to-end PR preparation: branch hygiene, push with quality gates, and a high-quality PR body.
Push gates are delegated to the `push-to-github` skill — this skill does not re-implement them.

## Workflow (in order — do not skip)

### 1. Inspect repository state
Run in parallel:
- `git rev-parse --abbrev-ref HEAD` — current branch
- `git status --short` — pending changes
- `git remote get-url origin` — origin presence
- `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'` — default branch
- `git fetch origin --prune` — refresh remote refs

Abort if:
- No origin remote → ask user to set one.
- Working tree clean AND branch already matches `origin/<branch>` → nothing to PR.

### 2. Determine the base branch
Priority:
1. User-specified base.
2. Repo default from `origin/HEAD`.
3. Prefer `develop` over `main`/`master` if it exists (GitFlow repos).

Verify base exists: `git rev-parse --verify origin/<base>`. Abort if not.

### 3. Classify the change
Heuristics (first match wins):
- New file implementing new capability → `feat`
- Diff only touches tests → `test`
- Diff only touches docs/markdown → `docs`
- Diff only touches config/CI → `fix` or `chore`
- Removing/renaming without behavior change → `refactor`
- Small correction of existing behavior → `fix`
- Mixed: pick dominant type, note secondary in PR body

### 4. Branch hygiene
- **Protected branches** (`main`, `master`, `develop`, `release/*`): must NOT push directly — create a feature branch.
- **Active feature branch** (`feat/`, `fix/`, `chore/`, `refactor/`, `docs/`, `test/`): stay on it.
- New branch name: `<type>/<short-kebab-summary>` — under 60 chars.

### 5. Push via push-to-github skill
Follow the full `push-to-github` skill workflow: run all quality gates, create commits, and push the branch. Wait for the push to succeed before proceeding. If it reports a blocker, stop and surface it.

### 6. Build the PR body

#### Discover template
Check in order:
1. `.github/pull_request_template.md`
2. `.github/PULL_REQUEST_TEMPLATE.md`
3. `.github/PULL_REQUEST_TEMPLATE/*.md`
4. `docs/pull_request_template.md`
5. Root `pull_request_template.md`

Fill each section from the actual diff. Never invent content.

#### No template — structured default
```markdown
## Summary
<one-line recap>

## Changes
<bullet per commit: git log --format='- %s' origin/<base>..HEAD>

## Diff vs `<base>`
<git diff --stat output, max 20 files>

## Test plan
- [ ] Quality gates passed (delegated to push-to-github)
- [ ] Manual smoke of affected area
```

### 7. Compute PR title
Format: `type(scope): short summary` — imperative, lowercase, ≤60 chars.
If single commit on branch, use its subject verbatim.

### 8. Create the PR
```
gh pr create \
  --base <base> \
  --head <current-branch> \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body>
EOF
)"
```
Add `--draft` if user indicated WIP/draft.
Capture and return the PR URL.

### 9. Report
- PR URL
- Title and base→head
- Template used (path or "default")
- Gates delegated to push-to-github
- Any warnings

## Required rules
- Never amend existing commits.
- Never use `--no-verify`.
- Never force-push to a protected branch.
- Never push directly to `main`/`master`/`develop`.
- PR body must reflect the actual diff — no speculative content.

## Failure handling
Stop when:
- push-to-github reports an unresolved blocker (repeat verbatim).
- `gh` is not authenticated → ask user to run `gh auth login`.
- Base branch cannot be determined and user has not provided one.
- An open PR already exists → return the existing URL (`gh pr list --head <branch> --json url --jq '.[0].url'`).
