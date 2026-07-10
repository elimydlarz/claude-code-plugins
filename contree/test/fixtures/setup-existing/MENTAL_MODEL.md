# Mental Model

## Core Domain Identity
A pure JavaScript utility generates URL-safe short codes.

## World-to-Code Mapping
The fixture contains project configuration but no production implementation yet.

## Ubiquitous Language
A changed test is a normal test impacted by added, modified, or deleted project files.

## Bounded Contexts
Normal tests stay separate from functional System and Journey tests.

## Invariants
Changed-test selection never runs functional tests and records state only after tests pass.

## Decision Rationale
The maintained native runner keeps snapshot and impact-selection mechanics out of harness hook configuration.

## Temporal View
Contree setup integrates the native runner without replacing existing lint or architecture hooks.
