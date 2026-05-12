# Feature: Dark Mode Toggle

## Acceptance criteria
- AC: dark-toggle-persists  — User's dark-mode preference survives page reload
- AC: dark-toggle-system    — Respects OS preference on first load
- AC: dark-toggle-keyboard  — Toggle is keyboard accessible

## Constraints
- Constraint: localStorage write atomicity
- Constraint: no flicker on initial paint

## Edge cases
- Edge case: localStorage unavailable
