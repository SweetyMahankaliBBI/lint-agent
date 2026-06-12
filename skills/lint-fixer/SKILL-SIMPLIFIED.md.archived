---
name: lint-fixer
description: "Fix ESLint violations in a directory. Simple, fast, no external scripts required."
---

# Lint Fixer Skill — Simplified Playbook

## Overview

Fix ESLint violations in any directory. No phases, no planning files, no PowerShell scripts. Just fix code.

---

## Workflow

When user says: `fix src/app/invoice` or `fix lib/shared`

### Step 1: Create Branch
```powershell
git checkout -b "lint-fix/$(Split-Path $path -Leaf)"
```

### Step 2: Find Files
```powershell
Get-ChildItem -Path $path -Recurse -Filter *.ts | Where-Object { $_.Name -notmatch '.spec.ts' }
```

### Step 3: Run Autofix
```powershell
npx eslint $path --fix
```

### Step 4: Fix Remaining Issues
- Run: `npx eslint $path --format json`
- Parse JSON output
- For each file with errors:
  - Read file content
  - Fix violations using VS Code edit tools
  - Batch edits in groups of 10 files

### Step 5: Validate Every 10 Files
```powershell
# Quick validation
npx eslint $path
npx tsc --noEmit
```

If validation fails → revert last batch, skip file, continue.

### Step 6: Final Validation
```powershell
# Full validation
npm run lint
npm run build
npm test
```

### Step 7: Commit
```powershell
git add .
git commit -m "fix(lint): clean up $(Split-Path $path -Leaf)"
```

### Step 8: Report
Show summary in chat:
```
✅ Fixed: 45 violations in 12 files
⚠️ Skipped: 3 files (manual review needed)
✓ Validation: lint + tsc + build + tests passed
```

---

## Rules for Manual Fixes

### Priority Order
1. **P1** - Auto-fixable (eslint --fix already handled)
2. **P2** - Simple renames/imports
3. **P3** - Type annotations
4. **P4** - Refactoring (extract functions, simplify conditions)
5. **P5** - Complex (skip if uncertain)

### Common Patterns

#### `@typescript-eslint/no-explicit-any`
```typescript
// ❌ Before
function process(data: any) {

// ✅ After
function process(data: unknown) {
  // Add type guard if needed
  if (typeof data === 'object' && data !== null) {
```

#### `@typescript-eslint/no-unused-vars`
```typescript
// ❌ Before
import { Foo, Bar } from './types';

// ✅ After
import { Foo } from './types';
```

#### `@angular-eslint/component-class-suffix`
```typescript
// ❌ Before
export class InvoiceView {

// ✅ After
export class InvoiceViewComponent {
```

#### `prefer-const`
```typescript
// ❌ Before
let count = 0;
return count;

// ✅ After
const count = 0;
return count;
```

---

## What NOT To Do

### ❌ Never Suppress Rules
```typescript
// FORBIDDEN - never do this
/* eslint-disable @typescript-eslint/no-explicit-any */
```

### ❌ Never Break Working Code
- If a fix would change behavior → skip it
- Report in summary (no files created)

### ❌ Never Batch Too Many Files
- Validate every 10 files
- If validation fails → revert batch, continue

### ❌ Never Push Without User Approval
- Commit locally only
- User reviews and pushes

---

## Error Recovery

If validation fails:
1. Revert last batch: `git checkout -- .`
2. Skip problematic file
3. Continue with next batch

If tests fail:
1. Check if failure existed before: `git stash && npm test && git stash pop`
2. If new failure → revert
3. If pre-existing → note in summary, continue

---

## Example Session

```
User: fix src/app/invoice

Agent: ✅ Created branch: lint-fix/invoice
Agent: 📁 Found 24 TypeScript files
Agent: 🔧 Running eslint --fix...
Agent: ✅ Auto-fixed 67 violations
Agent: 🔨 Manually fixing remaining 23 violations...
       Editing invoice.component.ts...
       Editing invoice.service.ts...
       Editing invoice.model.ts...
Agent: ✅ Batch 1/3 validated (10 files)
Agent: ✅ Batch 2/3 validated (10 files)
Agent: ✅ Batch 3/3 validated (4 files)
Agent: ✅ Final validation: lint ✓ tsc ✓ build ✓ tests ✓
Agent: ✅ Committed locally
Agent: 📊 Fixed 90 violations in 24 files

Ready to push? (y/n)
```

---

## Key Principles

1. **Start small** - One directory at a time
2. **Validate often** - Every 10 files
3. **Fail fast** - Revert on any error
4. **Never suppress** - Fix or skip, never disable rules
5. **User controls push** - Agent commits, user pushes

---

## Tools Used

- `npx eslint` - Detect and autofix violations
- `npx tsc --noEmit` - Type checking
- `npm run lint/build/test` - Validation gates
- VS Code edit tools - Manual fixes
- Git - Branch, commit, revert

**No PowerShell scripts. No external dependencies. Just VS Code + ESLint.**
