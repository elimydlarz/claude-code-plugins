# Mental Model

## Core Domain Identity
A pure JavaScript utility generates URL-safe short codes.

## World-to-Code Mapping
The project exposes short-code generation and validation from `src/shortcode.js`.

## Ubiquitous Language
A short code is a six-character lowercase alphanumeric string; a changed test is a normal test impacted by added, modified, or deleted project files.

## Bounded Contexts
Normal Unit, Integration, and Component tests stay separate from Journey tests.

## Invariants
Changed-test selection never runs Journey tests and records state only after tests pass.

## Decision Rationale
The maintained native runner keeps snapshot and impact-selection mechanics out of harness hook configuration.

## Temporal View
Contree setup bootstraps the existing behaviour as trees and tests and integrates the native runner without replacing existing lint or architecture hooks.
