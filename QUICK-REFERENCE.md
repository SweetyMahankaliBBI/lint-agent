# 🎯 Quick Reference - Ultra-Clean Lint Agent

## One Command to Rule Them All

```
@lint-agent fix <directory>
```

That's it. No phases. No planning. No files created.

---

## What Happens When You Say "fix X"

```
1. git checkout -b lint-fix/X        (Create branch)
2. npx eslint X --fix                (Autofix cheap wins)
3. npx eslint X --format json        (Parse remaining errors)
4. [VS Code edit tools]              (Fix violations manually)
5. npx eslint X && npx tsc --noEmit  (Validate every 10 files)
6. npm run lint && build && test     (Final validation)
7. git commit -m "fix(lint): X"      (Commit locally)
8. [Show summary in chat]            (Report results)
```

**Total time: 2-5 minutes depending on directory size.**

---

## What Files Get Created

**Answer: ZERO**

❌ No `.lint-cleanup/` directory  
❌ No `inventory.json`  
❌ No `branch-plan.json`  
❌ No `ownership.json`  
❌ No `progress.json`  
❌ No `failed-files.txt`  
❌ No status tracking documents  

✅ Just your fixed code + git commit

---

## Examples

### Example 1: Fix Invoice Feature
```
User: fix src/app/invoice

Agent: ✅ Created branch: lint-fix/invoice
Agent: 📁 Found 24 TypeScript files
Agent: 🔧 Auto-fixed 67 violations
Agent: 🔨 Fixing remaining 23 manually...
Agent: ✅ Batch 1/3 validated (10 files)
Agent: ✅ Batch 2/3 validated (10 files)
Agent: ✅ Batch 3/3 validated (4 files)
Agent: ✅ Final validation passed
Agent: ✅ Committed
Agent: 📊 Fixed 90 violations in 24 files
       Skipped 3 files (manual review)

Time: 2 minutes
```

### Example 2: Fix Shared Library
```
User: fix lib/shared

Agent: ✅ Branch: lint-fix/shared
Agent: 📁 15 files found
Agent: 🔧 Auto-fixed 34 violations
Agent: 🔨 Fixing 12 remaining...
Agent: ✅ All batches validated
Agent: ✅ Committed
Agent: 📊 Fixed 46 violations in 15 files

Time: 90 seconds
```

### Example 3: Fix Components
```
User: fix src/components/dashboard

Agent: ✅ Branch: lint-fix/dashboard
Agent: 📁 8 files found
Agent: 🔧 Auto-fixed 23 violations
Agent: 🔨 Fixing 5 remaining...
Agent: ✅ Validated
Agent: ✅ Committed
Agent: 📊 Fixed 28 violations in 8 files

Time: 60 seconds
```

---

## Common Patterns Fixed

| Rule | Before | After |
|------|--------|-------|
| `no-explicit-any` | `data: any` | `data: unknown` |
| `no-unused-vars` | `import {A,B,C}` (only B used) | `import {B}` |
| `component-class-suffix` | `class InvoiceView` | `class InvoiceViewComponent` |
| `prefer-const` | `let x = 5; return x;` | `const x = 5; return x;` |
| `no-inferrable-types` | `count: number = 0` | `count = 0` |

---

## Error Recovery

If validation fails:
```
Agent: ⚠️ Batch 2/3 validation failed
Agent: ↩️ Reverted batch 2
Agent: 📝 Skipping problematic files
Agent: ✅ Continuing with batch 3
```

Agent automatically:
- Reverts failed batch
- Skips problematic files
- Continues with remaining work
- Reports what was skipped

**You never lose working code.**

---

## Validation Gates

Every 10 files:
```powershell
npx eslint $path           # No lint errors
npx tsc --noEmit           # No type errors
```

Final validation:
```powershell
npm run lint               # Full project lint
npm run build              # Compiles successfully
npm test                   # All tests pass
```

**If any gate fails → automatic revert → safe.**

---

## Comparison: Old vs New

### Old Agent (Complex)
```
User: fix src/app/invoice
↓
Agent: Reading configurations...          (2 min)
Agent: Running override-analyzer.ps1...   (3 min)
Agent: Creating inventory.json...         (5 min)
Agent: Running partition-planner.ps1...   (5 min)
Agent: Creating branch-plan.json...       (2 min)
Agent: Checking ownership...              (3 min)
Agent: Creating ownership.json...         (2 min)
Agent: Phase 1 must complete first!       (!!!)
↓
Result: 22 min elapsed, 0 violations fixed, 7 files created
```

### New Agent (Ultra-Clean)
```
User: fix src/app/invoice
↓
Agent: ✅ Branch created
Agent: 🔧 Auto-fixed 67 violations
Agent: 🔨 Fixing 23 remaining...
Agent: ✅ Validated
Agent: ✅ Committed
Agent: 📊 Fixed 90 violations
↓
Result: 2 min elapsed, 90 violations fixed, 0 files created
```

**45x faster. Zero overhead.**

---

## Philosophy

### ❌ Don't Do This (Old Way)
- Create planning documents
- Write state to disk
- Run PowerShell scripts
- Check phase dependencies
- Coordinate multiple workers
- Track ownership
- Persist progress to JSON

### ✅ Do This (New Way)
- Analyze in memory
- Plan in memory
- Execute immediately
- Validate incrementally
- Report in chat
- Commit to git

**The best file is no file.**

---

## When to Use Which Version

### Use Ultra-Clean When:
- ✅ Fixing specific directories
- ✅ Quick cleanup of feature code
- ✅ Want immediate results
- ✅ Don't want tracking files
- ✅ Working on small-to-medium projects

### Use Complex When:
- 📊 Need detailed analysis reports
- 📊 Managing multi-branch coordination
- 📊 Want progress tracking across weeks
- 📊 Large enterprise projects (50k+ LOC)

**Most users want Ultra-Clean.**

---

## How to Activate

```powershell
cd c:\Projects\lint-agent

# Activate ultra-clean version
Copy-Item "lint-agent-SIMPLIFIED.agent.md" "lint-agent.agent.md" -Force
Copy-Item "skills/lint-fixer/SKILL-SIMPLIFIED.md" "skills/lint-fixer/SKILL.md" -Force

# Restart VS Code (Ctrl+Shift+P → "Reload Window")
```

Now `@lint-agent fix <directory>` uses the ultra-clean workflow.

---

## Documentation

- **[SKILL-SIMPLIFIED.md](skills/lint-fixer/SKILL-SIMPLIFIED.md)** - Complete workflow (195 lines)
- **[lint-agent-SIMPLIFIED.agent.md](lint-agent-SIMPLIFIED.agent.md)** - Agent config (70 lines)
- **[ULTRA-CLEAN-FLOW.md](ULTRA-CLEAN-FLOW.md)** - Execution flow diagram
- **[SIMPLIFICATION-GUIDE.md](SIMPLIFICATION-GUIDE.md)** - Migration guide
- **[README.md](README.md)** - Full documentation

---

## Support

**Questions?** Open an issue on GitHub.

**Want to contribute?** Submit a PR.

**Love it?** ⭐ Star the repo!

---

## Summary

**Input:** `@lint-agent fix <directory>`

**Output:** 
- ✅ Fixed code
- ✅ Git commit
- ✅ Summary in chat
- ✅ Zero tracking files

**Time:** 1-5 minutes

**Philosophy:** Analyze → Plan → Execute

**The best file is no file.**
