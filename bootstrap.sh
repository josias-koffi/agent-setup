#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# bootstrap.sh — Install the agent-setup framework globally for Claude Code
#
# Run once (or any time you pull a newer version of this repo):
#   bash bootstrap.sh            # installs only if not at the latest version
#   bash bootstrap.sh --force    # back up current install, then reinstall
#   bash bootstrap.sh --dry-run  # print what would be done, no writes
#
# After install, from ANY project directory:
#   claude
#   /init [optional: vision-file.md]   # initialises .claude/, .project/, agents/, …
#   /sprint 001 developer analyze-design-dev-review US-001
#
# What gets installed:
#   ~/.claude/skills/init/SKILL.md           — thin orchestrator (/init command)
#   ~/.claude/skills/sprint/SKILL.md         — global /sprint command
#   ~/.claude/agent-setup/VERSION            — installed version
#   ~/.claude/agent-setup/bin/
#     render-templates.sh                    — shell interpolation engine
#   ~/.claude/agent-setup/templates/         — every static template /init copies
#
# `/init` detects stack + context and calls render-templates.sh once to produce
# all project files. Static boilerplate never enters the LLM context.
#
# Honours $CLAUDE_HOME for non-default locations.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"

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

# ─── Compare with installed version ──────────────────────────────────────────
INSTALLED_VERSION=""
if [ -f "$DEST/agent-setup/VERSION" ]; then
    INSTALLED_VERSION="$(tr -d '[:space:]' <"$DEST/agent-setup/VERSION")"
fi

if [ -n "$INSTALLED_VERSION" ] && [ "$INSTALLED_VERSION" = "$NEW_VERSION" ] && [ "$FORCE" -ne 1 ]; then
    echo "agent-setup $INSTALLED_VERSION already installed at $DEST/agent-setup."
    echo "Use --force to reinstall (will back up current tree)."
    exit 0
fi

# ─── Backup on --force ───────────────────────────────────────────────────────
if [ -d "$DEST/agent-setup" ] && [ "$FORCE" = 1 ]; then
    BACKUP="$DEST/agent-setup.bak.$(date +%Y%m%d%H%M%S)"
    echo "Backing up current install → $BACKUP"
    run mv "$DEST/agent-setup" "$BACKUP"
fi

# ─── Sanity check repo layout ────────────────────────────────────────────────
for required in templates bin/render-templates.sh skills/init.md skills/sprint.md; do
    if [ ! -e "$SCRIPT_DIR/$required" ]; then
        echo "bootstrap: missing $SCRIPT_DIR/$required — repo looks incomplete" >&2
        exit 1
    fi
done

# ─── Create target tree ──────────────────────────────────────────────────────
run mkdir -p "$DEST/agent-setup/bin" "$DEST/agent-setup/templates"
run mkdir -p "$DEST/skills/init" "$DEST/skills/sprint"

# ─── Copy payload ────────────────────────────────────────────────────────────
echo "Installing agent-setup $NEW_VERSION → $DEST"

run cp -r "$SCRIPT_DIR/templates/." "$DEST/agent-setup/templates/"
run cp "$SCRIPT_DIR/bin/render-templates.sh" "$DEST/agent-setup/bin/render-templates.sh"
run chmod +x "$DEST/agent-setup/bin/render-templates.sh"
run cp "$SCRIPT_DIR/VERSION" "$DEST/agent-setup/VERSION"

run cp "$SCRIPT_DIR/skills/init.md"   "$DEST/skills/init/SKILL.md"
run cp "$SCRIPT_DIR/skills/sprint.md" "$DEST/skills/sprint/SKILL.md"

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
  $DEST/skills/init/SKILL.md        (/init  — per-project bootstrap)
  $DEST/skills/sprint/SKILL.md      (/sprint — workflow runner, global)
  $DEST/agent-setup/templates/      (static templates)
  $DEST/agent-setup/bin/            (shell renderer)

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

Reinstall later:
  bash bootstrap.sh --force   # backs up current templates, then overwrites
─────────────────────────────────────────────────────────────
BANNER
