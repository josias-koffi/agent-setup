#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# render-templates.sh — copy and interpolate agent-setup templates into a project
#
# Usage:
#   env PROJECT_NAME=foo STACK=node LINT_CMD='npm run lint' ... \
#       render-templates.sh /path/to/project
#
# Vault mode (Obsidian):
#   Set VAULT_PATH and VAULT_PROJECT_PATH to render agents/workflows/spec/sprints
#   into the vault instead of the project repo. Only .project/state.json,
#   .claude/, AGENTS.md, and .codex/ are written to the project root in vault mode.
#
# Template source: the installed framework root next to this script, or
# ${AGENT_SETUP_HOME}/agent-setup/templates when explicitly provided.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUT_DIR="${1:-}"
if [ -z "$OUT_DIR" ]; then
    echo "usage: render-templates.sh <out-dir>" >&2
    exit 1
fi
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

AGENT_SETUP_HOME="${AGENT_SETUP_HOME:-}"
if [ -n "$AGENT_SETUP_HOME" ]; then
    TPL_ROOT="$AGENT_SETUP_HOME/agent-setup/templates"
else
    TPL_ROOT="$FRAMEWORK_ROOT/templates"
fi

if [ ! -d "$TPL_ROOT" ]; then
    echo "render-templates: template dir not found: $TPL_ROOT" >&2
    echo "render-templates: run bootstrap.sh first" >&2
    exit 2
fi

# ── Vault mode detection ─────────────────────────────────────────────────────
VAULT_PATH="${VAULT_PATH:-}"
VAULT_PROJECT_PATH="${VAULT_PROJECT_PATH:-}"
VAULT_MODE="false"
if [ -n "$VAULT_PATH" ] && [ -n "$VAULT_PROJECT_PATH" ]; then
    VAULT_MODE="true"
fi

# Compute derived path variables used in templates
if [ "$VAULT_MODE" = "true" ]; then
    VISION_PATH="${VAULT_PROJECT_PATH}/vision.md"
    SPEC_PATH="${VAULT_PROJECT_PATH}/spec/engineering-standards.md"
    AGENTS_DIR="${VAULT_PROJECT_PATH}/agents"
    WORKFLOWS_DEF_DIR="${VAULT_PROJECT_PATH}/workflows/definitions"
    WORKFLOWS_RUNS_DIR="${VAULT_PROJECT_PATH}/workflows/runs"
    SPRINTS_DIR="${VAULT_PROJECT_PATH}/sprints"
else
    VISION_PATH=".project/vision.md"
    SPEC_PATH="agent-setup/spec/engineering-standards.md"
    AGENTS_DIR="agent-setup/agents"
    WORKFLOWS_DEF_DIR="agent-setup/workflows"
    WORKFLOWS_RUNS_DIR=".project/workflows"
    SPRINTS_DIR=".project/sprints"
fi
export VISION_PATH SPEC_PATH AGENTS_DIR WORKFLOWS_DEF_DIR WORKFLOWS_RUNS_DIR SPRINTS_DIR

REQUIRED_VARS=(
    PROJECT_NAME PROJECT_TYPE STACK STACK_DETAILS ARCHITECTURE_STYLE
    LINT_CMD FORMAT_CMD TEST_CMD BUILD_CMD DEV_CMD AUDIT_CMD
    COVERAGE_TOOL CI_STATUS LINTERS TODAY_ISO TODAY_PLUS_14
    VISION_MODE DETECTED_FEATURES_BLOCK CLARIFICATIONS_JSON_ARRAY
    VISION_PATH SPEC_PATH AGENTS_DIR WORKFLOWS_DEF_DIR WORKFLOWS_RUNS_DIR SPRINTS_DIR
)
ROLE_VARS=(ROLE_NAME ROLE_TITLE ROLE_SLUG)
VAULT_VARS=(VAULT_PATH VAULT_PROJECT_PATH)
VARS=("${REQUIRED_VARS[@]}" "${ROLE_VARS[@]}" "${VAULT_VARS[@]}")

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

# ── Render helpers ────────────────────────────────────────────────────────────

render_to() {
    local base_dir="$1" tpl="$2" target="$3"
    local target_abs="$base_dir/$target"

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
            continue
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

render_one() {
    render_to "$OUT_DIR" "$1" "$2"
}

render_vault_one() {
    render_to "$VAULT_PROJECT_PATH" "$1" "$2"
}

render_obsidian_one() {
    render_to "$VAULT_PATH" "$1" "$2"
}

# ── Always render to repo ────────────────────────────────────────────────────

render_one "$TPL_ROOT/claude/CLAUDE.md.tpl"     ".claude/CLAUDE.md"
render_one "$TPL_ROOT/claude/settings.json.tpl" ".claude/settings.json"
render_one "$TPL_ROOT/codex/AGENTS.md.tpl"       "AGENTS.md"
render_one "$TPL_ROOT/project/state.json.tpl"    ".project/state.json"

# ── Vault mode: render content files into vault ──────────────────────────────

if [ "$VAULT_MODE" = "true" ]; then
    # Bootstrap vault structure if needed
    if [ ! -f "$VAULT_PATH/.obsidian/app.json" ]; then
        render_obsidian_one "$TPL_ROOT/obsidian/app.json.tpl" ".obsidian/app.json"
    fi
    if [ ! -f "$VAULT_PATH/_index.md" ]; then
        render_obsidian_one "$TPL_ROOT/obsidian/_index.md.tpl" "_index.md"
    else
        # Append project link to vault index if not already listed
        if ! grep -q "{{PROJECT_NAME}}" "$VAULT_PATH/_index.md" 2>/dev/null && \
           ! grep -q "$PROJECT_NAME" "$VAULT_PATH/_index.md" 2>/dev/null; then
            echo "- [[$PROJECT_NAME/_README|$PROJECT_NAME]]" >> "$VAULT_PATH/_index.md"
            echo "UPDATED: _index.md (added $PROJECT_NAME)"
        fi
    fi

    render_vault_one "$TPL_ROOT/obsidian/_README.md.tpl"          "_README.md"
    render_vault_one "$TPL_ROOT/obsidian/_MOC_Sprints.md.tpl"     "_MOC_Sprints.md"
    render_vault_one "$TPL_ROOT/obsidian/_MOC_Workflows.md.tpl"   "_MOC_Workflows.md"
    render_vault_one "$TPL_ROOT/obsidian/_MOC_Decisions.md.tpl"   "_MOC_Decisions.md"
    render_vault_one "$TPL_ROOT/obsidian/_MOC_Agents.md.tpl"      "_MOC_Agents.md"
    render_vault_one "$TPL_ROOT/spec/engineering-standards.md.tpl" "spec/engineering-standards.md"
    render_vault_one "$TPL_ROOT/sprints/backlog.md.tpl"            "sprints/backlog.md"
    render_vault_one "$TPL_ROOT/sprints/sprint-001.md.tpl"         "sprints/sprint-001.md"

    if [ "${VISION_MODE:-}" = "auto-stub" ]; then
        render_vault_one "$TPL_ROOT/project/vision.auto-stub.md.tpl" "vision.md"
    fi

    for tpl in "$TPL_ROOT/workflows/"*.md.tpl; do
        [ -f "$tpl" ] || continue
        base="$(basename "$tpl" .tpl)"
        render_vault_one "$tpl" "workflows/definitions/$base"
    done

    for tpl in "$TPL_ROOT/skills/"*.md.tpl; do
        [ -f "$tpl" ] || continue
        base="$(basename "$tpl" .tpl)"
        render_one "$tpl" "agent-setup/skills/$base"
    done

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
        export ROLE_SLUG="$role"
        ROLE_TITLE="$(role_title_for "$role")"
        export ROLE_TITLE
        render_vault_one "$TPL_ROOT/agents/$role.agent.md.tpl" "agents/$role/agent.md"
        render_vault_one "$TPL_ROOT/agents/_memory.md.tpl"     "agents/$role/memory.md"
    done

    mkdir -p "$VAULT_PROJECT_PATH/"{decisions,designs,spikes,releases,workflows/runs}
    mkdir -p "$VAULT_PROJECT_PATH/agents/specialized"
    mkdir -p "$OUT_DIR/.project"

# ── Legacy mode: render everything into repo ─────────────────────────────────

else
    render_one "$TPL_ROOT/spec/engineering-standards.md.tpl" "agent-setup/spec/engineering-standards.md"
    render_one "$TPL_ROOT/sprints/backlog.md.tpl"            ".project/sprints/backlog.md"
    render_one "$TPL_ROOT/sprints/sprint-001.md.tpl"         ".project/sprints/sprint-001.md"

    if [ "${VISION_MODE:-}" = "auto-stub" ]; then
        render_one "$TPL_ROOT/project/vision.auto-stub.md.tpl" ".project/vision.md"
    fi

    for tpl in "$TPL_ROOT/workflows/"*.md.tpl; do
        [ -f "$tpl" ] || continue
        base="$(basename "$tpl" .tpl)"
        render_one "$tpl" "agent-setup/workflows/$base"
    done

    for tpl in "$TPL_ROOT/skills/"*.md.tpl; do
        [ -f "$tpl" ] || continue
        base="$(basename "$tpl" .tpl)"
        render_one "$tpl" "agent-setup/skills/$base"
    done

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
        export ROLE_SLUG="$role"
        ROLE_TITLE="$(role_title_for "$role")"
        export ROLE_TITLE
        render_one "$TPL_ROOT/agents/$role.agent.md.tpl" "agent-setup/agents/$role/agent.md"
        render_one "$TPL_ROOT/agents/_memory.md.tpl"     "agent-setup/agents/$role/memory.md"
    done

    mkdir -p "$OUT_DIR/agent-setup/agents/specialized"
    mkdir -p "$OUT_DIR/.project/"{decisions,designs,spikes,releases,sprints,workflows}
fi

echo "render-templates: done"
