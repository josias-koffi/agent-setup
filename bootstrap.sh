#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# bootstrap.sh — Install the /init skill globally for Claude Code
#
# Run once:
#   bash bootstrap.sh
#
# Then, from ANY project directory:
#   claude
#   /init [optional: vision-file.md]
#
# The /init skill handles both greenfield AND existing projects:
#   - Detects stack, conventions, and existing code
#   - Generates a vision stub from README if no vision provided
#   - Creates agents, workflows, skills, sprints, memory, and engineering spec
#   - Installs project-local /sprint command for running workflows
# ─────────────────────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/skills/init"

echo "📦 Installing /init skill..."

mkdir -p "$TARGET_DIR"
cp "$SCRIPT_DIR/init.md" "$TARGET_DIR/SKILL.md"

echo ""
echo "✅ Installed: $TARGET_DIR/SKILL.md"
echo ""
echo "─────────────────────────────────────────────────────────────"
echo "USAGE"
echo "─────────────────────────────────────────────────────────────"
echo ""
echo "  cd ~/your-project"
echo "  claude"
echo ""
echo "  # Greenfield project (with vision file):"
echo "  /init ./vision.md"
echo ""
echo "  # Existing project (auto-detects stack, auto-generates vision stub):"
echo "  /init"
echo ""
echo "  # After /init completes, run sprints from project root:"
echo "  /sprint 001 developer analyze-design-dev-review US-001"
echo "  /sprint 001 developer analyze-design-dev-review all"
echo "  /sprint 001 qa-reviewer analyze-design-dev-review US-001"
echo ""
echo "─────────────────────────────────────────────────────────────"
