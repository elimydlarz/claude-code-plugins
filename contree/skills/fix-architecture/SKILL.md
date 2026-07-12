---
name: fix-architecture
description: "Repair every reported architecture violation with partitioned subagent work and rerun boundary feedback until green. TRIGGER when: architecture lint reports violations or an operator asks to fix dependency direction, purity, composition-root, or cycle problems."
---

# Fix Architecture

Repair architecture violations at their source without weakening the architecture feedback.

## 1. Establish the complete failure

Read `MENTAL_MODEL.md`, the architecture-linter configuration, the relevant source, and tests. Run the project's architecture command first and preserve its complete output. Group violations by the boundary crossed and the source files that must change.

If a violation conflicts with the operator's intended architecture or `MENTAL_MODEL.md`, explain the concrete conflict and resolve the decision with the operator before changing the enforced boundary. Ordinary implementation violations do not require operator input.

## 2. Partition and delegate

Partition all reported violations into complete, non-overlapping work for subagents. Give each subagent:

- its exact violation output and rule names
- exclusive ownership of the source and test files it may change
- the applicable mental-model invariants
- the commands that prove its partition is repaired

Run independent partitions concurrently. Keep shared composition roots, public port types, architecture configuration, and cross-partition reconciliation with the coding agent so subagents do not overlap.

Subagents fix the production design and preserve observable behavior. Do not disable rules, weaken boundaries, add exemptions, introduce ignore directives, move forbidden work behind aliases, or delete behavior to make lint green.

## 3. Reconcile and verify

Reconcile every subagent change at shared seams. Resolve duplicate ports, incompatible moved types, composition-root wiring, and test coverage yourself. Run the affected normal tests, then rerun the complete architecture command so every architecture rule executes together.

If violations remain, Repartition every remaining violation into fresh non-overlapping subagent work. Reconcile and rerun again until architecture lint passes. Repeated appearances of the same rule are unresolved work, not a reason to suppress the rule.

Do not report completion while any violation remains. Finish only when the complete architecture command and affected tests pass, with no disabled rule, weakened boundary, or exemption in the change.
