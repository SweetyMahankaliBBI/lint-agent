# Lint Agent

> Systematically fix ESLint violations with safety checks and validation at every step.

Framework-agnostic lint cleanup for Angular, React, Vue, or any TypeScript/JavaScript project.

---

## 🎯 Purpose

This agent automates ESLint violation fixes in large codebases by:
- Processing violations systematically (by rule type or file)
- Running tests after each fix to ensure nothing breaks
- Providing detailed progress reports
- Skipping complex violations that require manual review

**Ultimate Goal:** Remove or minimize override files by fixing all lint violations and enabling strict linting.

---

## 📋 Prerequisites

Before using this agent, ensure:
- ✅ Git working directory is clean (commit or stash changes)
- ✅ All tests are passing (`npm test`)
- ✅ Dependencies are installed (`npm install`)
- ✅ You have a backup or can easily revert changes

---

## 🚀 Quick Start

### Analyze Current State

```
@lint-agent analyze
```

This shows:
- Total errors and warnings
- Top violation types by frequency
- Recommended fix order by priority
- Estimated time per category

### Fix All Violations (Recommended)

```
@lint-agent fix-all
```

This will:
1. Process violations in priority order (safest first)
2. Run tests after each fix batch
3. Skip violations that cause test failures
4. Provide a detailed summary report

### Fix Specific Violation Type

```
@lint-agent fix-type @typescript-eslint/no-unused-vars
@lint-agent fix-type @typescript-eslint/no-explicit-any
```

Useful when you want to focus on one specific type of violation.

### Fix All Violations in a File

```
@lint-agent fix-file src/app/invoice/invoice.component.ts
@lint-agent fix-file invoice.component.ts
```

This will fix all violations in the specified file (all rule types), useful when:
- You want to clean up a specific file completely
- You're working on a file and want to resolve all its violations
- You need to ensure a specific file has no lint issues

---

## 📁 File Structure

```
lint-agent/
├── README.md                    # This file
├── lint-agent.agent.md         # Agent orchestrator (main file)
├── QUICK-REFERENCE.md          # One-page cheat sheet
├── skills/
│   └── lint-fixer/
│       └── SKILL.md            # Detailed workflow and fix patterns
└── references/
    ├── rule-patterns.md        # Fix patterns for each rule
    └── session-lessons.md      # Lessons learned
```

---

## 🎯 Fix Priority Order

| Priority | Rule                                   | Time  | Risk |
| -------- | -------------------------------------- | ----- | ---- |
| 1️⃣       | @typescript-eslint/no-unused-vars      | 30min | Low  |
| 1️⃣       | id-denylist                            | 5min  | Low  |
| 1️⃣       | explicit-member-accessibility          | 15min | Low  |
| 2️⃣       | @typescript-eslint/no-explicit-any     | 2h    | Med  |
| 2️⃣       | explicit-module-boundary-types         | 1h    | Med  |
| 3️⃣       | @angular-eslint/prefer-inject          | 1h    | Med  |
| 3️⃣       | prefer-optional-chain                  | 30min | Low  |
| 4️⃣       | @typescript-eslint/no-deprecated       | 2h    | High |

---

## ✅ Key Features

### Zero File Creation
- No tracking files, planning documents, or status logs
- Only creates code fixes and git commits
- Everything reported in chat

### Automatic Validation
- Validates every 10 files during fixing
- Runs full test suite before committing
- Reverts immediately on any failure

### Safety First
- Never suppresses rules with eslint-disable
- Never commits code that breaks tests
- Never pushes without user review

### Smart Batching
- Processes files in batches of 10
- Validates each batch independently
- Skips problematic files automatically

---

## 📊 Example Session

```
User: @lint-agent fix-type @typescript-eslint/no-unused-vars

Agent: ✅ Created branch: lint-fix/no-unused-vars
Agent: 🔧 Running eslint --fix...
Agent: ✅ Auto-fixed 45 violations
Agent: 🔨 Manually fixing remaining 12 violations...
       Batch 1/2: 10 files...
Agent: ✅ Validated batch 1/2
       Batch 2/2: 2 files...
Agent: ✅ Validated batch 2/2
Agent: ✅ Final validation: lint ✓ build ✓ tests ✓
Agent: ✅ Regenerated override file
Agent: ✅ Committed locally
Agent: 📊 Fixed 57 violations in 24 files

Ready to review and push.
```

---

## 🔧 Common Fix Patterns

### Remove Unused Variables
```typescript
// ❌ Before
import { Foo, Bar } from './types';

// ✅ After
import { Foo } from './types';
```

### Replace Any with Proper Types
```typescript
// ❌ Before
function process(data: any) { }

// ✅ After
function process(data: unknown) {
  if (typeof data === 'object' && data !== null) {
    // Type guard
  }
}
```

### Add Access Modifiers
```typescript
// ❌ Before
class MyComponent {
  name: string;
}

// ✅ After
class MyComponent {
  public name: string;
}
```

See [QUICK-REFERENCE.md](QUICK-REFERENCE.md) for more patterns.

---

## 🚨 Safety Rules

### ✅ Always
- Validate every 10 files during manual fixes
- Run full validation (lint + build + test) before committing
- Revert immediately on any validation failure
- Fix or skip violations — never suppress rules

### ❌ Never
- Add new rules to override files (only remove as fixed)
- Commit code that breaks tests or builds
- Batch more than 10 files without validation
- Push changes without user review

---

## 📚 Documentation

- **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** - One-page cheat sheet
- **[skills/lint-fixer/SKILL.md](skills/lint-fixer/SKILL.md)** - Detailed workflow
- **[references/rule-patterns.md](references/rule-patterns.md)** - Fix patterns for each rule

---

## 🎯 Core Principles

1. **Zero files created** - Only code fixes and git commits
2. **Validate often** - Every 10 files during manual fixes
3. **Fail fast** - Revert immediately on any error
4. **Never suppress** - Fix or skip, never disable rules
5. **User controls push** - Agent commits locally, user reviews and pushes
lint-agent/
├── lint-agent.agent.md          # Master Orchestrator (complex)
├── skills/
│   └── lint-fixer/
│       └── SKILL.md             # Core playbook (500+ lines)
├── workers/
│   ├── shared-worker.md         # Phase 1: shared/core code
│   ├── feature-worker.md        # Phase 2: feature directories
│   ├── type-migration.md        # Phase 3: hard any→typed cases
│   ├── override-cleanup.md      # Phase 4: remove cleared suppressions
│   └── validation.md            # Reusable gate definitions
└── references/
    ├── rule-patterns.md         # Per-rule fix patterns (P1–P5)
    ├── verify-fixes.ps1         # Regression detection script
    ├── partition-planner.ps1    # File-disjoint branch partitioner
    └── override-analyzer.ps1   # Override file parser
```

**Uses: 3 PowerShell scripts, 4 worker types. Creates: 10-15 tracking files.**

---

## 🔄 How to Switch Versions

### Switch to Ultra-Clean (Recommended)
```powershell
# Backup current version
Copy-Item "lint-agent.agent.md" "lint-agent.agent.md.OLD" -Force
Copy-Item "skills/lint-fixer/SKILL.md" "skills/lint-fixer/SKILL.OLD.md" -Force

# Activate ultra-clean version
Copy-Item "lint-agent-SIMPLIFIED.agent.md" "lint-agent.agent.md" -Force
Copy-Item "skills/lint-fixer/SKILL-SIMPLIFIED.md" "skills/lint-fixer/SKILL.md" -Force

# Restart Copilot (Ctrl+Shift+P → "Reload Window")
```

### Switch Back to Complex Version
```powershell
# Restore from backup
Copy-Item "lint-agent.agent.md.OLD" "lint-agent.agent.md" -Force
Copy-Item "skills/lint-fixer/SKILL.OLD.md" "skills/lint-fixer/SKILL.md" -Force

# Restart Copilot
```

### Use Both Side-by-Side
Keep both available:
- Complex: `@lint-agent` (for full project analysis)
- Ultra-clean: Load simplified files manually when needed

---

## Supported Frameworks

| Framework | Detected By | Lint | TypeCheck | Build | Test |
|-----------|-------------|------|-----------|-------|------|
| Angular | `@angular/core` in deps | `npx eslint` | `tsc --noEmit -p tsconfig.app.json` | `ng build` | `ng test --watch=false` |
| React | `react` in deps | `npx eslint` | `tsc --noEmit` | `vite build` | `vitest run` |
| Vue | `vue` in deps | `npx eslint` | `vue-tsc --noEmit` | `vite build` | `vitest run` |
| TypeScript | fallback | `npx eslint` | `tsc --noEmit` | `npm run build` | `npm test` |

## Operating Modes

| Mode | Command | What It Does |
|------|---------|--------------|
| **Analyze** | `@lint-agent analyze <path>` | Parse overrides, count debt, show top rules |
| **Plan** | `@lint-agent plan --branches N` | Partition files into disjoint branches |
| **Execute** | `@lint-agent execute --branch <name>` | Fix one branch (shared/feature/type/cleanup) |
| **Status** | `@lint-agent status` | Show progress across all branches |
| **CodeRabbit** | `@lint-agent coderabbit <pr-url>` | Address reviewer comments on a lint PR |

## Key Principles

1. **File-disjoint partitioning** — No file appears in two branches → zero merge conflicts
2. **Phase ordering** — Shared → Features → Types → Cleanup (never out of order)
3. **Validation after every chunk** — 5 files then verify, never batch-and-pray
4. **No silencers** — Never introduce `eslint-disable`, `@ts-ignore`, or `as any`
5. **No behavior changes** — Lint fixes are compile-time only
6. **Ownership tracking** — `ownership.json` prevents two workers editing same file
7. **Resumable** — Interrupted sessions continue from last verified chunk

## Usage Examples

### Full Cleanup (3-day plan)
```
@lint-agent analyze c:\Projects\code\skyux-spa-expenses
@lint-agent plan --branches 3
@lint-agent execute --branch lint/shared       # Day 1 morning
@lint-agent execute --branch lint/feature-1    # Day 1 afternoon
@lint-agent execute --branch lint/feature-2    # Day 2 morning
@lint-agent execute --branch lint/feature-3    # Day 2 afternoon
@lint-agent execute --branch lint/type-migration   # Day 3 morning
@lint-agent execute --branch lint/override-cleanup # Day 3 afternoon
```

### Quick Single-Rule Fix
```
@lint-agent execute --branch lint/shared --rule prefer-const
```

### Check Progress
```
@lint-agent status
```

## Requirements

- VS Code with GitHub Copilot
- Node.js 18+
- Git
- Project with ESLint configured
- Override/suppression file (or inline eslint-disable comments)

## Configuration

No config file needed. The agent auto-detects:
- Framework (from package.json)
- Package manager (from lockfile)
- Override file (from filesystem scan)
- Test runner (from scripts or dependencies)

## Safety

- **Never pushes** without explicit user approval
- **Never force-pushes** (ever)
- **Reverts failed chunks** automatically
- **Logs everything** to `.lint-cleanup/` for auditability
- **Respects ownership** — won't touch files claimed by another worker

## Feedback

Try it on your feature area and let us know:
- Does it work on your folder?
- Any rules it handles incorrectly?
- Suggestions for improvement?

Open an [Issue](https://github.com/SweetyMahankaliBBI/lint-agent/issues) or submit a PR.
