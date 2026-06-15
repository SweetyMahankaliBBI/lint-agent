---
name: lint-fixer
description: "Fix ESLint violations folder by folder. Shared first, then features in parallel."
---

# Lint Fixer Skill

## Overview

Fix ESLint violations folder by folder. Each folder gets its own branch.
Shared/core folders must be fixed first; feature folders can run in parallel.

**Core Principles:**
- Never add new rules to override files — only remove as fixed
- Fixes must ONLY reduce violations, never increase them
- Validate: tests pass, app builds, no new violations anywhere
- Zero tracking files (only code fixes + git commits)
- Fix or skip — never suppress rules with eslint-disable

---

## Commands

### 1. ANALYZE

**When user says:** `analyze <path>` (any directory in any project)

1. Run ESLint across the target path:
   ```powershell
   npx eslint $path --format json | ConvertFrom-Json
   ```

2. Group results by subfolder, showing:
   - Violation count and file count per folder
   - Top rule violations per folder
   - Classification: `shared/core` vs `feature`

3. Present in chat (paths will match whatever project is being used):
   ```
   Lint Analysis: <path>

   Folder                       Violations   Files   Type
   <path>/shared                156          38      SHARED (fix first)
   <path>/core                  43           12      SHARED (fix first)
   <path>/features/billing      90           24      feature
   <path>/features/reports      67           18      feature
   <path>/features/settings     34           9       feature

   Total: 390 violations across 101 files
   Top rules: no-explicit-any (145), no-unused-vars (89), prefer-inject (67)
   ```

**Creates: 0 files**

---

### 2. PLAN

**When user says:** `plan <path>` (any directory in any project)

1. Run ANALYZE to get folder breakdown
2. Classify folders:
   - Shared: folders named `shared`, `core`, `common`, `lib`, `utils`
   - Features: everything else
3. Present execution plan (using actual paths from the user's project):
   ```
   Execution Plan: <path>

   Step 1 — Fix shared/core first, one rule per PR (P1 → P4):
     fix <path>/shared --rule no-unused-vars     -> lint-fix/shared/no-unused-vars    (34 violations)
     fix <path>/shared --rule no-explicit-any    -> lint-fix/shared/no-explicit-any   (89 violations)
     fix <path>/core   --rule prefer-inject      -> lint-fix/core/prefer-inject       (33 violations)

   Step 2 — Fix features in parallel, one rule per PR:
     fix <path>/features/a --rule no-explicit-any  -> lint-fix/feature-a/no-explicit-any (40 violations)
     fix <path>/features/b --rule no-explicit-any  -> lint-fix/feature-b/no-explicit-any (27 violations)
     fix <path>/features/c --rule no-explicit-any  -> lint-fix/feature-c/no-explicit-any (23 violations)

   Each box above = one branch + one PR. Merge before starting next rule in same folder.
   Same rule can run in parallel across different feature folders.
   ```

**Creates: 0 files**

---

### 3. FIX

**When user says:** `fix src/app/invoice --rule no-explicit-any`

Fix ONE ESLint rule in the specified folder. One branch and one PR per rule per folder.
Fix rules in priority order (P1 first). Merge each PR before starting the next rule in the same folder.

#### Step 0: Pre-Fix Baseline
```powershell
ng lint 2>&1 | Select-String "problem"
ng test --watch=false
```
Record total violation count and confirm all tests pass before touching any code.
**CRITICAL:** The final count after fixing MUST be lower than this baseline.

#### Step 1: Create Branch
```powershell
$folderName = (Split-Path $path -Leaf) -replace '[/\\]', '-'
$ruleName   = $rule -replace '[/@]', '' -replace '/', '-'
git checkout -b "lint-fix/$folderName/$ruleName"
```

#### Step 2: Find TypeScript Files
```powershell
Get-ChildItem -Path $path -Recurse -Filter *.ts |
  Where-Object { $_.Name -notmatch '\.spec\.ts$' }
```

#### Step 3: Run Autofix (scoped to the target rule)
```powershell
npx eslint $path --fix --rule "$rule: error"
```
This handles auto-fixable violations for the target rule only.

#### Step 4: Get Remaining Violations for That Rule and Fix
```powershell
$violations = npx eslint $path --format json | ConvertFrom-Json
# Filter to the target rule only
$violations | ForEach-Object { $_.messages | Where-Object { $_.ruleId -eq $rule } }
```
Fix all remaining violations for the target rule using patterns from the Fix Patterns section.

| Priority | Rules | Risk | Strategy |
|---|---|---|---|
| P1 | no-unused-vars, id-denylist, explicit-member-accessibility | Low | Fix all |
| P2 | no-explicit-any, explicit-module-boundary-types, no-unsafe-* | Medium | Fix all |
| P3 | prefer-inject, prefer-optional-chain, prefer-spread, no-constant-binary-expression | Medium | Fix all |
| P4 | no-deprecated, no-floating-promises, no-unsafe-enum-comparison | Higher | Fix carefully |
| Skip | prefer-standalone, complex type inference, major refactors | Defer | Skip and note |

#### Step 5: Fix Manually (Batches of 10 Files)

For the target rule, process all affected files in batches of 10:
1. Read file (`read_file` tool)
2. Identify all violations for the target rule in that file
3. Apply the matching fix pattern from the Fix Patterns section below
4. Write all fixes in one pass (`multi_replace_string_in_file`)
5. After every 10 files → validate (Step 6)

#### Step 6: Validate Every 10 Files
```powershell
npx eslint $path
npx tsc --noEmit
```
- **CRITICAL:** NO new violations introduced — in this folder OR anywhere else
- If validation fails → `git checkout -- .` (revert batch), skip the file, continue

#### Step 7: Pre-PR Gate (ALL must pass — no exceptions)

```powershell
# 1. Regenerate lint file overrides to reflect the fixed state
ng generate @blackbaud-internal/skyux-angular-builders:lint-file-overrides

# 2. Full Angular lint — total violation count must be lower than baseline
ng lint

# 3. All Angular tests must pass
ng test --watch=false
```

**CRITICAL:** If ANY check fails — STOP, revert all changes (`git checkout -- .`), report the specific failure. Do NOT commit, push, or create a PR.

#### Step 8: Commit and Push (only after gate passes)
```powershell
git add .
git commit -m "fix(lint): $ruleName in $folderName"
git push origin "lint-fix/$folderName/$ruleName"
```

#### Step 9: Create PR
Use PR title: `fix(lint): <rule-name> in <folder-name>  (<N> violations → 0)`

PR description:
```
## Lint Fix: <rule-name> — <folder-name>

Rule: `<rule-name>`
Folder: `<folder-path>`
Violations fixed: N → 0
Files changed: X

### What was done
- <brief summary of fix strategy used>

### Pre-PR Validation
- [x] ng generate @blackbaud-internal/skyux-angular-builders:lint-file-overrides ✓
- [x] ng lint ✓ (violations: <baseline> → <new count>)
- [x] ng test ✓ (all tests pass)
- [x] No new violations introduced elsewhere
```

Detect the remote URL (`git remote get-url origin`), then use the matching MCP tool:
- Azure DevOps: `mcp_azure_devops__repo_create_pull_request`
- GitHub: `mcp_github_mcp_se_create_pull_request`

Set:
- source branch: `lint-fix/<folderName>/<ruleName>`
- target branch: `master` (or `main` — check default branch)

---

## Fix Patterns

### P1 — @typescript-eslint/no-unused-vars

**Remove unused imports:**
```typescript
// Before
import { Foo, Bar } from './types';   // Bar unused

// After
import { Foo } from './types';
```

**Remove unused variables:**
```typescript
// Before
const unusedVar = 'test';

// After
(delete line entirely)
```

**Safety rules:**
- Only remove if there are zero references in the file
- For parameters required by an interface signature, prefix with `_` instead of removing
- In test files, `_param` prefix already indicates intentionally unused — leave as-is
- Never remove if referenced in template expressions or string interpolation

```typescript
// Interface compliance — prefix, don't remove
function handle(event: Event, _context: Context) {
  return event.data;
}
```

---

### P1 — id-denylist

Quote restricted property names (zero functional impact):
```typescript
// Before
const account = { id: 1, number: '100-200' };

// After
const account = { id: 1, 'number': '100-200' };
```

---

### P1 — @typescript-eslint/explicit-member-accessibility

Add access modifiers using these defaults:

| Member | Default modifier |
|---|---|
| Methods called from template | `public` |
| Lifecycle hooks (ngOnInit, etc.) | `public` |
| Service/public API methods | `public` |
| Internal helper methods | `private` |
| Injected services | `private readonly` |
| Properties bound to template | `public` |
| Internal fields | `private` |

```typescript
// Before
class MyComponent {
  title = 'test';
  ngOnInit() {}
  getData() {}
  private helper() {}
}

// After
class MyComponent {
  public title = 'test';
  public ngOnInit(): void {}
  public getData(): void {}
  private helper(): void {}
}
```

---

### P2 — @typescript-eslint/no-explicit-any

Choose the right replacement strategy:

**a) Known type — use the interface:**
```typescript
// Before
function process(data: any) { return data.value; }

// After
function process(data: ProcessData): string { return data.value; }
```

**b) Truly unknown — use `unknown` + type guard:**
```typescript
// Before
function handle(input: any) { return input.id; }

// After
function handle(input: unknown): string {
  if (typeof input === 'object' && input !== null && 'id' in input) {
    return (input as { id: string }).id;
  }
  throw new Error('Invalid input');
}
```

**c) Partial objects:**
```typescript
// Before
const partial: any = { name: 'test' };

// After
const partial: Partial<MyType> = { name: 'test' };
```

**d) Test mocks — use typed spy:**
```typescript
// Before
const mock: any = { getData: () => [] };

// After
const mock = jasmine.createSpyObj<MyService>('MyService', ['getData']);
```

**Never leave `any`** — always replace with a specific type, `unknown`, or a typed mock.

---

### P2 — @typescript-eslint/explicit-module-boundary-types

Add explicit return types to all exported functions:
```typescript
// Before
export function getUsers() {
  return this.userService.getAll();
}

// After
export function getUsers(): Observable<User[]> {
  return this.userService.getAll();
}
```

---

### P3 — @angular-eslint/prefer-inject

Convert constructor injection to `inject()` fields:
```typescript
// Before
export class MyComponent {
  constructor(
    private myService: MyService,
    private router: Router
  ) {}
}

// After
export class MyComponent {
  private readonly myService = inject(MyService);
  private readonly router = inject(Router);
}
```

**Rules:**
- Use `private readonly` for injected services
- Use `public readonly` if accessed from template
- Remove the constructor if it becomes empty
- Maintain original field order

**Edge case — constructor with body logic:**
```typescript
// Keep the constructor, move injections to fields
export class MyComponent {
  private readonly myService = inject(MyService);

  constructor() {
    this.myService.init();   // body logic stays
  }
}
```

---

### P3 — @typescript-eslint/prefer-optional-chain

```typescript
// Before
if (obj && obj.prop && obj.prop.value) {
  return obj.prop.value;
}

// After
return obj?.prop?.value;
```

---

### P3 — prefer-const

```typescript
// Before
let count = 0;
return count;

// After
const count = 0;
return count;
```

---

### P4 — @typescript-eslint/no-deprecated

Replace deprecated APIs with modern equivalents. Common patterns:

**Angular testing:**
```typescript
// Before
imports: [RouterTestingModule]

// After
providers: [provideRouter([])]
```

**Angular core:**
```typescript
// Before
{ provide: APP_INITIALIZER, useFactory: ... }

// After
provideAppInitializer(() => ...)
```

**Browser platform:**
```typescript
// Before
platformBrowserDynamic().bootstrapModule(AppModule)

// After
bootstrapApplication(AppComponent, appConfig)
```

**When no clear replacement exists** — skip and note in summary for manual review.

---

## Skipped / Deferred Patterns

These are intentionally skipped during automated fixing:

| Rule | Reason |
|---|---|
| `@angular-eslint/prefer-standalone` | Major component refactor — requires separate migration |
| Complex type inference (`no-unsafe-*` in deeply nested types) | Requires domain knowledge |
| Deprecated APIs with no direct replacement | Requires coordinated team update |
| Any fix that would change runtime behavior | Skip and flag for manual review |

---

## What NOT To Do

### Never Suppress Rules
```typescript
// FORBIDDEN — never add these
/* eslint-disable @typescript-eslint/no-explicit-any */
// eslint-disable-next-line @typescript-eslint/no-unused-vars
```

### Never Proceed if Violations Increase
- If any fix introduces a new violation anywhere → STOP and revert immediately
- The total violation count must only ever go down

### Never Break Working Code
- If a fix would change runtime behavior → skip it and report
- When uncertain about side effects → skip the file

### Never Skip Validation
- Always validate every 10 files
- Always run full validation before committing

### Never Push Without User Review
- Commit locally only
- User reviews diff and pushes

---

## Error Recovery

### If Lint/TSC Fails (per batch)
```powershell
git checkout -- .   # Revert the batch
# Skip the problematic file
# Continue with next batch
```

### If Final Tests Fail
```powershell
git stash           # Check if failure pre-existed
npm test
git stash pop
# If new failure -> revert all changes on this branch
# If pre-existing -> note in summary, continue
```

---

## Tools Used

- `npx eslint` — detect and autofix violations
- `npx tsc --noEmit` — type checking without output
- `npm run lint / build / test` — validation gates
- `read_file` — read file before editing
- `multi_replace_string_in_file` — apply multiple fixes in one pass
- `git` — branch, commit, revert

**No external PowerShell scripts required.**
