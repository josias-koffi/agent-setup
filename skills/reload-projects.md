---
name: reload-projects
description: >
  Probes all repos registered in state.json.repos that have missing metadata fields, auto-detects name/stack/description/role from each repo's manifest, writes the results back to state.json, and syncs the updated repos array to every sibling repo's state.json. Run this after manually adding a new {"path": "..."} entry to the repos array.
allowed-tools: Read, Write, Bash(ls:*), Bash(test:*)
---

# reload-projects — Multi-Repo Discovery and Sync

## Purpose

`reload-projects` iterates over every entry in `.project/state.json > repos`, probes repos that have missing metadata, writes the detected fields back, then syncs the complete `repos` array to every sibling repo that is also an agent-setup project.

Run this command after adding a new repo path to `state.json.repos`:
```json
"repos": [
  {"path": "/absolute/path/to/new-repo"}
]
```

## Arguments

None. Operates on all repos listed in `.project/state.json > repos`.

## Strict sequence

### 1. Load state

Read `.project/state.json`. Extract the `repos` array.

If `repos` is empty or missing, report "No repos registered. Add entries to state.json.repos and re-run." and stop.

### 2. Probe unconfigured repos

For each repo entry where any of `name`, `stack`, `description`, or `role` is `null`:

**2.1 Verify path**
Check that the `path` exists and is a directory. If not, record it as failed and continue to the next entry — do not stop the whole run.

**2.2 Read manifest**
Read the first manifest file found at `path` in this priority order:
- `package.json` → stack: `node`, name from `name`, description from `description`
- `Cargo.toml` → stack: `rust`, name from `[package].name`, description from `[package].description`
- `go.mod` → stack: `go`, name from module path (last segment), description: read first non-blank line of `README.md`
- `composer.json` → stack: `php`, name from `name` (after `/`), description from `description`
- `pyproject.toml` → stack: `python`, name from `[project].name` or `[tool.poetry.name]`, description from `[project].description`
- `requirements.txt` → stack: `python`, name from dirname, description: read first non-blank line of `README.md`

If no manifest is found, set `stack: unknown`, `name` to dirname, `description: null`.

**2.3 Detect role**
Infer `role` from the repo name and description using these keywords:
- `frontend` — keywords: front, ui, web, dashboard, app, client, react, vue, angular, next, svelte
- `backend` — keywords: back, api, server, service, rest, graphql, grpc, gateway
- `mobile` — keywords: mobile, ios, android, react-native, flutter, expo
- `lib` — keywords: lib, library, sdk, package, core, shared, common, utils
- `infra` — keywords: infra, deploy, terraform, k8s, kubernetes, docker, helm, ops, devops, ci

If no keyword matches, set `role: lib` as default.

**2.4 Write back**
Update only the `null` fields in the repo entry. Never overwrite fields the user has already set. Write the updated `state.json`.

### 3. Sync to sibling repos

After all probing is complete, take the final `repos` array from the current `state.json` and write it to every sibling:
- For each repo entry (including the current project itself if listed), check whether `<path>/.project/state.json` exists
- If it does: read that file, replace only its `repos` field with the updated array, write it back
- If it does not: skip silently (not an agent-setup project)
- Do not modify any other field in the sibling's `state.json`

### 4. Report

Print a summary table:

```
repo discovery results
======================
REPO       PATH                        STATUS    name          stack    role
--------   --------------------------  --------  ------------  -------  ---------
api        /home/user/projects/api     updated   my-api        go       backend
web        /home/user/projects/web     updated   my-dashboard  node     frontend
mobile     /home/user/projects/mobile  skipped   (all fields already set)
/bad/path  /bad/path                   failed    (path does not exist)

sync results
============
- /home/user/projects/api/.project/state.json  → synced
- /home/user/projects/web/.project/state.json  → synced
- /home/user/projects/other                    → skipped (no .project/state.json)
```

## Hard rules

- Never overwrite a field that already has a non-null value
- Never modify any state.json field other than `repos`
- Never stop the full run because a single repo path is invalid — report and continue
- Idempotent: running twice produces identical results
