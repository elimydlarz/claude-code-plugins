---
name: change
description: "Set expected behaviour by writing or modifying test trees — the contract that says what the system should do before any code exists. TRIGGER when: the user describes a feature, capability, or behaviour change they want — even loosely (e.g. 'I want X', 'let's add Y', 'can we make it do Z', 'change how X works', 'I need to modify', 'remove this behaviour'). Trigger before any code is discussed or written."
---

# Change

Sets expected behaviour before code exists. Talks through a behaviour change with the user and writes it into the test trees in `## Requirements` of the project's CLAUDE.md — making intent explicit and agreed before implementation begins.

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

Name the tree — a short noun phrase describing what the system does. Write paths using EARS patterns (see EARS Patterns below) to describe the capability's operating principles:

```
capability-name
  then <ubiquitous outcome>
  while <precondition>
    then <outcome>
  when <trigger>
    then <outcome>
    and <outcome>
  if <error condition>
    then <recovery outcome>
```

Add as a new subsection under `## Requirements`.

**Modifying existing behaviour:**

Find the existing tree. Add, change, or remove `when/then` paths to reflect the new behaviour. Don't rewrite paths that aren't changing.

**Removing a capability:**

Remove the tree from `## Requirements`. Confirm with the user first.

### 4. Decompose into Layers

Contree prescribes hexagonal architecture: domain is pure, I/O lives in adapters, dependencies point inward. Every tree decomposes across these layers.

**Hexagonal layers:**

- **Domain** — entities, value objects, pure business rules. No framework, no I/O, no async. Takes data, returns data.
- **Use-case (application)** — orchestrates a single consumer-visible behaviour. Receives outbound ports as constructor args. Returns plain data, never adapter types.
- **Inbound adapter** — translates a transport (HTTP, CLI, queue, cron) into use-case input and the result back into a transport response.
- **Outbound port** — interface the use-case depends on (repository, gateway, clock, logger). Lives next to the use-case.
- **Outbound adapter** — concrete implementation of an outbound port against real infrastructure (DB, HTTP SDK, queue client).

**Decomposition rules:**

- Each `when/then` path in the tree maps to a **functional test** exercising the whole vertical slice through a real inbound adapter.
- Each **side effect** in the tree (persistence, external call, time, randomness) becomes an outbound port — named for the capability, not the technology (`OrderRepository`, not `PostgresClient`).
- **Use-case tests** fake outbound ports and assert orchestration + returned data.
- **Adapter tests** are separate: inbound adapters test protocol mapping; outbound adapters test integration against real infrastructure.
- **Domain tests** cover business rules with no mocks, no async, no setup.
- Stop decomposing when it's obvious. Trivial pieces don't need their own tree.

Every `then` in the tree should be traceable down through functional → use-case → (port or domain) → adapter.

**Feature-first module layout** — use this directory shape when adding or touching a capability:

```
src/features/<name>/
  domain/              # entities, value objects, pure rules
  application/
    ports/             # inbound + outbound port interfaces
    use-cases/         # orchestration
  adapters/
    inbound/           # http, cli, queue, cron
    outbound/          # postgres, stripe, s3, etc.
  composition/         # explicit wiring of adapters into use-cases
```

The **composition root** is the only place that imports concrete adapters and wires them into use-cases. Nothing else should.

### 5. Present for Alignment

Share the trees with the user before moving to implementation. The trees are the contract — get agreement before building.

Once aligned, suggest the user runs `sync` to audit completeness and implement gaps.

## Tree Format Rules

- **Use EARS patterns** — choose the right keyword for each requirement (see EARS Patterns below). Don't force everything into `when/then`.
- **`then` describes outcomes** — what the consumer observes. What changes, what's produced, what's prevented.
- **Every `then` must assert something the `when` clause does not already imply** — if a `then` merely restates the condition, it's a tautology and adds no value. "when created / then it is created" tests nothing. "when created with default / then value is zero" asserts a concrete outcome.
- **Describe principles, not cases** — "when the input is invalid" not "when the input is empty / when the input is null / when the input is too long".
- **Include the negative** — use `if/then` for error cases and unwanted behaviour. Absence of behaviour is part of the specification.
- **Use the consumer's vocabulary** — describe what the consumer sees, not implementation internals.

## Examples

**Good** — uses EARS patterns to match each requirement's nature:
```
media-player
  then supports mp3 and wav formats
  while playing
    when pause is pressed
      then playback pauses at current position
    when track ends
      then the next track starts automatically
  when a track is loaded
    then playback begins from the start
  if the file is corrupt
    then playback is rejected with an error message
  where bluetooth is available
    then audio can be routed to a bluetooth device
```

**Bad** — enumerates cases:
```
media-player
  when file is "song.mp3"
    then song.mp3 plays
  when file is "track.wav"
    then track.wav plays
```

**Bad** — tautological (then restates the when):
```
media-player
  when a track is loaded
    then a track is loaded
  when playback is paused
    then it pauses
```

**Bad** — flat siblings for causally dependent behaviour:
```
auth
  when token is invalid
    then refresh is attempted
  when refresh fails
    then user is logged out
```

**Good** — causal nesting (refresh failure depends on refresh being attempted):
```
auth
  when token is invalid
    then refresh is attempted
      when refresh fails
        then user is logged out
```

**Bad** — uses implementation language:
```
media-player
  when AudioContext.decodeAudioData resolves
    then the Float32Array buffer is assigned to the source node
```

## EARS Patterns

Test trees use EARS (Easy Approach to Requirements Syntax) to choose the right keyword for each requirement. Match the pattern to the requirement's nature — don't force everything into `when/then`.

**Ubiquitous** — always true, no condition:
```
then <outcome>
```

**State-driven** — active while a condition holds:
```
while <precondition>
  then <outcome>
```

**Event-driven** — response to a trigger:
```
when <trigger>
  then <outcome>
```

**Optional feature** — applies only when a feature is present:
```
where <feature>
  then <outcome>
```

**Unwanted behaviour** — response to error or undesired situation:
```
if <condition>
  then <outcome>
```

**Complex** — state + event combined:
```
while <precondition>
  when <trigger>
    then <outcome>
```

**Causal nesting** — when a trigger can only occur as a consequence of a prior outcome, nest it under that outcome:
```
when <trigger>
  then <outcome>
    when <consequence of outcome>
      then <next outcome>
```

A `when` that depends on a preceding `then` is not a sibling — it is a child. If "refresh fails" can only happen because "refresh was attempted", nest it under the `then` that attempts the refresh.

Choose the pattern that fits: a system constraint is ubiquitous; a precondition that must hold is state-driven; a discrete trigger is event-driven; an error case is unwanted behaviour; a feature flag is optional. Combine when needed. Nest when one behaviour depends on another's outcome.
