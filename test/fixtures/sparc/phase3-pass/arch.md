# Architecture — Dark Mode Toggle

## Public interface

```ts
export type Theme = "light" | "dark" | "system";

export interface ThemeStore {
  current: Theme;
  setTheme(t: Theme): void;
  subscribe(cb: (t: Theme) => void): () => void;
}

export function createThemeStore(opts: { storage: Storage; initial?: Theme }): ThemeStore;
```

## Module layout

- `src/theme/store.ts` — exports `createThemeStore`. Owns localStorage atomicity (write-through, single mutation per call).
- `src/theme/Toggle.tsx` — UI component. Keyboard accessible via native button.
- `src/theme/inline-script.ts` — runs synchronously before React hydrates to set `<html class>`. Addresses Constraint: no flicker on initial paint.

## Sequence

1. Inline script reads localStorage. If empty, falls back to `matchMedia('(prefers-color-scheme: dark)')`.
2. React hydrates with the same theme.
3. Toggle component calls `setTheme(next)` which writes localStorage atomically and notifies subscribers.

Addresses Constraint: localStorage write atomicity via the `setTheme` single-mutation contract.
