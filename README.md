# Engineering Debt Reduction Platform (EDRP)

A standalone, framework-agnostic agent platform for systematically eliminating lint/type debt from any Angular, React, or Vue SPA.

## Quick Start

1. **Open this folder** in VS Code as a workspace (or add to existing workspace)
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

## Architecture

```
┌─────────────────────────────────────────┐
│         Master Orchestrator             │
│        (lint-agent.agent.md)            │
├─────────────────────────────────────────┤
│  Phase 1    Phase 2       Phase 3       │ Phase 4
│  Shared  →  Feature ×N →  Type Migr →  Override Cleanup
│  Worker     Workers       Worker        Worker
└─────────────────────────────────────────┘
         ↓           ↓           ↓
    ┌─────────────────────────────────┐
    │  Validation Gates (every chunk) │
    │  Lint → TSC → Build → Tests    │
    └─────────────────────────────────┘
```

## File Structure

```
lint-agent/
├── lint-agent.agent.md          # Master Orchestrator (entry point)
├── README.md                    # This file
├── skills/
│   └── lint-fixer/
│       └── SKILL.md             # Core playbook (workflow steps)
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
