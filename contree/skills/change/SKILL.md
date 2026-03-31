---
name: change
description: "Set expected behaviour by writing or modifying test trees — the contract that says what the system should do before any code exists. TRIGGER when: planning or describing a behaviour change, before any code is written."
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

Name the tree — a short noun phrase describing what the system does. Write paths using EARS patterns (see the `ears` rule) to describe the capability's operating principles:

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

For each tree, think about how it decomposes into functional and unit tests:

- **Functional tests** describe consumer-visible behaviour. Each `when/then` path in the tree maps to a functional test.
- **Unit tests** describe individual component responsibilities. Ask: what internal components need to exist? Each component gets unit tests from the perspective of *its* consumer (the layer above). Mock collaborators.
- **Stop decomposing when it's obvious.** Trivial components don't need unit trees.

Every `then` in the tree should be traceable through the functional and unit layers.

### 5. Present for Alignment

Share the trees with the user before moving to implementation. The trees are the contract — get agreement before building.

Once aligned, suggest the user runs `sync` to audit completeness and implement gaps.

## Tree Format Rules

- **Use EARS patterns** — choose the right keyword for each requirement (see the `ears` rule). Don't force everything into `when/then`.
- **`then` describes outcomes** — what the consumer observes. What changes, what's produced, what's prevented.
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

**Bad** — uses implementation language:
```
media-player
  when AudioContext.decodeAudioData resolves
    then the Float32Array buffer is assigned to the source node
```
