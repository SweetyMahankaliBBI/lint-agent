# Engineering Debt Reduction Platform - Ultra-Clean Version

**Analyze → Plan → Execute. Zero files. Zero overhead.**

Framework-agnostic lint cleanup for Angular, React, or Vue SPAs.

## What Changed: Old vs New

| Aspect | Old (Complex) | New (Ultra-Clean) |
|--------|---------------|-------------------|
| **Startup** | 30 min | 30 sec |
| **Files Created** | 10-15 tracking files | **0 files** |
| **Instructions** | 500+ lines | 195 lines |
| **Phases** | 3 sequential | 1 direct |
| **Scripts** | 3 PowerShell | 0 needed |

## Setup (One Time)

```powershell
git clone https://github.com/SweetyMahankaliBBI/lint-agent.git c:\Projects\lint-agent
cd c:\Projects\lint-agent
.\setup.ps1
```

After setup, `@lint-agent` is available in Copilot Chat in any workspace.

---

## Quick Start (New Ultra-Clean Version)

**Just say what directory to fix:**

```
User: @lint-agent fix src/app/invoice

Agent: ✅ Branch created
Agent: 🔧 Auto-fixed 67 violations  
Agent: 🔨 Fixing remaining 23 violations...
Agent: ✅ Validated in batches
Agent: ✅ Committed
Agent: 📊 Fixed 90 violations in 24 files
```

**Total time: 2 minutes. Files created: 0.**

---

## Architecture (Simplified)

```
Old (Complex):                    New (Ultra-Clean):
┌─────────────────────┐          ┌──────────────────┐
│ Master Orchestrator │          │  Single Workflow │
├─────────────────────┤          ├──────────────────┤
│ Phase 1: Shared     │          │  1. Create branch│
│ Phase 2: Features   │   →→→    │  2. Autofix      │
│ Phase 3: Type Migr  │          │  3. Manual fix   │
│ Phase 4: Cleanup    │          │  4. Validate     │
└─────────────────────┘          │  5. Commit       │
         ↓                        └──────────────────┘
┌─────────────────────┐
│ Creates 15 files    │          Zero files created
│ 30 min startup      │          30 sec startup
└─────────────────────┘
```

## Quick Start (Old Complex Version - Still Available)

1. **Open your project** in VS Code
2. **Point it at your project:**
   ```
   @lint-agent analyze c:\path\to\your\spa
   ```
3. **Plan the work:**
   ```
   @lint-agent plan --branches 3
   ```
4. **Execute:**
   ```
   @lint-agent execute --branch lint/shared
   ```

## File Structure

### Ultra-Clean Version (Recommended)
```
lint-agent/
├── lint-agent-SIMPLIFIED.agent.md    # NEW: Ultra-clean orchestrator (70 lines)
├── skills/
│   └── lint-fixer/
│       └── SKILL-SIMPLIFIED.md       # NEW: Zero-file workflow (195 lines)
├── SIMPLIFICATION-GUIDE.md           # NEW: Migration guide
├── ULTRA-CLEAN-FLOW.md               # NEW: Execution flow diagram
└── README.md                         # This file
```

**Uses: VS Code + ESLint only. Creates: 0 files.**

### Old Complex Version (Still Available)
```
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
