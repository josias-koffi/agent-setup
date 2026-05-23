#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# bootstrap.sh — Install the agent-setup framework globally for Claude Code and Codex CLI
#
# Run once (or any time you pull a newer version of this repo):
#   bash bootstrap.sh            # installs only if not at the latest version
#   bash bootstrap.sh --force    # back up current install, then reinstall
#   bash bootstrap.sh --dry-run  # print what would be done, no writes
#   bash bootstrap.sh --no-mcp   # skip the local CVE MCP server install
#
# After install, from ANY project directory:
#   claude / codex
#   init-project [optional: vision-file.md]
#   sprint 001 [task-id]
#   run-agent developer "Fix checkout race condition"
#   run-workflow analyze-design-dev-review US-001
#   push-to-github
#   create-pr
#   upgrade-project
#   migrate vault_path=/abs/path
#
# What gets installed (same files to both ~/.claude and ~/.codex):
#   skills/init-project/SKILL.md           — init-project skill
#   skills/sprint/SKILL.md                 — sprint skill
#   skills/run-agent/SKILL.md              — run-agent skill
#   skills/run-workflow/SKILL.md           — run-workflow skill
#   skills/upgrade-project/SKILL.md        — upgrade-project skill
#   skills/push-to-github/SKILL.md         — agnostic push skill (project overrides this)
#   skills/create-pr/SKILL.md              — create-pr skill
#   skills/documentation-from-commits/SKILL.md
#   skills/reload-projects/SKILL.md            — reload-projects skill
#   skills/migrate/SKILL.md                    — migrate to Obsidian vault
#   skills/design-critique/SKILL.md            — /critique command (Impeccable-backed design review)
#   agent-setup/VERSION                    — installed framework version
#   agent-setup/bin/render-templates.sh    — shell interpolation engine
#   agent-setup/templates/                 — every static template init-project copies
#
# Vendored MCP servers (shared across both runtimes):
#   $HOME/.agent-setup/vendor/cve-mcp-server/  — CVE MCP server (mukul975/cve-mcp-server)
#                                                cloned + pip-installed in a local venv
#   $HOME/.agent-setup/vendor/manifest.json    — paths consumed by init-project/upgrade-project
#
# Project-level skill overrides:
#   After running init-project in a project, stack-specific skills are installed to
#   .claude/skills/ and .codex/skills/ within the project directory. These take
#   precedence over the global agnostic skills above.
#
# Honours $CLAUDE_HOME and $CODEX_HOME for non-default locations.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DEST="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_DEST="${CODEX_HOME:-$HOME/.codex}"

FORCE=0
DRY_RUN=0
SKIP_MCP=0
for arg in "$@"; do
    case "$arg" in
        --force)   FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --no-mcp)  SKIP_MCP=1 ;;
        -h|--help)
            grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown arg: $arg" >&2; exit 1 ;;
    esac
done

MCP_VENDOR_DIR="${AGENT_SETUP_VENDOR:-$HOME/.agent-setup/vendor}"
CVE_MCP_REPO="https://github.com/mukul975/cve-mcp-server.git"
CVE_MCP_HOME="$MCP_VENDOR_DIR/cve-mcp-server"

run() {
    if [ "$DRY_RUN" = 1 ]; then
        printf '  [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

if [ ! -f "$SCRIPT_DIR/VERSION" ]; then
    echo "bootstrap: VERSION file missing at $SCRIPT_DIR/VERSION" >&2
    exit 1
fi
NEW_VERSION="$(tr -d '[:space:]' <"$SCRIPT_DIR/VERSION")"

# Source skill file -> installed global skill directory.
SKILL_MAPPINGS=(
    "skills/init.md:init-project"
    "skills/sprint.md:sprint"
    "skills/run-agent.md:run-agent"
    "skills/run-workflow.md:run-workflow"
    "skills/upgrade-project.md:upgrade-project"
    "skills/push-to-github.md:push-to-github"
    "skills/create-pr.md:create-pr"
    "skills/documentation-from-commits.md:documentation-from-commits"
    "skills/reload-projects.md:reload-projects"
    "skills/migrate.md:migrate"
    "skills/design-critique.md:design-critique"
)

for required in \
    templates \
    bin/render-templates.sh; do
    if [ ! -e "$SCRIPT_DIR/$required" ]; then
        echo "bootstrap: missing $SCRIPT_DIR/$required — repo looks incomplete" >&2
        exit 1
    fi
done

for mapping in "${SKILL_MAPPINGS[@]}"; do
    IFS=':' read -r source_skill _ <<<"$mapping"
    if [ ! -e "$SCRIPT_DIR/$source_skill" ]; then
        echo "bootstrap: missing $SCRIPT_DIR/$source_skill — repo looks incomplete" >&2
        exit 1
    fi
done

# Install all global skills from a single source file to both runtimes.
# $1 = cli name (for display)
# $2 = destination root (~/.claude or ~/.codex)
install_target() {
    local cli_name="$1"
    local dest="$2"
    local installed_version=""

    if [ -f "$dest/agent-setup/VERSION" ]; then
        installed_version="$(tr -d '[:space:]' <"$dest/agent-setup/VERSION")"
    fi

    if [ -n "$installed_version" ] && [ "$installed_version" = "$NEW_VERSION" ] && [ "$FORCE" -ne 1 ]; then
        echo "agent-setup $installed_version already installed for $cli_name at $dest/agent-setup."
        return 0
    fi

    if [ -d "$dest/agent-setup" ] && [ "$FORCE" = 1 ]; then
        local backup="$dest/agent-setup.bak.$(date +%Y%m%d%H%M%S)"
        echo "Backing up current $cli_name install → $backup"
        run mv "$dest/agent-setup" "$backup"
    fi

    run mkdir -p "$dest/agent-setup/bin" "$dest/agent-setup/templates"
    for mapping in "${SKILL_MAPPINGS[@]}"; do
        IFS=':' read -r _ skill_name <<<"$mapping"
        run mkdir -p "$dest/skills/$skill_name"
    done

    echo "Installing agent-setup $NEW_VERSION for $cli_name → $dest"

    run cp -r "$SCRIPT_DIR/templates/." "$dest/agent-setup/templates/"
    run cp "$SCRIPT_DIR/bin/render-templates.sh" "$dest/agent-setup/bin/render-templates.sh"
    run chmod +x "$dest/agent-setup/bin/render-templates.sh"
    run cp "$SCRIPT_DIR/VERSION" "$dest/agent-setup/VERSION"

    for mapping in "${SKILL_MAPPINGS[@]}"; do
        IFS=':' read -r source_skill skill_name <<<"$mapping"
        run cp "$SCRIPT_DIR/$source_skill" "$dest/skills/$skill_name/SKILL.md"
    done
}

install_target "Claude" "$CLAUDE_DEST"
install_target "Codex"  "$CODEX_DEST"

# Install CVE MCP server locally (default MCP for vulnerability/CVE lookups).
# Skipped with --no-mcp, or silently degraded when git/python3 are missing.
install_cve_mcp() {
    if [ "$SKIP_MCP" = 1 ]; then
        echo "Skipping CVE MCP install (--no-mcp)."
        return 0
    fi
    if ! command -v git >/dev/null 2>&1; then
        echo "CVE MCP: 'git' not found — skipping. Install git, then re-run bootstrap." >&2
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo "CVE MCP: 'python3' not found — skipping. Install Python 3.10+, then re-run bootstrap." >&2
        return 0
    fi

    run mkdir -p "$MCP_VENDOR_DIR"

    if [ -d "$CVE_MCP_HOME/.git" ]; then
        if [ "$FORCE" = 1 ]; then
            echo "Refreshing CVE MCP server → $CVE_MCP_HOME"
            run git -C "$CVE_MCP_HOME" fetch --quiet origin
            run git -C "$CVE_MCP_HOME" reset --hard origin/HEAD
        else
            echo "CVE MCP server already cloned at $CVE_MCP_HOME (use --force to refresh)."
        fi
    else
        echo "Cloning CVE MCP server → $CVE_MCP_HOME"
        run git clone --quiet --depth 1 "$CVE_MCP_REPO" "$CVE_MCP_HOME"
    fi

    if [ "$DRY_RUN" = 1 ]; then
        printf '  [dry-run] python3 -m venv %s/.venv\n' "$CVE_MCP_HOME"
        printf '  [dry-run] %s/.venv/bin/pip install -e %s\n' "$CVE_MCP_HOME" "$CVE_MCP_HOME"
        return 0
    fi

    if [ ! -x "$CVE_MCP_HOME/.venv/bin/python" ]; then
        echo "Creating venv at $CVE_MCP_HOME/.venv"
        python3 -m venv "$CVE_MCP_HOME/.venv"
    fi
    echo "Installing CVE MCP server dependencies (pip install -e .)"
    "$CVE_MCP_HOME/.venv/bin/pip" install --quiet --upgrade pip
    "$CVE_MCP_HOME/.venv/bin/pip" install --quiet -e "$CVE_MCP_HOME"

    # Manifest so init-project / upgrade-project can locate the install
    cat >"$MCP_VENDOR_DIR/manifest.json" <<EOF
{
  "cve_mcp_home": "$CVE_MCP_HOME",
  "cve_mcp_python": "$CVE_MCP_HOME/.venv/bin/python"
}
EOF
    echo "CVE MCP install complete."
}

install_cve_mcp

if [ "$DRY_RUN" = 1 ]; then
    echo
    echo "(dry-run — no changes written)"
    exit 0
fi

cat <<'BANNER'

─────────────────────────────────────────────────────────────
✅ agent-setup installed.

Global skills (agnostic, same files for Claude Code and Codex CLI):
  init-project, sprint, run-agent, run-workflow, upgrade-project
  push-to-github, create-pr, documentation-from-commits, reload-projects

Project-level overrides:
  After running init-project, stack-specific skills are installed to
  .claude/skills/ and .codex/skills/ inside the project — they take
  precedence over the global agnostic skills above.

USAGE
─────────────────────────────────────────────────────────────

  cd ~/your-project

  claude
  /init-project ./vision.md
  /sprint 001
  /run-agent developer "Fix checkout race condition"
  /run-workflow analyze-design-dev-review US-001
  /push-to-github
  /create-pr
  /upgrade-project

  codex
  $init-project ./vision.md
  $sprint 001
  $run-agent developer Fix checkout race condition
  $run-workflow analyze-design-dev-review US-001
  $push-to-github
  $create-pr
  $upgrade-project

Reinstall later:
  bash bootstrap.sh --force   # backs up each installed target, then overwrites
─────────────────────────────────────────────────────────────
BANNER
