# Validation Gates

## Role

This document defines the reusable validation gates that ALL workers run after every chunk. A "gate" is a check that must pass before work continues. Any failure triggers a revert-and-skip of the offending chunk.

---

## Gate Definitions

### Gate 1: Scoped Lint

**Purpose:** Confirm the rule you're fixing decreased, no NEW rules appeared, and no lint errors introduced in OTHER files.

```powershell
# Lint ONLY the fixed files (fast check)
npx eslint <fixed-files> --format json > .lint-cleanup/gate1-scoped.json

# Lint the FULL project to catch cross-file regressions (before commit/push)
npx eslint . --format json > .lint-cleanup/gate1-full.json
```

**Pass criteria:**
- Target rule count for fixed files: DECREASED or ZERO
- No new rule violations in fixed files
- No new warnings that weren't there before
- **CRITICAL: No new errors/warnings introduced in OTHER files you didn't touch**
  - Compare full lint output against baseline (recorded at branch start)
  - If a file you didn't edit now shows new errors → your type change or import removal broke it

**Fail action:** Diagnose which change caused the cross-file error. Try to fix (2 attempts). If unfixable, revert last chunk.

---

### Gate 2: TypeScript Compilation

**Purpose:** Ensure type changes compile cleanly.

```powershell
# Angular
npx tsc --noEmit --project tsconfig.app.json

# React (typical)
npx tsc --noEmit

# Vue
npx vue-tsc --noEmit
```

**Pass criteria:** Exit code 0, zero errors.

**Fail action:** Revert last chunk. The failure is almost always a type mismatch — a new interface doesn't match callers, or a removed `any` exposed an incompatible usage.

---

### Gate 3: Build

**Purpose:** Ensure the application still builds for production.

```powershell
# Angular
npx ng build --configuration=production 2>&1 | Select-Object -Last 20

# React (CRA)
npx react-scripts build

# React (Vite)
npx vite build

# Vue
npx vue-cli-service build
# or
npx vite build
```

**Pass criteria:** Exit code 0, no build errors.

**Fail action:** Revert last chunk. Build failures after lint fixes are rare but can happen with template-related changes.

---

### Gate 4: Tests

**Purpose:** Ensure all unit tests still pass.

```powershell
# Angular
npx ng test --watch=false --browsers=ChromeHeadless

# React
npx react-scripts test --watchAll=false --ci

# Vue
npx vue-cli-service test:unit --ci
# or vitest
npx vitest run

# Generic
npm test -- --ci
```

**Pass criteria:** Exit code 0, zero test failures.

**Fail action:** Revert last chunk. Log which test failed and which file change likely caused it. If test was testing wrong behavior (testing `any`-dependent code), the test itself may need updating — but only if you own that test file.

---

### Gate 5: Silencer Check

**Purpose:** Ensure no escape hatches were introduced as "fixes."

```powershell
# Check git diff for banned patterns
$diff = git diff --cached --unified=0
$silencers = $diff | Select-String -Pattern 'eslint-disable|@ts-ignore|@ts-nocheck|as any|as unknown as any'

if ($silencers.Count -gt 0) {
    Write-Error "SILENCER DETECTED in diff:"
    $silencers | ForEach-Object { Write-Error $_.Line }
}
```

**Pass criteria:** Zero silencer patterns in the diff.

**Fail action:** Remove the silencer, fix properly, or skip the file.

**Banned patterns:**
- `// eslint-disable-next-line`
- `// eslint-disable`
- `// @ts-ignore`
- `// @ts-nocheck`
- `as any` (with some exceptions — see below)
- `as unknown as any`

**Exceptions (allowed):**
- `as unknown as SpecificType` — valid type assertion
- Test files accessing private members: `as unknown as ComponentWithPrivates`
- Third-party type mismatches where no other solution exists (must be logged)

---

### Gate 6: Code Coverage

**Purpose:** Ensure unit test code coverage does not drop below the required threshold (80%).

```powershell
# Angular
npx ng test --watch=false --browsers=ChromeHeadless --code-coverage
$coverageSummary = Get-Content coverage/coverage-summary.json | ConvertFrom-Json
$totalStatements = $coverageSummary.total.statements.pct

# React (vitest)
npx vitest run --coverage
$coverageSummary = Get-Content coverage/coverage-summary.json | ConvertFrom-Json
$totalStatements = $coverageSummary.total.statements.pct

# React (jest)
npx jest --ci --coverage
$coverageSummary = Get-Content coverage/coverage-summary.json | ConvertFrom-Json
$totalStatements = $coverageSummary.total.statements.pct

# Check threshold
if ($totalStatements -lt 80) {
    Write-Error "CODE COVERAGE BELOW 80%: $totalStatements%"
}
```

**Pass criteria:** Statement coverage >= 80%. Branch/function coverage should not decrease from baseline.

**Fail action:** 
- If coverage dropped because a lint fix removed dead code → acceptable (log it)
- If coverage dropped because a fix broke test assertions → revert chunk, fix properly
- If coverage was already below 80% before your changes → log baseline, ensure you don't reduce it further

**Baseline check:** On first run, record the existing coverage as baseline:
```powershell
# Record at branch start (before any fixes)
$baseline = $coverageSummary.total.statements.pct
# After fixes: coverage must be >= min($baseline, 80)
```

---

## Framework-Adaptive Commands

| Gate | Angular | React | Vue |
|------|---------|-------|-----|
| Lint | `npx eslint <files>` | `npx eslint <files>` | `npx eslint <files>` |
| TypeScript | `npx tsc --noEmit -p tsconfig.app.json` | `npx tsc --noEmit` | `npx vue-tsc --noEmit` |
| Build | `npx ng build` | `npx vite build` or `react-scripts build` | `npx vite build` |
| Test | `npx ng test --watch=false` | `npx vitest run` or `jest --ci` | `npx vitest run` |
| Coverage | `npx ng test --watch=false --code-coverage` | `npx vitest run --coverage` or `jest --ci --coverage` | `npx vitest run --coverage` |

---

## When to Run Gates

| Event | Gates to Run |
|---|---|
| After every 5 files fixed | Gates 1–5 (lint, tsc, build, test, silencer) |
| After autofix batch | Gate 1 (lint) + Gate 2 (tsc) |
| Before commit | All 6 gates (full, including coverage) |
| Before push | All 6 gates (full, clean working tree) |

---

## Failure Escalation

### Fix-First Strategy

When a gate fails, **try to fix the issue before reverting**. Only revert if the fix attempt also fails.

```
Gate fails → Diagnose error → Attempt fix → Re-run gate
  ├─ Fix succeeds → Continue (count as passed)
  └─ Fix fails → Revert chunk → Log → Move to next chunk
```

### Per-Gate Fix Attempts

| Gate | On Failure | Fix Approach |
|------|-----------|--------------|
| Gate 1 (Lint) | New lint error introduced | Re-read the error, fix the specific line, re-run lint on that file |
| Gate 2 (TSC) | Type error | Read the tsc error, fix type mismatch (add missing property, correct type annotation), re-run tsc |
| Gate 3 (Build) | Build error | Read build output, fix template/import issues, re-run build |
| Gate 4 (Tests) | Test failure | Read test output, fix the failing assertion or update test to match corrected behavior, re-run test |
| Gate 5 (Silencer) | Banned pattern in diff | Remove the silencer, apply a proper fix instead, re-check diff |
| Gate 6 (Coverage) | Coverage below threshold | Identify uncovered lines in changed files, add missing test cases or adjust tests, re-run coverage |

### Fix Attempt Rules

1. **Max 2 fix attempts per gate failure** — if it still fails after 2 tries, revert
2. **Never compromise correctness to pass a gate** — don't add `as any` to fix tsc, don't skip assertions to fix tests
3. **Test fixes must test real behavior** — don't write empty/trivial tests just to bump coverage
4. **Log every fix attempt** — include what failed, what was tried, and the outcome

### Escalation After Fix Attempts Exhausted

| Consecutive Reverts | Action |
|---|---|
| 1 chunk reverted | Log, continue to next chunk |
| 2 chunks reverted | Re-read errors carefully, adjust overall approach |
| 3 chunks reverted | PAUSE, report to user: "3 consecutive gate failures — may be systemic issue" |
| 5 chunks reverted | STOP all work, full report, wait for user direction |

---

## Scoped vs Full Gates

**Scoped** (after 5 files — faster):
- Lint only touched files
- tsc on full project (can't scope easily)
- Skip build (too slow for per-chunk)
- Run only affected test files (if determinable)

**Full** (before commit/push — complete):
- Lint entire project
- tsc full project
- Full build
- All tests
- Code coverage check (>= 80% statements)

Use scoped for speed during iteration. Use full for final validation before commit.
