#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# bootstrap.sh — Install the agent-setup framework globally for Claude Code and Codex CLI
#
# Run once (or any time you pull a newer version of this repo):
#   bash bootstrap.sh            # installs only if not at the latest version
#   bash bootstrap.sh --force    # back up current install, then reinstall
#   bash bootstrap.sh --dry-run  # print what would be done, no writes
#
# After install, from ANY project directory:
#   claude
#   /init [optional: vision-file.md]   # initialises .claude/, AGENTS.md, .project/, agents/, …
#   /sprint 001 developer analyze-design-dev-review US-001
#
#   codex
#   Use the global `init` skill in a project directory
#   Use the global `sprint` skill after initialisation
#
# What gets installed:
#   ~/.claude/skills/init/SKILL.md           — Claude /init skill
#   ~/.claude/skills/sprint/SKILL.md         — Claude /sprint skill
#   ~/.codex/skills/init/SKILL.md            — Codex init skill
#   ~/.codex/skills/sprint/SKILL.md          — Codex sprint skill
#   ~/.claude/agent-setup/VERSION            — Claude-installed framework version
#   ~/.codex/agent-setup/VERSION             — Codex-installed framework version
#   ~/.claude/agent-setup/bin/
#   ~/.codex/agent-setup/bin/
#     render-templates.sh                    — shell interpolation engine
#   ~/.claude/agent-setup/templates/         — every static template /init copies
#   ~/.codex/agent-setup/templates/          — every static template Codex skills use
#
# `/init` detects stack + context and calls render-templates.sh once to produce
# all project files. Static boilerplate never enters the LLM context.
#
# Honours $CLAUDE_HOME and $CODEX_HOME for non-default locations.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DEST="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_DEST="${CODEX_HOME:-$HOME/.codex}"

FORCE=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --force)   FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown arg: $arg" >&2; exit 1 ;;
    esac
done

run() {
    if [ "$DRY_RUN" = 1 ]; then
        printf '  [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# ─── Read new version from the repo ──────────────────────────────────────────
if [ ! -f "$SCRIPT_DIR/VERSION" ]; then
    echo "bootstrap: VERSION file missing at $SCRIPT_DIR/VERSION" >&2
    exit 1
fi
NEW_VERSION="$(tr -d '[:space:]' <"$SCRIPT_DIR/VERSION")"

# ─── Sanity check repo layout ────────────────────────────────────────────────
for required in templates bin/render-templates.sh skills/init.md skills/sprint.md skills/init.codex.md skills/sprint.codex.md; do
    if [ ! -e "$SCRIPT_DIR/$required" ]; then
        echo "bootstrap: missing $SCRIPT_DIR/$required — repo looks incomplete" >&2
        exit 1
    fi
done

install_target() {
    local cli_name="$1"
    local dest="$2"
    local init_skill_src="$3"
    local sprint_skill_src="$4"
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
    run mkdir -p "$dest/skills/init" "$dest/skills/sprint"

    echo "Installing agent-setup $NEW_VERSION for $cli_name → $dest"

    run cp -r "$SCRIPT_DIR/templates/." "$dest/agent-setup/templates/"
    run cp "$SCRIPT_DIR/bin/render-templates.sh" "$dest/agent-setup/bin/render-templates.sh"
    run chmod +x "$dest/agent-setup/bin/render-templates.sh"
    run cp "$SCRIPT_DIR/VERSION" "$dest/agent-setup/VERSION"

    run cp "$SCRIPT_DIR/$init_skill_src" "$dest/skills/init/SKILL.md"
    run cp "$SCRIPT_DIR/$sprint_skill_src" "$dest/skills/sprint/SKILL.md"
}

install_target "Claude" "$CLAUDE_DEST" "skills/init.md" "skills/sprint.md"
install_target "Codex" "$CODEX_DEST" "skills/init.codex.md" "skills/sprint.codex.md"

# ─── Banner ──────────────────────────────────────────────────────────────────
if [ "$DRY_RUN" = 1 ]; then
    echo
    echo "(dry-run — no changes written)"
    exit 0
fi

cat <<BANNER

─────────────────────────────────────────────────────────────
✅ agent-setup $NEW_VERSION installed.

Installed under:
  $CLAUDE_DEST/skills/init/SKILL.md   (Claude /init)
  $CLAUDE_DEST/skills/sprint/SKILL.md (Claude /sprint)
  $CLAUDE_DEST/agent-setup/           (Claude framework payload)
  $CODEX_DEST/skills/init/SKILL.md    (Codex init skill)
  $CODEX_DEST/skills/sprint/SKILL.md  (Codex sprint skill)
  $CODEX_DEST/agent-setup/            (Codex framework payload)

USAGE
─────────────────────────────────────────────────────────────

  cd ~/your-project
  claude

  # Greenfield project (with vision file):
  /init ./vision.md

  # Existing project (auto-detects stack, auto-generates vision stub):
  /init

  # Run sprints from any project initialised by /init:
  /sprint 001 developer  analyze-design-dev-review US-001
  /sprint 001 developer  analyze-design-dev-review all
  /sprint 001 qa-reviewer analyze-design-dev-review US-001
  /sprint 001 tech-lead  release all

  # Or from Codex CLI, use the installed `init` and `sprint` skills
  codex

Reinstall later:
  bash bootstrap.sh --force   # backs up each installed target, then overwrites
─────────────────────────────────────────────────────────────
BANNER
