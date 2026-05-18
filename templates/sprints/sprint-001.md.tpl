<!-- generated-by: /init-project -->
<!-- vars: TODAY_ISO, TODAY_PLUS_14 -->
---
tags: [sprint/001, sprint/active, vault/timeline]
parent: "[[_README]]"
backlog: "[[sprints/backlog]]"
---
# Sprint 001

## 🎯 Sprint Goal
Clarify vision and engineering baseline.

## 📅 Period
- Start: {{TODAY_ISO}}
- End: {{TODAY_PLUS_14}}

## ✅ Tasks (3–8 max)
- [ ] **[US-001]** Resolve clarifications in `.project/state.json > clarifications_pending`
  - Agent: [[agents/product-owner/agent|product-owner]]
  - Workflow: [[workflows/definitions/spike-research|spike-research]]
  <!-- Workflow can also be a dynamic agent chain, e.g. `analyst-product-owner` -->
  - Acceptance criteria:
    - [ ] Every `⚠️ TO CLARIFY` has a written answer or a concrete follow-up in the backlog
    - [ ] [[vision|vision]] reviewed and updated where needed
  - Source: [[vision#clarifications|vision §clarifications]]
  - Depends-on: <!-- e.g. [[spikes/SPIKE-002]] or `<repo>/<task-id>` -->

## 🔁 Workflow Runs
<!-- Auto-appended by `sprint` / `run-workflow` skills — most recent first -->
<!-- - YYYY-MM-DD — [[workflows/runs/<run-id>|<workflow-name>]] (US-XXX) — PASS|FAIL -->

## 📊 Sprint DoD
- [ ] All tasks ticked
- [ ] All acceptance criteria verified
- [ ] `run-tests` green
- [ ] Coverage ≥ spec threshold
- [ ] QA review ✅

## 🚧 Risks
- Vision auto-stub may diverge from actual intent → [[agents/product-owner/agent|product-owner]] + stakeholder review before [[sprints/sprint-002|Sprint 002]].

## ⚠️ To Clarify (sprint blockers)
- See `.project/state.json > clarifications_pending`.
