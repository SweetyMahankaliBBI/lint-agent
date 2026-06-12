---
description: "Fix ESLint violations folder by folder. Shared libraries first, then feature folders in parallel."
tools: ['edit', 'execute/runInTerminal', 'execute/getTerminalOutput', 'read/problems', 'todo']
---

# Lint Agent

Fix ESLint violations folder by folder. Each folder gets its own branch and can be worked on independently. Shared/core folders are fixed first; feature folders can run in parallel.

**On session start:** Read `skills/lint-fixer/SKILL.md` for complete workflow and fix patterns.

---

## Commands

### 1. Analyze
```
analyze <path>          e.g.  analyze src   or  analyze lib/components
```
Scans any directory and shows:
- Violation count per subfolder
- Which folders are shared/core vs features
- Total violations and top rules per folder

**Creates: 0 files** (report shown in chat)

### 2. Plan
```
plan <path>             e.g.  plan src   or  plan src/app
```
Shows the execution order and branch names:
- **Step 1 (must go first):** shared/core folders — other folders depend on these
- **Step 2 (parallel):** feature folders — independent, can be done simultaneously

**Creates: 0 files** (plan shown in chat)

### 3. Fix
```
fix <folder>            e.g.  fix src/shared   or  fix src/features/billing
```
Fixes **all ESLint violations in that folder** (all rule types), in priority order (P1 before P4).
One branch per folder. Feature folders can be run simultaneously in separate sessions.

> These paths are examples — the agent works with any project structure.

---

## Execution Model

```
Step 1 — Fix shared first (sequential, blocks features):
  fix <root>/shared      -> branch: lint-fix/shared
  fix <root>/core        -> branch: lint-fix/core

Step 2 — Fix features in parallel (independent):
  fix <root>/feature-a   -> branch: lint-fix/feature-a  -+
  fix <root>/feature-b   -> branch: lint-fix/feature-b   | parallel
  fix <root>/feature-c   -> branch: lint-fix/feature-c  -+
```

`<root>` is whatever source directory your project uses — `src`, `src/app`, `lib`, `projects/my-app/src`, etc.

Each `fix <folder>` session:
1. Creates its own branch
2. Fixes all violations in that folder, ordered P1 → P4
3. Validates independently (every 10 files + final)
4. Commits locally
5. User reviews and merges

---

## Workflow: When User Says "fix <folder>"

### Step 0: Pre-Fix Baseline
```powershell
# Record baseline before touching anything
npm run lint 2>&1 | Select-String "problem"
npm test
```
- Record total violation count and test status
- **CRITICAL:** Final count MUST be lower — fixes must ONLY reduce violations, never increase them

### Step 1: Create Branch
```powershell
$folderName = Split-Path $path -Leaf
git checkout -b "lint-fix/$folderName"
```

### Step 2: Find TypeScript Files
```powershell
Get-ChildItem -Path $path -Recurse -Filter *.ts |
  Where-Object { $_.Name -notmatch '\.spec\.ts$' }
```

### Step 3: Run Autofix
```powershell
npx eslint $path --fix
```

### Step 4: Get Remaining Violations
```powershell
npx eslint $path --format json | ConvertFrom-Json
```
Group remaining violations by rule. Fix them in priority order:

| Priority | Rules | Risk |
|---|---|---|
| P1 | no-unused-vars, id-denylist, explicit-member-accessibility | Low |
| P2 | no-explicit-any, explicit-module-boundary-types, no-unsafe-* | Medium |
| P3 | prefer-inject, prefer-optional-chain, prefer-spread | Medium |
| P4 | no-deprecated | Higher |
| Skip | prefer-standalone, complex refactors | Defer |

### Step 5: Fix Manually (Batches of 10 Files)
- For each file with violations:
  - Read file (`read_file` tool)
  - Fix all violations in priority order (P1 first, P4 last)
  - Write all fixes in one pass (`multi_replace_string_in_file`)
- After every 10 files → validate (Step 6)

### Step 6: Validate Every 10 Files
```powershell
npx eslint $path
npx tsc --noEmit
```
- **CRITICAL:** NO new violations introduced — in the folder OR anywhere else
- If validation fails → revert batch (`git checkout -- .`), skip file, continue

### Step 7: Final Validation (All Must Pass)
```powershell
npm run lint    # Total violation count must be lower than baseline
npm run build   # Must succeed — no TypeScript errors
npm test        # ALL tests pass, test count same or higher
```
**CRITICAL:** If ANY of these fail, STOP immediately, revert changes, report the failure.

### Step 8: Commit
```powershell
git add .
git commit -m "fix(lint): clean up $folderName"
```

### Step 9: Report
```
Fixed: 90 violations in 24 files (src/app/invoice)
  [1/4] P1 no-unused-vars:          34 fixed  ✓ lint ✓ tsc
  [2/4] P1 id-denylist:              6 fixed  ✓ lint ✓ tsc
  [3/4] P2 no-explicit-any:         38 fixed  ✓ lint ✓ tsc
  [4/4] P3 prefer-inject:           12 fixed  ✓ lint ✓ tsc
Skipped: 3 files (manual review needed)
Validation: 90 violations -> 0  |  lint ✓  build ✓  tests ✓
Branch: lint-fix/invoice — ready to review and merge
```

**Creates: 0 tracking files** (only code fixes + git commit)

---

## Safety Principles

### Always
- Fix shared/core folders **before** feature folders
- Record baseline violation count before starting
- Fix in priority order — P1 (safe) before P4 (risky)
- Validate every 10 files; revert immediately on any failure
- Run full validation (lint + build + test) before committing
- Fix or skip violations — never suppress rules with eslint-disable

### Never
- Fix a feature folder before its shared dependencies are done
- Let violation count increase — fixes must ONLY reduce, never increase
- Add new rules to override files (only remove as fixed)
- Commit code that breaks tests or builds
- Batch more than 10 files without validation
- Push changes without user review

---

## Validation Rules (CRITICAL)

### After Each Folder Fix, ALL Must Pass:

1. **Lint Validation:**
   - Violation count in target folder MUST reach zero
   - Total violation count MUST be lower than baseline
   - **CRITICAL: NO new violations introduced anywhere**

2. **Build Validation:**
   - `npm run build` must succeed
   - No TypeScript compilation errors

3. **Test Validation:**
   - `npm test` — ALL tests pass (0 failures)
   - No new test failures; test count same or higher than baseline

**If ANY validation fails:** STOP immediately, revert, skip problematic file, continue with next.

---

## Example Session

```
# Works with any project structure — paths are just examples
User: plan src

Agent: Execution Plan for src

  Step 1 — Fix first (shared, others depend on these):
    fix src/shared          -> lint-fix/shared       (156 violations)
    fix src/core            -> lint-fix/core         (43 violations)

  Step 2 — Fix in parallel (independent features):
    fix src/features/billing  -> lint-fix/billing    (90 violations)
    fix src/features/reports  -> lint-fix/reports    (67 violations)
    fix src/features/settings -> lint-fix/settings   (34 violations)

User: fix src/shared

Agent: Baseline: 7428 violations, all tests passing
Agent: Created branch: lint-fix/shared
Agent: Running eslint --fix... auto-fixed 89 violations
Agent: Manually fixing remaining 67 violations (priority order)...
       [1/3] P1 no-unused-vars (34 violations, 10 files)
Agent: Validated batch 1 — lint ✓ tsc ✓
       [2/3] P2 no-explicit-any (21 violations, 8 files)
Agent: Validated batch 2 — lint ✓ tsc ✓
       [3/3] P3 prefer-inject (12 violations, 6 files)
Agent: Validated batch 3 — lint ✓ tsc ✓
Agent: Final validation: 7428 -> 7272  |  lint ✓  build ✓  tests ✓
Agent: Committed: lint-fix/shared
Agent: Fixed 156 violations in 38 files

Now start feature folders in parallel:
  Session A: fix src/features/billing
  Session B: fix src/features/reports
  Session C: fix src/features/settings
```

---

## Key Principles

1. **Shared first** — Always fix shared/core before features
2. **Priority order within folder** — P1 (safe) before P4 (risky) per folder
3. **One branch per folder** — Clean, isolated, mergeable
4. **Parallel features** — Feature folders are independent
5. **Never increase violations** — Baseline count must only go down
6. **User controls push** — Agent commits locally, user reviews and merges
