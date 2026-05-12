# Feature: Dark Mode Toggle

## Acceptance criteria

- AC: dark-toggle-persists  — User's dark-mode preference survives page reload via localStorage
- AC: dark-toggle-system    — Toggle respects OS-level preference on first load when no override stored
- AC: dark-toggle-keyboard  — Toggle is reachable via Tab and operable via Space/Enter

## Constraints

- Constraint: must not flicker on initial paint (set theme class before React hydrates)
- Constraint: must not break existing CSS variable system

## Edge cases

- Edge case: localStorage unavailable (Safari private mode) — fall back to system preference
- Edge case: user disabled JS — must still render in OS-default theme
