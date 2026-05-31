---
name: lint-fixer
description: "Core playbook for the Engineering Debt Reduction Platform. Detailed step-by-step workflow for scanning, fixing, verifying, and shipping lint debt elimination. Used by all workers."
---

# Lint Fixer Skill — Core Playbook

## Overview

This skill defines the ground-truth workflow for fixing lint debt. All workers (Shared, Feature, Type Migration, Override Cleanup) follow this playbook for their fix-verify-ship cycle.

---

## Workflow Summary

```
[1] Bootstrap    → Detect framework, find override file, check git state
[2] Inventory    → Parse overrides, count by rule/file/directory
[3] Scope        → Worker reads its assigned files from branch plan
[4] Priority     → Sort rules by priority (P1 first, P5 last)
[5] Autofix      → Run eslint --fix for autofixable rules
[6] Manual Fix   → Fix remaining issues file-by-file, top-to-bottom
[7] Verify       → Run validation gates (lint + tsc + build + tests)
[8] Commit       → Stage + commit (never push without approval)
[9] Report       → Summarize what was fixed, what was skipped
```

---

## [1] Bootstrap

Detect everything automatically. Never ask the user what they already have in their repo.

```powershell
# Detect framework
$pkg = Get-Content package.json | ConvertFrom-Json
$framework = if ($pkg.dependencies.'@angular/core') { 'angular' }
             elseif ($pkg.dependencies.react) { 'react' }
             elseif ($pkg.dependencies.vue) { 'vue' }
             else { 'typescript' }

# Detect package manager
$pm = if (Test-Path 'pnpm-lock.yaml') { 'pnpm' }
      elseif (Test-Path 'yarn.lock') { 'yarn' }
      else { 'npm' }

# Detect override file
$overrideFile = if (Test-Path 'eslint.config.file-overrides.mjs') { 'eslint.config.file-overrides.mjs' }
               elseif (Test-Path 'eslint.config.file-overrides.js') { 'eslint.config.file-overrides.js' }
               else { $null }  # Will scan for inline eslint-disable instead

# Git state
$branch = git branch --show-current
$dirty = (git status --porcelain).Count -gt 0
```

**If dirty → STOP.** Ask user: "Working tree has uncommitted changes. Stash, commit, or abort?"

---

## [2] Inventory

Parse the override file to build the work task list. The override file IS the truth — it lists every (file, rule) pair that needs fixing.

```powershell
# Use references/override-analyzer.ps1
& "$agentRoot/references/override-analyzer.ps1" -OverridePath $overrideFile -OutputPath .lint-cleanup/inventory.json
```

Output: structured JSON with:
```json
{
  "totalOverrides": 1237,
  "totalFiles": 341,
  "totalRules": 34,
  "byRule": [{"rule": "no-deprecated", "count": 147, "files": [...]}],
  "byFile": [{"file": "src/app/...", "rules": [...], "count": 5}],
  "byDirectory": [{"dir": "src/app/settings", "files": 45, "overrides": 800}]
}
```

---

## [3] Scope

Each worker has an assigned scope (set of files it owns). Read from `.lint-cleanup/branch-N.md` or determined by worker type:

- **Shared Worker:** `src/app/shared/**`, `src/app/core/**` (interfaces, models, services)
- **Feature Worker:** One feature directory (e.g., `src/app/creditcard/**`)
- **Type Migration:** All remaining files with `no-explicit-any`
- **Override Cleanup:** The override file itself

**HARD RULE:** Never fix files outside your scope. Check ownership.json before every file edit.

---

## [4] Priority Order

Within your scope, fix rules in this order (maximum impact, minimum risk):

| Priority | Rules | Approach | Risk |
|----------|-------|----------|------|
| **P1** | `no-unused-vars`, `id-denylist`, `prefer-const`, `explicit-member-accessibility` | Autofix or trivial | Low |
| **P2** | `prefer-optional-chain`, `prefer-nullish-coalescing`, `prefer-inject`, `prefer-spread`, `prefer-for-of` | Autofix + verify | Low-Med |
| **P3** | `no-explicit-any`, `no-unsafe-assignment`, `no-unsafe-member-access`, `no-unsafe-call`, `no-unsafe-return`, `no-unsafe-argument`, `no-unsafe-enum-comparison` | Manual, type inference | Med-High |
| **P4** | `no-deprecated`, `no-shadow`, `no-floating-promises`, `unbound-method`, `no-lifecycle-call` | Manual, may escalate | High |
| **SKIP** | `prefer-standalone`, `template/no-inline-styles`, `skyux-eslint-template/*` | Do NOT fix without explicit ask | Architectural |

**Always P1 first.** Quick wins build confidence, free up import/variable noise so P3/P4 are cleaner.

---

## [5] Autofix (Cheap Wins)

Run targeted autofix per rule for autofixable rules only:

```powershell
# Angular
npx eslint <files> --rule "<ruleId>: error" --fix --no-error-on-unmatched-pattern

# Per-rule so one fix doesn't introduce issues for another rule
```

**Autofixable rules (safe to run --fix):**
- `prefer-const`
- `prefer-optional-chain`
- `prefer-nullish-coalescing` (VERIFY semantics for 0/"" cases)
- `explicit-member-accessibility`
- `prefer-spread`
- `prefer-for-of`
- `no-redundant-type-constituents`

**NEVER autofix these (require human/AI judgment):**
- `no-explicit-any`
- All `no-unsafe-*`
- `no-deprecated`
- `prefer-inject` (mechanical but touches constructor — verify)
- `no-floating-promises`
- Template rules

After autofix: run scoped lint on touched files to confirm reduction.

---

## [6] Manual Fix Loop

For each remaining `(file, line, rule)` in priority order:

```
1. READ: ~15 lines around the reported line
2. RECIPE: Look up rule in references/rule-patterns.md
3. EDIT: Apply fix using exact-string replacement (3-5 lines context)
4. VERIFY LINE: Re-read file at [line-2, line+2] — confirm fix landed
5. NEXT: Move to next issue in same file (top-to-bottom)
6. CHUNK: After every 5 files → run verification gates
```

### Rules for Manual Fixes

- **Edit top-to-bottom** within a file (avoids line drift from prior edits)
- **If file content doesn't match** lint report → re-lint for fresh line numbers
- **If recipe requires domain knowledge** → skip file, log reason, continue
- **If multiple valid approaches** → pick simplest, document choice
- **If fix would change runtime behavior** → STOP, ask user
- **Never use PowerShell `-replace` for file edits** → Use `replace_string_in_file` tool. PowerShell regex corrupts newlines and inserts literal `\n` characters
- **Never prepend imports blindly** → Search the file for existing imports from the same module FIRST. Merge into the existing import statement. Adding a duplicate `import { X } from 'module'` causes `no-duplicate-imports` errors
- **When narrowing from `any`** → Check ALL call sites of the method/variable before changing the type. Hidden arguments, overloads, or optional params masked by `any` will cause test failures
- **Cast at usage site, not variable declaration** → For mock/spy variables, cast where the value is used (e.g., `.and.returnValue(x as T)`) not on the variable itself. Casting the variable hides spy methods like `.toHaveBeenCalled()`
- **Always check the spec file** → After changing a method signature (adding generics, removing params, changing types), IMMEDIATELY lint the corresponding `.spec.ts`. Spec casts like `as ICellRendererParams` or `as unknown as Event` often break when the source type changes. Fix them in the same commit.
- **Export interfaces used in public signatures** → If you introduce a type parameter (e.g., `ICellRendererParams<MyRowData>`) and the component has a `.spec.ts`, the interface MUST be exported so specs can import it for proper casting.
- **Never `.bind(this) as unknown as () => void`** → Wrap callbacks in arrow functions instead. Casts hide signature mismatches and drop argument type safety.

---

## [7] Verification Gates

After EVERY chunk of 5 files. Read `workers/validation.md` for full details.

```
Gate 1: Scoped Lint     → target rule count DECREASED, no new violations
Gate 2: TypeScript      → tsc --noEmit passes (zero new errors)
Gate 3: Build           → ng build / npm run build passes
Gate 4: Tests           → ALL tests pass, zero failures
Gate 5: Silencer Check  → git diff shows no eslint-disable / @ts-ignore / as any
Gate 6: Coverage        → statement coverage >= 80%
```

**ANY gate fails → diagnose → try to fix (max 2 attempts) → re-run gate. If fix fails → revert that chunk → log failure → continue next chunk.**

Do NOT stop the entire branch on one chunk failure. Only stop if 5+ consecutive chunks fail (systemic issue).

---

## [8] Commit

After all chunks verified:

```powershell
# Stage all fixed files
git add <fixed-files>

# Regenerate the override file to remove cleared entries for this batch
# Angular (with skyux-angular-builders):
npx ng generate @blackbaud-internal/skyux-angular-builders:lint-file-overrides

# If no generator available: manually remove cleared (file, rule) entries
# Or defer to Phase 4 (override cleanup) for bulk removal

# Verify the override file change is clean (only removals, no additions)
git diff eslint.config.file-overrides.mjs | Select-String "^\+" | Where-Object { $_ -notmatch "^\+\+\+" }
# Should show ONLY removed lines (prefixed with -), NEVER new rule additions

# Stage override file changes too
git add eslint.config.file-overrides.mjs

# Commit with conventional commit message
git commit -m "fix(lint): eliminate <rule> warnings in <scope>

Fixed <N> violations of <rule> across <M> files.
All tests passing. No behavior changes.
Override file updated: removed <X> cleared entries."
```

**Override file rules:**
- NEVER add new rules to the override file
- ONLY remove entries where the violation is confirmed fixed
- If `ng generate` command is available → use it (auto-regenerates accurately)
- If not available → defer override cleanup to Phase 4
- Always verify the diff shows only removals

**Never push automatically.** Ask user: "Push and open PR? (y/n)"

If user says yes (or AUTO_PUSH mode):
```powershell
git push -u origin <branch-name>
# Then open PR via ADO/GitHub MCP
```

---

## [9] Report

After each batch:
```
✅ Batch: Fixed <count> overrides in <files> files
   Rule: <rule> | Before: X → After: Y (-Z)
   Gates: ALL PASS | Skipped: <N> files
```

After branch complete:
```
🎯 Branch Complete: lint/<name>
   Overrides: <before> → <after> (-<delta>, <percent>% reduction)
   Rules cleared: [list of rules now at zero in this scope]
   Tests: PASSING (<N> specs)
   Coverage: <X>% (threshold: 80%)
   Skipped: <N> files (logged in .lint-cleanup/skipped.md)
   Failed fixes: <N> (logged in .lint-cleanup/failed-fixes.log)
   
   Ready to push + PR? (y/n)
```

---

## Failed Fixes Log

All failed fixes are logged to `.lint-cleanup/failed-fixes.log` with enough detail to retry later or fix manually.

**Format:**
```
[2026-05-31T10:15:23] FAILED | branch: lint/feature-creditcard | file: src/app/creditcard/service.ts
  Rule: @typescript-eslint/no-explicit-any (line 45)
  Attempted: Replace `any` with `CreditCardResponse`
  Failure: tsc error TS2339 — Property 'cardNumber' does not exist on type 'CreditCardResponse'
  Root cause: API response has additional fields not in interface
  Action needed: Update CreditCardResponse interface to include 'cardNumber' field

[2026-05-31T10:22:07] FAILED | branch: lint/feature-creditcard | file: src/app/creditcard/list.component.ts
  Rule: @typescript-eslint/no-deprecated (line 12)
  Attempted: Replace RouterTestingModule with provideRouter([])
  Failure: Test failure — "No provider for ActivatedRoute"
  Root cause: Component uses ActivatedRoute params, needs route stub
  Action needed: Add provideActivatedRoute mock to test providers
```

**When to log:**
- Any file that was skipped after 2 fix attempts failed
- Any file skipped because fix would change runtime behavior
- Any file skipped due to domain knowledge requirement

**Workers append to this log; never overwrite it.** The log survives across sessions for resumability.

---

## Ownership Enforcement

Before editing ANY file, verify:

```
1. Read .lint-cleanup/ownership.json
2. Check: is this file claimed by another worker?
3. If YES → DO NOT EDIT → log "ownership conflict: <file> owned by <worker>"
4. If NO → proceed with edit
```

After starting work on a file, register ownership:
```
Update ownership.json: add file to current worker's claimed set
```

---

## Error Recovery

| Failure Type | Action |
|---|---|
| Single file breaks lint | Diagnose → try to fix (2 attempts) → revert if fails, log, continue |
| Single file breaks tsc | Diagnose → try to fix (2 attempts) → revert if fails, log, continue |
| Single file breaks tests | Diagnose → check if behavioral change → try to fix → revert if fails, log, continue |
| Coverage drops below threshold | Identify uncovered lines → add/adjust tests → revert chunk if can't recover |
| 5+ files fail in a row | STOP — systemic issue, report to user |
| Ownership conflict | REFUSE to edit, log, skip file |
| Type cannot be inferred | Skip file with reason, continue |
| Deprecated API no replacement docs | Skip, log for Phase 4 review |

---

## Known Pitfalls (Lessons from Real Sessions)

These are **proven time-sinks**. Follow these rules to avoid repeating them:

### 1. Never use PowerShell regex for file edits

`$content -replace` with backtick-n inserts literal characters, not real newlines. This silently corrupts files and requires a second fix pass.

**Rule:** Use `replace_string_in_file` tool for ALL file edits. Terminal is for read-only operations only (`git status`, `npx eslint`, `tsc`, etc.).

### 2. Always merge imports — never prepend duplicates

Adding `import { X } from 'module'` at the top when the same module is already imported elsewhere causes `no-duplicate-imports` errors and wastes a fix cycle.

**Rule:** Before adding any import, search the file for `from 'module-name'`. If found, merge into the existing import statement.

### 3. Check all call sites before narrowing `any`

Replacing `any` with a specific type makes code compile, but may hide arguments or overloads that callers depend on. This causes test failures that are hard to diagnose.

**Rule:** When narrowing from `any`, grep for all usages of the function/method. Check if callers pass extra arguments, use optional params, or rely on implicit behavior that `any` was masking.

### 4. Check git state before commit operations

Running `git commit --amend` during an in-progress merge leaves conflict markers in files. Only caught when tests fail with cryptic TS errors.

**Rule:** Always run `git status` before any commit/amend. If in a merge or rebase state, use `git commit` (not `--amend`).

### 5. Cast at usage site, not variable declaration (mocks)

Casting a mock variable (`const mock = x as SomeType`) hides spy methods. `expect(mock.method).toHaveBeenCalled()` fails because the type no longer exposes jasmine spy properties.

**Rule:** Keep mock variables typed as spies. Cast only at the point of use: `.and.returnValue(result as unknown as T)`.

### 6. Validate every 5 files, not at the end

Fixing 30 files then running validation creates a 30-file debug surface. Each validation cycle is ~2-3 min; catching errors early limits blast radius.

**Rule:** Run all gates after every 5 files (as prescribed). Never batch more than 5 files between validations.

### 7. Verify method name casing after mock changes

When renaming or refactoring mocks, method names may get incorrect casing (e.g., `endEventWithError` vs `endEventwitherror`). TypeScript won't catch this if the mock is typed as `any` or `jasmine.SpyObj<any>`. Tests pass compilation but fail at runtime with "spy not called."

**Rule:** After any change to a mock object or its methods, verify the method name casing matches the real implementation exactly. Search for the original method name in the source class to confirm spelling.

---

## Common Test-Fix Patterns

When fixing lint in spec files, watch for these pre-existing bugs that surface when `any` is removed:

### Mock methods returning void instead of Observable

```typescript
// ❌ Broken — returns void, callers expect Observable
class MockService {
  getData() { /* nothing */ }
}

// ✅ Fixed — return proper Observable
class MockService {
  getData(): Observable<unknown[]> { return of([]); }
}
```

**When you see it:** `no-unsafe-*` or `no-explicit-any` on a mock class. After typing it correctly, `.pipe()` or `.subscribe()` calls will throw because the method returns `void`.

**Rule:** When fixing types on mock classes, verify every mock method returns a value compatible with what the real service returns (Observable, Promise, object, etc.).

### Duplicate providers — last one wins silently

```typescript
// ❌ First provider is dead code (second overrides it)
providers: [
  { provide: MyService, useValue: { getAll: () => of([]) } },
  { provide: MyService, useValue: { hasAccess: () => true } },
]

// ✅ Merge into one or remove the dead one
providers: [
  { provide: MyService, useValue: { getAll: () => of([]), hasAccess: () => true } },
]
```

**When you see it:** Two `{ provide: X }` entries for the same token. Check which methods the component actually calls — keep only those.

**Rule:** Before adding a mock provider, search the providers array for existing entries with the same token. Merge or remove duplicates.

### Vacuously-true assertions (wrong mock structure)

```typescript
// ❌ Test passes but tests nothing — params.value is always undefined
component.agInit({ params: { value: [1, 2, 3] } });
expect(component.items).toBeUndefined(); // "passes" because structure is wrong

// ✅ Pass correct structure, assert real behavior
component.agInit({ value: [1, 2, 3] });
expect(component.items).toEqual([1, 2, 3]);
```

**When you see it:** Assertions like `toBeUndefined()`, `toEqual(undefined)`, `toBeFalsy()` on values that SHOULD have data. The test setup is passing the wrong object shape.

**Rule:** When a test asserts undefined/falsy on something that should clearly have a value, check the mock structure against what the component actually reads. Fix the test to test real behavior.

### Loop index bugs in tests

```typescript
// ❌ Always patches last control (length-1 on every iteration)
for (const control of controls) {
  component.patchControl(controls.length - 1, 'value');
}

// ✅ Use index
for (let i = 0; i < controls.length; i++) {
  component.patchControl(i, 'value');
}
```

**Rule:** When lint-fixing loops in tests, verify the index variable is actually used correctly. Off-by-one or constant-index bugs are common in test code.

### Mock class ordering (dependency between mocks)

```typescript
// ❌ MockService.open() references MockInstance before it's defined
class MockService { open() { return new MockInstance(); } }
class MockInstance { closed = of({ action: 'ok' }); }

// ✅ Define dependency first
class MockInstance { closed: Observable<{ action: string }> = of({ action: 'ok' }); }
class MockService { open() { return new MockInstance(); } }
```

**Rule:** When mock classes reference each other, ensure the dependency is defined first. TypeScript hoisting doesn't apply to class expressions in the same way.

---

## Resumability

If a session is interrupted, the next session can resume:

```
1. Read .lint-cleanup/ownership.json → see what's done/in-progress
2. Read .lint-cleanup/branch-N.md → see assigned files
3. Run scoped lint on remaining files → get current state
4. Continue from where it stopped
```

Progress is tracked per-file in ownership.json, not just per-branch.

---

## Fast Mode (`--fast`)

Activated with `execute --fast` or `execute --branch N --fast`. Trades per-chunk safety for 3-5x speed on low-risk rules.

### What changes in fast mode

| Step | Normal | Fast |
|------|--------|------|
| Autofix | Per-rule, scoped | **All autofixable rules, entire branch, one shot** |
| Batch size | 5 files | **10 files** |
| Per-chunk gates | lint + tsc + build + tests | **lint + tsc only** |
| Final gates | All | **All (lint + tsc + build + tests + coverage)** |
| Fix approach | Read 15 lines → edit → re-read | **Read full file → plan all fixes → single multi_replace** |

### Fast mode workflow

```
[1] Autofix blast     → eslint --fix on ALL scoped files (one command)
[2] Verify blast      → lint + tsc only (catch regressions from autofix)
[3] Commit autofix    → Separate commit: "fix(lint): autofix P1/P2 rules in <scope>"
[4] Manual fix loop   → 10 files per chunk, read full file, batch edits
[5] Per-chunk gates   → lint + tsc ONLY (skip build + tests)
[6] Final validation  → FULL: lint + tsc + build + tests + coverage
[7] Commit + report
```

### Step [1] Autofix Blast

```powershell
# Fix ALL safe rules at once across the entire scope
$scopeFiles = Get-Content .lint-cleanup/branch-N.md | Where-Object { $_ -match '\.ts$' }
$fileArgs = $scopeFiles -join ' '

npx eslint $fileArgs --fix --no-error-on-unmatched-pattern 2>&1
```

This handles `prefer-const`, `prefer-optional-chain`, `prefer-nullish-coalescing`, `explicit-member-accessibility`, `prefer-spread`, `prefer-for-of` in one shot.

### Step [4] Batch Edit Strategy

Instead of read-edit-verify per line:

```
1. READ: Full file content
2. PLAN: Identify ALL lint violations in that file (from lint output)
3. EDIT: Apply ALL fixes in one multi_replace_string_in_file call
4. NEXT FILE: Don't re-read, move on
5. After 10 files → run lint + tsc
```

**Why this is faster:** One tool call with 5 replacements is faster than 5 separate read-edit-verify cycles. Line drift doesn't matter because you're working from a single read.

### Step [5] Relaxed Gates (per-chunk)

```powershell
# Gate 1: Scoped lint — count must not increase
npx eslint $chunkFiles 2>&1 | Select-String "error"

# Gate 2: TypeScript — must compile
npx tsc --noEmit 2>&1 | Select-String "error TS"

# SKIP: build, tests, coverage (deferred to final)
```

**Why tsc is NOT skippable:** Removing a parameter, adding generics, or changing a type can cascade to files you didn't touch. `tsc` catches this in 5 seconds. Build/tests take 60-120 seconds and only matter for behavioral changes.

### Step [6] Final Validation (mandatory, no shortcuts)

After ALL manual fixes are done:

```powershell
# Full build
ng build

# Full tests
ng test --watch=false --code-coverage

# Coverage check
# Statement coverage must be >= 80%

# Silencer check
git diff --unified=0 | Select-String "eslint-disable|@ts-ignore|as any"
# Must return NOTHING
```

**If final validation fails:** Bisect which chunk broke it. Revert that chunk, re-apply with normal mode gates.

### When NOT to use fast mode

- **P3 fixes (`no-explicit-any`, `no-unsafe-*`)** — Type changes cascade unpredictably. Use normal mode.
- **P4 fixes (`no-deprecated`, `no-floating-promises`)** — May change behavior. Use normal mode.
- **Unfamiliar codebase** — You don't know what's safe. Use normal mode for first branch.

### When fast mode shines

- **P1/P2 only** — `prefer-const`, `id-denylist`, `explicit-member-accessibility`, `prefer-optional-chain`
- **Spec files** — Test code changes don't affect production behavior
- **Second pass** — You already ran normal mode once, now cleaning up residuals
