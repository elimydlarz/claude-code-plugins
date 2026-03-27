---
name: change
description: "Write or modify test trees in CLAUDE.md. TRIGGER when: adding a new capability, changing existing behaviour, or removing a feature."
---

# Change

Talk through a behaviour change with the user and reflect it in the test trees in `## Requirements` of the project's CLAUDE.md. Test trees are the requirements — they describe what the system does using `when/then` format.

## When to Use

- Adding a new capability or feature
- Modifying existing behaviour
- Removing a capability
- When the user describes what they want built or changed
- Before implementation — trees first, code second

## Process

### 1. Understand the Change

What behaviour is being added, modified, or removed? Talk it through with the user. Clarify scope and boundaries before touching any trees.

### 2. Identify the Consumer

Who or what consumes this behaviour? A user? An API client? Another module? The consumer's perspective is where you start — not the internals.

Use the consumer's vocabulary. If the consumer says "register", the tree says "registers" — not "calls POST /api/users".

### 3. Write or Modify the Trees

**Adding a new capability:**

Name the tree — a short noun phrase describing what the system does. Write `when/then` paths describing the capability's operating principles:

```
capability-name
  when <condition>
    then <outcome>
    and <outcome>
  when <other condition>
    then <different outcome>
```

Add as a new subsection under `## Requirements`.

**Modifying existing behaviour:**

Find the existing tree. Add, change, or remove `when/then` paths to reflect the new behaviour. Don't rewrite paths that aren't changing.

**Removing a capability:**

Remove the tree from `## Requirements`. Confirm with the user first.

### 4. Decompose into Layers

For each tree, think about how it decomposes into functional and unit tests:

- **Functional tests** describe consumer-visible behaviour. Each `when/then` path in the tree maps to a functional test.
- **Unit tests** describe individual component responsibilities. Ask: what internal components need to exist? Each component gets unit tests from the perspective of *its* consumer (the layer above). Mock collaborators.
- **Stop decomposing when it's obvious.** Trivial components don't need unit trees.

Every `then` in the tree should be traceable through the functional and unit layers.

### 5. Present for Alignment

Share the trees with the user before moving to implementation. The trees are the contract — get agreement before building.

Once aligned, suggest the user runs `sync` to audit completeness and implement gaps.

## Tree Format Rules

- **`when` describes conditions** — what triggers or sets up the behaviour. Nest with `and` for compound conditions.
- **`then` describes outcomes** — what the consumer observes. What changes, what's produced, what's prevented.
- **Describe principles, not cases** — "when the input is invalid" not "when the input is empty / when the input is null / when the input is too long".
- **Include the negative** — if something happens when valid, say what happens when invalid. Absence of behaviour is part of the specification.
- **Use the consumer's vocabulary** — describe what the consumer sees, not implementation internals.

## Examples

**Good** — describes operating principles:
```
user-registration
  when a new user registers with valid details
    then the user account is created
    and a welcome email is sent
  when the email is already registered
    then registration is rejected
    and the existing account is not modified
```

**Bad** — enumerates cases:
```
user-registration
  when name is "Alice"
    then account for Alice is created
  when name is "Bob"
    then account for Bob is created
```

**Bad** — uses implementation language:
```
user-registration
  when POST /api/users is called with valid JSON body
    then a row is inserted into the users table
    and an SQS message is published to the welcome-email queue
```
