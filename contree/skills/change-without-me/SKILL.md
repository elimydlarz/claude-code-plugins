---
name: change-without-me
description: "Run the complete Contree arc from idea to independently reviewed working software without routine operator phase transitions: change sets the contract, sync audits it, tdd closes every gap, mutation and completion sync prove the result, and second-opinion findings are repaired before completion. TRIGGER when: the user wants the full workflow, asks to take an idea through implementation, asks to make the project complete, or wants change/sync/tdd handled end to end."
---

# Change Without Me

Carry one idea from intent to a verified, independently reviewed implementation. Run each named skill faithfully and keep ownership of the whole workflow until every completion gate passes.

Do not pause for routine phase transitions. If a consequential choice cannot be resolved from the rules, mental model, trees, tests, code, and operator intention, consult the operator, then resume the workflow. Do not add routine phase-transition pauses around that consultation.

If any phase fails, surface the complete error. Do not run a later phase or claim completion.

## Process

### 1. CHANGE — set expected behaviour

Run the `change` skill process. Understand the behaviour, identify the consumer, and write or modify test trees in `TEST_TREES.md`. Start a new user arc with its Journey tree and a capability under an existing journey with its System tree. Add inner-layer trees only when a failing consumer test reveals substantive behaviour at their natural layer.

Do not pause for alignment — proceed directly.

### 2. SYNC — identify gaps and cruft

Run the complete `sync` skill process. Load the trees, run the full suite, audit every leaf, inspect production behaviour in reverse, review every mental-model section, and identify every gap.

Do not pause to present gaps — proceed directly to implementation.

### 3. TDD — close gaps

For every gap identified by sync, run the `tdd` skill process without pausing. Confirm the current tree, write and observe one RED test at its declared layer, implement only enough to make it GREEN, then refactor. When the failure reveals substantive behaviour at an inner layer, add its Domain, Use-case, Adapter, or Port tree and repeat from its consumer. Continue until every identified gap is closed.

Run mutation testing at the end of the TDD phase. Mutation testing validates Domain and Use-case tests. Strengthen the responsible tests and rerun the affected mutation scope until the configured threshold passes.

### 4. COMPLETION SYNC — prove agreement

Rerun the complete `sync` audit and its full suite after mutation testing passes. Require intention, trees, tests, implementation, and the mental model to agree.

If the completion audit finds drift or gaps, route each finding through `change`, `sync`, or `tdd`, then repeat mutation testing and the complete sync audit. Continue until the completion audit proves agreement.

### 5. SECOND OPINION — close independent findings

Once completion sync proves agreement, run the `second-opinion` skill process and surface its independent review.

If the review finds actionable drift or gaps, route every finding through `change`, `sync`, or `tdd`. Repeat every completion gate before requesting another independent review. Continue until the independent review has no actionable findings.

### 6. DONE — intent and implementation are one

Report verified, independently reviewed working software only after every tree has a faithful passing test and fulfilling implementation, mutation testing passes, completion sync proves agreement, the full suite passes, and second-opinion has no actionable findings.
