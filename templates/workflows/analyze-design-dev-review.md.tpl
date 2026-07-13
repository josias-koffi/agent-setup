<!-- generated-by: /init-project -->
---
tags: [workflow/definition, workflow/analyze-design-dev-review]
parent: "[[_README]]"
---
# Workflow: Analyze -> Design -> Dev -> Review

## Mode
orchestrated

## Used by
<!-- Auto-appended by `sprint` / `run-workflow` when this workflow is triggered. -->
<!-- - [[sprints/sprint-NNN#US-XXX]] — YYYY-MM-DD → [[workflows/runs/<run-id>]] -->

## Stage 1 - Analyze
Agent: [[agents/product-owner/agent|product-owner]]
Inputs:
- Task record from sprint or ad hoc request
- `.project/vision.md`
- Acceptance criteria
Outputs:
- `.project/workflows/<run-id>/01-analyze.md`
Pass:
- Scope is clear
- Acceptance criteria are testable
- Missing product questions are listed
OnFailure:
- Stop and report unresolved scope gaps

## Stage 2 - Design
Agent: [[agents/designer/agent|designer]]
Inputs:
- `.project/workflows/<run-id>/01-analyze.md`
- UI or UX constraints from the vision
Outputs:
- `.project/workflows/<run-id>/02-design.md`
Pass:
- Proposed design fits the analyzed scope
- UX risks or non-UI skip decision are explicit
OnFailure:
- Stop and return to Stage 1 if the problem framing changed

## Stage 3a - Red (write the failing test)
Agent: [[agents/test-writer/agent|test-writer]]
Inputs:
- `.project/workflows/<run-id>/01-analyze.md`
- `.project/workflows/<run-id>/02-design.md`
- `agent-setup/spec/engineering-standards.md` §11
Outputs:
- `.project/workflows/<run-id>/03a-red.md`
Pass:
- At least one test exists per acceptance criterion
- Every new test was run via `run-tests` (`expect-fail` mode) and observed to fail for the right reason
- Verbatim failure output is captured in the artifact
- No production code was written or modified
- Test committed alone with a `test:` Conventional Commit
OnFailure:
- Stop and document which acceptance criterion could not be expressed as a failing test

## Stage 3b - Green (minimal implementation)
Agent: [[agents/developer/agent|developer]]
Inputs:
- `.project/workflows/<run-id>/01-analyze.md`
- `.project/workflows/<run-id>/02-design.md`
- `.project/workflows/<run-id>/03a-red.md`
- `agent-setup/spec/engineering-standards.md`
Outputs:
- `.project/workflows/<run-id>/03b-green.md`
Pass:
- The received test now passes, run via `run-tests` (`expect-pass` mode)
- The test itself was not weakened, deleted, or rewritten to force a pass
- No other test regressed
OnFailure:
- Stop and document the blocking engineering issue; if the test itself is wrong, flag it and return to Stage 3a — do not edit the test directly

## Stage 3c - Refactor
Agent: [[agents/developer/agent|developer]]
Inputs:
- `.project/workflows/<run-id>/03b-green.md`
- `agent-setup/spec/engineering-standards.md` §9
Outputs:
- `.project/workflows/<run-id>/03c-refactor.md`
Pass:
- Tests re-run via `run-tests` (`expect-pass` mode) and still pass after every refactor step
- Active refactoring honored on touched files (no new duplication or dead code; file size within language target or split per §9)
- Coverage impact is stated
OnFailure:
- Stop and document the blocking engineering issue

## Stage 4 - Review
Agent: [[agents/qa-reviewer/agent|qa-reviewer]]
Inputs:
- `.project/workflows/<run-id>/03a-red.md`
- `.project/workflows/<run-id>/03b-green.md`
- `.project/workflows/<run-id>/03c-refactor.md`
- Acceptance criteria
Outputs:
- `.project/workflows/<run-id>/04-review.md`
Pass:
- Every acceptance criterion is verified or rejected explicitly
- Blocking defects are listed separately from advisories
OnFailure:
- Stop and send the task back to implementation with the blocking findings

## Finalization
Agent: [[agents/tech-lead/agent|tech-lead]]
Inputs:
- `.project/workflows/<run-id>/04-review.md`
Outputs:
- `.project/workflows/<run-id>/final-summary.md`
Pass:
- Final verdict is unambiguous
- Next action is explicit
OnFailure:
- Stop and request clarification from the user
