# Lint Agent - Quick Reference

> Folder-wise parallel lint cleanup. Shared first, then features simultaneously.

## Goal

Fix all ESLint violations folder by folder, enabling strict linting across the codebase.
- Never add rules to override files — only remove as fixed
- Fixes must ONLY reduce violations, never increase them
- Tests pass, build succeeds, zero new violations anywhere

---

## Commands

```
# Scan any directory — shows violations per folder
analyze <path>          e.g. analyze src   or   analyze lib/components

# Show execution order and branch names
plan <path>             e.g. plan src   or   plan src/app

# Fix all violations in a specific folder
fix <folder>            e.g. fix src/shared   or   fix src/features/billing
```

> Works with any project structure. Replace `<path>` / `<folder>` with your actual directory.

---

## Execution Order

```
Step 1 — Fix shared/core FIRST (sequential):
  fix <root>/shared        -> lint-fix/shared
  fix <root>/core          -> lint-fix/core

Step 2 — Fix features in PARALLEL (independent):
  fix <root>/features/a    -> lint-fix/feature-a  -+
  fix <root>/features/b    -> lint-fix/feature-b   | simultaneous
  fix <root>/features/c    -> lint-fix/feature-c  -+
```

`<root>` = your project's source root (`src`, `src/app`, `lib`, `projects/my-app/src`, etc.).
Feature folders are independent — run them in separate sessions at the same time.

---

## When to Use Each Command

| Command | Use when |
|---|---|
| `analyze src/app` | Starting cleanup, want violation counts per folder |
| `plan src/app` | Ready to start, want execution order and branch names |
| `fix <folder>` | Fixing one folder; each session takes a different feature |

---

## Pre-Flight Checklist

- [ ] Git status is clean
- [ ] All tests passing: `npm test`
- [ ] Dependencies installed: `npm install`
- [ ] Shared/core folders fixed before starting features

---

## What Happens When You Run "fix <folder>"

```
# <folder> = any actual path in your project
0. Record baseline violation count + test status
1. git checkout -b lint-fix/<folder-name>
2. npx eslint <folder> --fix            (autofix cheap wins)
3. npx eslint <folder> --format json    (parse remaining)
4. Fix manually in priority order P1->P4
5. npx eslint + tsc --noEmit            (validate every 10 files)
6. npm run lint + build + test          (final validation)
7. git commit -m "fix(lint): <folder-name>"
8. Show summary with violation count reduction
9. Show: git push origin lint-fix/<folder-name>
   Ask: "Ready to create a PR?" (auto-detects Azure DevOps vs GitHub)
```

---

## Within-Folder Priority Order

Fix violations in this order to minimize risk:

| Priority | Rules | Risk |
|---|---|---|
| P1 | no-unused-vars, id-denylist, explicit-member-accessibility | Low |
| P2 | no-explicit-any, explicit-module-boundary-types, no-unsafe-* | Medium |
| P3 | prefer-inject, prefer-optional-chain, prefer-spread | Medium |
| P4 | no-deprecated, no-floating-promises | Higher |
| Skip | prefer-standalone, complex refactors | Defer |

---

## Common Fix Patterns

### No Unused Vars
```typescript
// Remove unused import
import { Foo, Bar } from './types';   // Bar unused
import { Foo } from './types';

// Interface compliance — prefix with _ instead of removing
function handle(event: Event, _context: Context) { }
```

### No Explicit Any — Choose Strategy
```typescript
// a) Known type
function process(data: any)  ->  function process(data: ProcessData)

// b) Truly unknown
function handle(input: any)  ->  function handle(input: unknown) {
  if (typeof input === 'object' && input !== null && 'id' in input) {
    return (input as { id: string }).id;
  }
}

// c) Partial object
const x: any = { name: '' }  ->  const x: Partial<MyType> = { name: '' }

// d) Test mock
const mock: any = { }        ->  jasmine.createSpyObj<MyService>('s', ['method'])
```

### Prefer Inject
```typescript
// Before
constructor(private svc: MyService, private router: Router) {}

// After
private readonly svc = inject(MyService);
private readonly router = inject(Router);
// Remove constructor if empty after conversion
```

### Explicit Accessibility Defaults
| Member | Modifier |
|---|---|
| Template-bound / lifecycle / public API | `public` |
| Injected service | `private readonly` |
| Internal helper / field | `private` |

### ID Denylist
```typescript
const config = { number: 42 };       // Before
const config = { 'number': 42 };     // After
```

---

## Validation Checklist (CRITICAL)

After every 10 files (batch) and at the end:

| Check | Command | Must Pass |
|---|---|---|
| Folder clean | `npx eslint <folder>` | Zero violations in folder |
| No new violations | `npm run lint` | Total count lower than baseline |
| TypeScript | `npx tsc --noEmit` | No compile errors |
| Build | `npm run build` | Succeeds |
| Tests | `npm test` | 0 failures, count same or higher |

**If ANY check fails:** `git checkout -- .`, skip the file, continue.

---

## Error Recovery

```powershell
# Revert a batch
git checkout -- .

# Check if test failure pre-existed
git stash
npm test
git stash pop
# New failure -> revert branch  |  Pre-existing -> note, continue
```

---

## Skipped Patterns

These are deferred — do not attempt during automated fixing:
- `prefer-standalone` — major component refactor
- Deeply nested `no-unsafe-*` — requires domain knowledge
- Deprecated APIs with no direct replacement — needs coordinated update

---

## Never Do This

```typescript
// FORBIDDEN — never suppress rules
/* eslint-disable @typescript-eslint/no-explicit-any */
// eslint-disable-next-line no-unused-vars
```

Fix or skip. Never disable.

---

## Key Principles

1. **Shared first** — Always fix shared/core before features
2. **P1 before P4** — Fix safe rules first, risky ones last
3. **One branch per folder** — Clean, isolated, mergeable
4. **Parallel features** — Feature folders are independent
5. **Baseline must only go down** — Never introduce new violations
6. **User controls push** — Agent commits, user reviews and merges
