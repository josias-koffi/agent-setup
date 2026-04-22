{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "statusMessage": "Checking tracking file enforcement...",
            "command": "jq --exit-status 'select(.tool_name == \"Skill\" and ((.tool_input.skill // \"\") | test(\"^(sprint|run-agent|run-workflow)$\"))) | {hookSpecificOutput:{hookEventName:\"PostToolUse\",additionalContext:(\"ENFORCEMENT: The \\(.tool_input.skill) skill just completed. You MUST now update tracking files before finishing: (1) tick sprint file checkboxes for every task whose acceptance criteria are fully verified, (2) update .project/state.json — set last_updated, last_workflow_run, last_task_completed, last_workflow_result; add sprint to completed_sprints only if DoD is met, (3) append a dated entry to relevant agent memory files, (4) update the backlog with any newly discovered items. Do NOT skip these steps — they are required by the sprint protocol.\")}}' 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
