---
name: change
description: "Set expected behaviour by writing or modifying test trees — the contract that says what the system should do before any code exists. TRIGGER when: the user describes a feature, capability, or behaviour change they want — even loosely (e.g. 'I want X', 'let's add Y', 'can we make it do Z', 'change how X works', 'I need to modify', 'remove this behaviour'). Trigger before any code is discussed or written."
---

# Change

Sets expected behaviour before code exists. Talks through a behaviour change with the user and writes it into the trees in `## Test Trees` of the project's CLAUDE.md — making intent explicit and agreed before implementation begins.

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

Add as a new subsection under `## Test Trees`.

**Modifying existing behaviour:**

Find the existing tree. Add, change, or remove `when/then` paths to reflect the new behaviour. Don't rewrite paths that aren't changing.

**Removing a capability:**

Remove the tree from `## Test Trees`. Confirm with the user first.

### 4. Decompose Across Layers and Positions

A System tree describes a slice's consumer-visible behaviour. Below it sits a set of smaller trees — one per behavioural unit the slice produces. Each smaller tree reifies one test file at one test layer. See the Test Layers section in `skills/tdd/SKILL.md` for full guidance on the four layers (Domain / Use-case / Adapter / System), the in-memory adapter pattern, and the shared port contract suite.

**Hex positions** — the locations in the codebase where code sits:

- **Domain** — entities, value objects, aggregates, domain services. No framework, no I/O, no async. Data in, data out.
- **Use-case (application)** — orchestrates a single consumer-visible behaviour. Receives outbound ports as constructor args. Returns plain data, never adapter types.
- **Driving adapter** — translates a transport (HTTP, CLI, queue, cron) into use-case input and the result back.
- **Outbound port** — interface the use-case depends on (repository, gateway, clock, logger). Lives next to the use-case in `application/ports/`.
- **Driven adapter** — concrete implementation of an outbound port. Ships with an in-memory twin (for Use-case and System tests) plus the real one (for production and Adapter tests).

**Decomposition rules:**

- The top-level tree describes the **slice** — a System tree named for the consumer-visible capability (`save-score`, `cancel-order`). It drives the System test.
- Below it, write a **separate tree** for each behavioural unit that has observable behaviour someone could change silently:
  - A **Domain tree** per domain object or service with substantive rules (`Money`, `SessionToken`). Trivial value objects don't earn a tree — they're implicit in the use-case.
  - A **Use-case tree** per use-case with non-trivial orchestration (`save-score-use-case`). A use-case that just delegates to a single port doesn't earn a tree.
  - A **Driving-adapter tree** per adapter with non-trivial translation (`score-http-handler`). Thin adapters don't earn a tree.
  - A **Port contract tree** per outbound port (`ScoreRepository`, `AuditLog`). The tree is reified by a shared contract suite (see `skills/tdd/SKILL.md`) that both the in-memory and real adapters must pass. Name ports for capability, not technology (`OrderRepository`, not `PostgresClient`).
  - A **Driven-adapter tree** per real driven adapter when it has adapter-specific behaviour beyond the port contract (`ScoreRepository-Postgres` for timeout/retry/schema; the port contract covers the rest).
- **One tree, one test file.** Each tree's `describe`/`it` hierarchy mirrors the tree verbatim.
- **Cross-cutting System trees** — for app-level invariants that aren't per-slice (auth enforcement, rate limiting, error envelope), write a System tree named for the policy.

**Tree naming heuristic** — name each tree for the subject with observable behaviour at its layer:

| Layer    | Subject                             | Example                                         |
| -------- | ----------------------------------- | ----------------------------------------------- |
| Domain   | domain object or service             | `Money`, `SessionToken`, `LeaderboardRanking`   |
| Use-case | the use-case                         | `save-score-use-case`                           |
| Port     | port interface (shared contract)     | `ScoreRepository`, `AuditLog`                   |
| Adapter  | adapter being exercised              | `score-http-handler`, `ScoreRepository-Postgres`|
| System   | capability/slice or cross-cutting policy | `save-score`, `auth-enforcement`            |

**Feature-first module layout** — use this directory shape when adding or touching a capability:

```
src/features/<name>/
  domain/              # entities, value objects, domain services (+ .domain.test.*)
  application/
    ports/             # outbound port interfaces (+ .contract.ts shared suites)
    use-cases/         # orchestration (+ .use-case.test.*)
  adapters/
    inbound/           # http, cli, queue, cron (+ .adapter.test.*)
    outbound/
      in-memory/       # in-memory implementations of outbound ports
      <real>/          # real implementations (postgres, stripe, s3) (+ .adapter.test.*)
  composition/         # explicit wiring; points at real or in-memory adapters per layer
```

The **composition root** is the only place that imports concrete adapters and wires them into use-cases. Nothing else should. Use-case and System tests wire in-memory adapters through it; production wires real adapters.

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
