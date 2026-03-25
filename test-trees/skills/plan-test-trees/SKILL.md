---
name: plan-test-trees
description: "Plans test trees for proposed behaviour changes. TRIGGER when: planning, designing, or discussing changes before writing code."
---

# Plan Test Trees

Before writing any code or tests, plan the test trees that will drive the implementation. This makes the outside-in decomposition visible and ensures you only build what a real consumer demands.

## When to Plan

- Before starting any behaviour change
- During plan mode or design discussions
- When the user asks "how should we test this?" or "what would this look like?"
- When reviewing a proposed change or feature
- Before a PR, to agree on scope

## Process

1. **Identify the consumer.** Who or what consumes this behaviour? A user? An API client? Another module? The consumer's perspective is where you start — not the internals.

2. **Write the functional tree first.** Describe what the consumer observes. No implementation details. No internal module names. Just: what happens from the outside when things go right, and when they go wrong?

3. **Decompose inward to unit trees.** For each functional behaviour, ask: what internal components need to exist to make this work? Write a unit tree for each component, showing what it does when called by its consumer (the layer above). Mock collaborators — each unit tree describes one component's responsibilities, not the whole chain.

4. **Review the trees as a specification.** Read them top-to-bottom. Do they describe *operating principles* clearly enough that someone unfamiliar with the code could understand what the system does? If not, restructure.

5. **Present to the user.** Share the planned trees and get alignment before writing any code.

## Test Tree Format

Structure trees so output reads as a human-readable specification of operating principles.

### Rules

- **Top-level names the subject.** Functional trees name the feature/capability. Unit trees name the module/class/function being tested.
- **`when` describes conditions.** Nest with `and` for compound conditions.
- **`then` describes outcomes.** What the consumer observes.
- **Describe principles, not cases.** "when <= 3 queries" not "when 1 query / when 2 queries / when 3 queries".
- **Include the negative.** If something renders when valid, say what happens when invalid. The absence of behaviour is part of the specification.

### Functional Trees

Functional trees describe consumer-visible behaviour. They use the language of the consumer, not of the implementation.

```text
FUNCTIONAL: UserRegistration
  when a new user registers with valid details
    then the user account is created
    and a welcome email is sent
  when a new user registers with a duplicate email
    then registration is rejected
    and the existing account is not modified
```

Ask yourself:
- What does the consumer (user, API client, CLI user) actually do?
- What do they observe in response?
- What are the key boundary conditions from their perspective?

### Unit Trees

Unit trees describe a single component's responsibilities. They use the language of collaborators and internal contracts.

```text
UNIT: RegistrationService
  when details are valid
    and email is unique
      then creates account via AccountRepository
      then dispatches WelcomeEmail event
    and email is already taken
      then raises DuplicateEmailError
      then does NOT create account
```

Each unit tree should make clear:
- What this component does (not what its collaborators do)
- What it delegates and to whom
- What it refuses to do and why

### Connecting the Layers

The functional tree states *what* should happen. The unit trees show *how* each layer contributes. Every `then` in the functional tree should be traceable through the unit trees.

```text
FUNCTIONAL: InvoiceGeneration
  when a completed order is invoiced
    then an invoice PDF is generated
    and the invoice is emailed to the customer
  when an incomplete order is invoiced
    then invoicing is rejected

UNIT: InvoiceService
  when order is complete
    then generates invoice via PdfGenerator
    then dispatches InvoiceEmail event
  when order is NOT complete
    then raises IncompleteOrderError
    then does NOT generate invoice

UNIT: PdfGenerator
  when generating an invoice
    then renders order line items
    then returns PDF bytes

UNIT: InvoiceEmailHandler
  when handling an InvoiceEmail event
    then sends email with PDF attachment via EmailGateway
```

## Thinking Consumer-Driven

The most common mistake is starting from the implementation and working outward. Instead:

1. **Start from the consumer's vocabulary.** If the consumer says "register", the functional tree says "registers" — not "calls POST /api/users".
2. **Let the functional tree drive decomposition.** Don't decide on internal components first and then figure out how to test them. The functional tree tells you what needs to exist; unit trees emerge from asking "what components would make this work?"
3. **Each unit tree has its own consumer.** The `RegistrationService` is consumed by the functional layer. The `AccountRepository` is consumed by the `RegistrationService`. Write each unit tree from the perspective of *its* consumer.
4. **Stop decomposing when it's obvious.** Not every internal function needs a unit tree in the plan. If a component's behaviour is trivial or a thin wrapper, mention it but don't force a tree.

## Output Format

Always present planned trees with the layer label prefix (`FUNCTIONAL:` or `UNIT:`), grouped with the functional tree first, then unit trees in outside-in order (outermost component first).

Separate each tree with a blank line. Use consistent indentation (2 spaces per level).
