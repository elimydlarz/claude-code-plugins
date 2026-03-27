---
name: define-requirement
description: "Writes requirement trees in CLAUDE.md. TRIGGER when: adding a new capability, feature, or behaviour to the project."
---

# Define Requirement

Write a requirement tree in `## Requirements` of the project's CLAUDE.md. Requirement trees are the specification — they describe what the system does using `when/then` format.

## When to Use

- Adding a new capability or feature
- Specifying behaviour before implementation
- When the user describes what they want built
- When a behaviour change needs to be captured before coding

## Process

### 1. Identify the Capability

Name it. The top-level of the tree is the capability name — a short noun phrase describing what the system does (e.g., `UserRegistration`, `InvoiceGeneration`, `stop-hook-sync`).

### 2. Write the Tree

Describe the capability's operating principles using `when/then` format:

```
capability-name
  when <condition>
    then <outcome>
    and <outcome>
  when <other condition>
    then <different outcome>
```

Rules:
- **`when` describes conditions** — what triggers or sets up the behaviour. Nest with `and` for compound conditions.
- **`then` describes outcomes** — what the consumer observes. What changes, what's produced, what's prevented.
- **Describe principles, not cases** — "when the input is invalid" not "when the input is empty / when the input is null / when the input is too long".
- **Include the negative** — if something happens when valid, say what happens when invalid. Absence of behaviour is part of the specification.
- **Use the consumer's vocabulary** — describe what the consumer sees, not implementation internals.

### 3. Add to CLAUDE.md

Add the tree as a new subsection under `## Requirements`:

```markdown
### capability-name

\```
capability-name
  when ...
    then ...
\```
```

Each capability gets its own subsection. One tree per subsection.

### 4. Present for Alignment

Share the requirement tree with the user before moving to implementation. The tree is the contract — get agreement on what the system should do before building it.

## What a Good Tree Looks Like

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
