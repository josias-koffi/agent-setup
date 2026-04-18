#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# render-templates.sh — copy and interpolate agent-setup templates into a project
#
# Usage:
#   env PROJECT_NAME=foo STACK=node LINT_CMD='npm run lint' ... \
#       render-templates.sh /path/to/project
#
# Template source: ${CLAUDE_HOME:-$HOME/.claude}/agent-setup/templates/
# Writes files into the given OUT_DIR, skipping any that already exist.
#
# Exit codes:
#   0  success
#   1  usage error
#   2  template source missing
#   3  unresolved {{VAR}} placeholders
#   4  write failure
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

OUT_DIR="${1:-}"
if [ -z "$OUT_DIR" ]; then
    echo "usage: render-templates.sh <out-dir>" >&2
    exit 1
fi
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
TPL_ROOT="$CLAUDE_HOME/agent-setup/templates"

if [ ! -d "$TPL_ROOT" ]; then
    echo "render-templates: template dir not found: $TPL_ROOT" >&2
    echo "render-templates: run bootstrap.sh first" >&2
    exit 2
fi

# Required vars — must be set by caller before invocation.
# (Unset = exit 3 up-front; empty string is allowed but surfaces as empty in output.)
REQUIRED_VARS=(
    PROJECT_NAME PROJECT_TYPE STACK STACK_DETAILS ARCHITECTURE_STYLE
    LINT_CMD FORMAT_CMD TEST_CMD BUILD_CMD DEV_CMD AUDIT_CMD
    COVERAGE_TOOL CI_STATUS LINTERS TODAY_ISO TODAY_PLUS_14
    VISION_MODE DETECTED_FEATURES_BLOCK CLARIFICATIONS_JSON_ARRAY
)

# Role-scoped vars are set inside the agent loop, not by the caller.
ROLE_VARS=(ROLE_NAME ROLE_TITLE)

# All substitutable vars (checked for leftover {{VAR}} after rendering).
VARS=("${REQUIRED_VARS[@]}" "${ROLE_VARS[@]}")

missing=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var+x}" ]; then
        missing+=("$var")
    fi
done
if [ ${#missing[@]} -gt 0 ]; then
    echo "render-templates: missing required env vars: ${missing[*]}" >&2
    exit 3
fi

render_one() {
    local tpl="$1" target="$2"
    local target_abs="$OUT_DIR/$target"

    if [ -e "$target_abs" ]; then
        echo "SKIP: $target (exists)"
        return 0
    fi

    mkdir -p "$(dirname "$target_abs")" || return 4

    if [ ! -f "$tpl" ]; then
        echo "render-templates: template missing: $tpl" >&2
        return 2
    fi

    local content
    content="$(cat "$tpl")"

    local var val
    for var in "${VARS[@]}"; do
        if [ -z "${!var+x}" ]; then
            continue  # ROLE_* unset outside agent loop — fine
        fi
        val="${!var}"
        content="${content//"{{$var}}"/$val}"
    done

    if grep -qE '\{\{[A-Z_]+\}\}' <<<"$content"; then
        echo "UNRESOLVED placeholders in $target:" >&2
        grep -oE '\{\{[A-Z_]+\}\}' <<<"$content" | sort -u >&2
        return 3
    fi

    printf '%s\n' "$content" >"$target_abs" || return 4
    echo "WROTE: $target"
}

# ─── 1:1 mappings ────────────────────────────────────────────────────────────
render_one "$TPL_ROOT/claude/CLAUDE.md.tpl"                ".claude/CLAUDE.md"
render_one "$TPL_ROOT/project/state.json.tpl"              ".project/state.json"
render_one "$TPL_ROOT/spec/engineering-standards.md.tpl"   "spec/engineering-standards.md"
render_one "$TPL_ROOT/sprints/backlog.md.tpl"              "sprints/backlog.md"
render_one "$TPL_ROOT/sprints/sprint-001.md.tpl"           "sprints/sprint-001.md"

# ─── Vision auto-stub (only when /init decided we need one) ──────────────────
if [ "${VISION_MODE:-}" = "auto-stub" ]; then
    render_one "$TPL_ROOT/project/vision.auto-stub.md.tpl" ".project/vision.md"
fi

# ─── Workflows (glob all) ────────────────────────────────────────────────────
for tpl in "$TPL_ROOT/workflows/"*.md.tpl; do
    [ -f "$tpl" ] || continue
    base="$(basename "$tpl" .tpl)"
    render_one "$tpl" "workflows/$base"
done

# ─── Skills (glob all) ───────────────────────────────────────────────────────
for tpl in "$TPL_ROOT/skills/"*.md.tpl; do
    [ -f "$tpl" ] || continue
    base="$(basename "$tpl" .tpl)"
    render_one "$tpl" "skills/$base"
done

# ─── Agents: 6 roles × (agent.md + memory.md) ────────────────────────────────
ROLES=(product-owner developer designer analyst qa-reviewer tech-lead)
role_title_for() {
    case "$1" in
        product-owner) echo "Product Owner" ;;
        developer)     echo "Developer" ;;
        designer)      echo "Designer" ;;
        analyst)       echo "Analyst" ;;
        qa-reviewer)   echo "QA Reviewer" ;;
        tech-lead)     echo "Tech Lead" ;;
    esac
}

for role in "${ROLES[@]}"; do
    export ROLE_NAME="$role"
    ROLE_TITLE="$(role_title_for "$role")"
    export ROLE_TITLE
    render_one "$TPL_ROOT/agents/$role.agent.md.tpl" "agents/$role/agent.md"
    render_one "$TPL_ROOT/agents/_memory.md.tpl"     "agents/$role/memory.md"
done

# Create the specialized/ placeholder directory (no template inside).
mkdir -p "$OUT_DIR/agents/specialized"
mkdir -p "$OUT_DIR/.project/"{decisions,designs,spikes,releases}

echo "render-templates: done"
