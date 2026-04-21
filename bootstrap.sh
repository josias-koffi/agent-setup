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
#   claude / codex
#   init-project [optional: vision-file.md]
#   sprint 001 [task-id]
#   run-agent developer "Fix checkout race condition"
#   run-workflow analyze-design-dev-review US-001
#   push-to-github
#   create-pr
#   upgrade-project
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
#   agent-setup/VERSION                    — installed framework version
#   agent-setup/bin/render-templates.sh    — shell interpolation engine
#   agent-setup/templates/                 — every static template init-project copies
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

if [ ! -f "$SCRIPT_DIR/VERSION" ]; then
    echo "bootstrap: VERSION file missing at $SCRIPT_DIR/VERSION" >&2
    exit 1
fi
NEW_VERSION="$(tr -d '[:space:]' <"$SCRIPT_DIR/VERSION")"

for required in \
    templates \
    bin/render-templates.sh \
    skills/init.md \
    skills/sprint.md \
    skills/run-agent.md \
    skills/run-workflow.md \
    skills/upgrade-project.md \
    skills/push-to-github.md \
    skills/create-pr.md \
    skills/documentation-from-commits.md; do
    if [ ! -e "$SCRIPT_DIR/$required" ]; then
        echo "bootstrap: missing $SCRIPT_DIR/$required — repo looks incomplete" >&2
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
    run mkdir -p \
        "$dest/skills/init-project" \
        "$dest/skills/sprint" \
        "$dest/skills/run-agent" \
        "$dest/skills/run-workflow" \
        "$dest/skills/upgrade-project" \
        "$dest/skills/push-to-github" \
        "$dest/skills/create-pr" \
        "$dest/skills/documentation-from-commits"

    echo "Installing agent-setup $NEW_VERSION for $cli_name → $dest"

    run cp -r "$SCRIPT_DIR/templates/." "$dest/agent-setup/templates/"
    run cp "$SCRIPT_DIR/bin/render-templates.sh" "$dest/agent-setup/bin/render-templates.sh"
    run chmod +x "$dest/agent-setup/bin/render-templates.sh"
    run cp "$SCRIPT_DIR/VERSION" "$dest/agent-setup/VERSION"

    run cp "$SCRIPT_DIR/skills/init.md"                      "$dest/skills/init-project/SKILL.md"
    run cp "$SCRIPT_DIR/skills/sprint.md"                    "$dest/skills/sprint/SKILL.md"
    run cp "$SCRIPT_DIR/skills/run-agent.md"                 "$dest/skills/run-agent/SKILL.md"
    run cp "$SCRIPT_DIR/skills/run-workflow.md"              "$dest/skills/run-workflow/SKILL.md"
    run cp "$SCRIPT_DIR/skills/upgrade-project.md"           "$dest/skills/upgrade-project/SKILL.md"
    run cp "$SCRIPT_DIR/skills/push-to-github.md"            "$dest/skills/push-to-github/SKILL.md"
    run cp "$SCRIPT_DIR/skills/create-pr.md"                 "$dest/skills/create-pr/SKILL.md"
    run cp "$SCRIPT_DIR/skills/documentation-from-commits.md" "$dest/skills/documentation-from-commits/SKILL.md"
}

install_target "Claude" "$CLAUDE_DEST"
install_target "Codex"  "$CODEX_DEST"

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
  push-to-github, create-pr, documentation-from-commits

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
