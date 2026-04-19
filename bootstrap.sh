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
#   /init-project [optional: vision-file.md]
#   /sprint 001 [task-id]
#   /run-agent developer "Fix checkout race condition"
#   /run-workflow analyze-design-dev-review US-001
#
#   codex
#   $init-project ./vision.md
#   $sprint 001 [task-id]
#   $run-agent developer Fix checkout race condition
#   $run-workflow analyze-design-dev-review US-001
#
# What gets installed:
#   ~/.claude/skills/init-project/SKILL.md    — Claude /init-project skill
#   ~/.claude/skills/sprint/SKILL.md          — Claude /sprint skill
#   ~/.claude/skills/run-agent/SKILL.md       — Claude /run-agent skill
#   ~/.claude/skills/run-workflow/SKILL.md    — Claude /run-workflow skill
#   ~/.codex/skills/init-project/SKILL.md     — Codex init-project skill
#   ~/.codex/skills/sprint/SKILL.md           — Codex sprint skill
#   ~/.codex/skills/run-agent/SKILL.md        — Codex run-agent skill
#   ~/.codex/skills/run-workflow/SKILL.md     — Codex run-workflow skill
#   ~/.claude/agent-setup/VERSION             — Claude-installed framework version
#   ~/.codex/agent-setup/VERSION              — Codex-installed framework version
#   ~/.claude/agent-setup/bin/
#   ~/.codex/agent-setup/bin/
#     render-templates.sh                     — shell interpolation engine
#   ~/.claude/agent-setup/templates/          — every static template /init copies
#   ~/.codex/agent-setup/templates/           — every static template Codex skills use
#
# `init-project` detects stack + context and calls render-templates.sh once to produce
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
    skills/init.codex.md \
    skills/sprint.codex.md \
    skills/run-agent.codex.md \
    skills/run-workflow.codex.md; do
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
    local run_agent_skill_src="$5"
    local run_workflow_skill_src="$6"
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
        "$dest/skills/run-workflow"

    echo "Installing agent-setup $NEW_VERSION for $cli_name → $dest"

    run cp -r "$SCRIPT_DIR/templates/." "$dest/agent-setup/templates/"
    run cp "$SCRIPT_DIR/bin/render-templates.sh" "$dest/agent-setup/bin/render-templates.sh"
    run chmod +x "$dest/agent-setup/bin/render-templates.sh"
    run cp "$SCRIPT_DIR/VERSION" "$dest/agent-setup/VERSION"

    run cp "$SCRIPT_DIR/$init_skill_src" "$dest/skills/init-project/SKILL.md"
    run cp "$SCRIPT_DIR/$sprint_skill_src" "$dest/skills/sprint/SKILL.md"
    run cp "$SCRIPT_DIR/$run_agent_skill_src" "$dest/skills/run-agent/SKILL.md"
    run cp "$SCRIPT_DIR/$run_workflow_skill_src" "$dest/skills/run-workflow/SKILL.md"
}

install_target "Claude" "$CLAUDE_DEST" \
    "skills/init.md" "skills/sprint.md" "skills/run-agent.md" "skills/run-workflow.md"
install_target "Codex" "$CODEX_DEST" \
    "skills/init.codex.md" "skills/sprint.codex.md" "skills/run-agent.codex.md" "skills/run-workflow.codex.md"

if [ "$DRY_RUN" = 1 ]; then
    echo
    echo "(dry-run — no changes written)"
    exit 0
fi

cat <<'BANNER'

─────────────────────────────────────────────────────────────
✅ agent-setup installed.

Installed under:
  CLAUDE_HOME/skills/init-project/SKILL.md    (Claude /init-project)
  CLAUDE_HOME/skills/sprint/SKILL.md          (Claude /sprint)
  CLAUDE_HOME/skills/run-agent/SKILL.md       (Claude /run-agent)
  CLAUDE_HOME/skills/run-workflow/SKILL.md    (Claude /run-workflow)
  CLAUDE_HOME/agent-setup/                    (Claude framework payload)
  CODEX_HOME/skills/init-project/SKILL.md     (Codex $init-project)
  CODEX_HOME/skills/sprint/SKILL.md           (Codex $sprint)
  CODEX_HOME/skills/run-agent/SKILL.md        (Codex $run-agent)
  CODEX_HOME/skills/run-workflow/SKILL.md     (Codex $run-workflow)
  CODEX_HOME/agent-setup/                     (Codex framework payload)

USAGE
─────────────────────────────────────────────────────────────

  cd ~/your-project
  claude

  /init-project ./vision.md
  /sprint 001
  /sprint 001 US-001
  /run-agent developer "Fix checkout race condition"
  /run-agent qa-reviewer "Review recent checkout changes for regressions"
  /run-workflow analyze-design-dev-review US-001

  codex
  $init-project ./vision.md
  $sprint 001
  $sprint 001 US-001
  $run-agent developer Fix checkout race condition
  $run-agent qa-reviewer Review recent checkout changes for regressions
  $run-workflow analyze-design-dev-review US-001

Reinstall later:
  bash bootstrap.sh --force   # backs up each installed target, then overwrites
─────────────────────────────────────────────────────────────
BANNER
