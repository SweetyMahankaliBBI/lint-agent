<#
.SYNOPSIS
    Install the Lint Agent (EDRP) for VS Code Copilot.

.DESCRIPTION
    Sets up the Engineering Debt Reduction Platform agent so it appears
    in the VS Code Copilot agent picker across all workspaces.

    What it does:
    1. Copies lint-agent folder to C:\Projects\lint-agent (or custom path)
    2. Creates the agent file in VS Code user prompts folder
    3. Verifies installation

.PARAMETER InstallPath
    Where to install the lint-agent platform. Default: C:\Projects\lint-agent

.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -InstallPath "D:\tools\lint-agent"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$InstallPath = 'C:\Projects\lint-agent'
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  EDRP — Lint Agent Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Copy platform files ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($scriptDir -ne $InstallPath) {
    Write-Host "[1/3] Installing platform to $InstallPath..." -ForegroundColor Yellow
    
    if (Test-Path $InstallPath) {
        Write-Host "      Target exists. Updating..." -ForegroundColor Gray
        Copy-Item -Path "$scriptDir\*" -Destination $InstallPath -Recurse -Force -Exclude 'setup.ps1'
    } else {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        Copy-Item -Path "$scriptDir\*" -Destination $InstallPath -Recurse -Force
    }
    Write-Host "      ✅ Platform installed at: $InstallPath" -ForegroundColor Green
} else {
    Write-Host "[1/3] Platform already at $InstallPath ✅" -ForegroundColor Green
}

# --- Step 2: Create agent in VS Code user prompts ---
Write-Host "[2/3] Registering agent in VS Code..." -ForegroundColor Yellow

$vsCodePromptsDir = Join-Path $env:APPDATA 'Code\User\prompts'

if (-not (Test-Path $vsCodePromptsDir)) {
    New-Item -ItemType Directory -Path $vsCodePromptsDir -Force | Out-Null
    Write-Host "      Created prompts folder: $vsCodePromptsDir" -ForegroundColor Gray
}

$agentContent = @'
---
description: "Engineering Debt Reduction Platform — Scans any Angular/React/Vue SPA, partitions lint debt into file-disjoint branches, fixes by priority, validates everything, opens PRs. Works from any workspace."
tools: ['edit', 'execute/runInTerminal', 'execute/getTerminalOutput', 'read/terminalLastCommand', 'read/terminalSelection', 'read/problems', 'search/usages', 'search/changes', 'execute/testFailure', 'execute/createAndRunTask', 'todo', 'web/fetch']
---

# Lint Agent — Engineering Debt Reduction Platform

You are the Master Orchestrator of the Engineering Debt Reduction Platform (EDRP). You scan repositories, plan work, fix lint debt systematically, validate everything, and open PRs. You work on whatever SPA the user points you at.

**AGENT_HOME:** `INSTALL_PATH_PLACEHOLDER`

**On session start:** Read these files for full instructions:
1. `INSTALL_PATH_PLACEHOLDER\skills\lint-fixer\SKILL.md` — Core playbook
2. `INSTALL_PATH_PLACEHOLDER\workers\validation.md` — Validation gates
3. `INSTALL_PATH_PLACEHOLDER\references\rule-patterns.md` — Per-rule fix patterns

**On demand (read when needed):**
- `INSTALL_PATH_PLACEHOLDER\workers\shared-worker.md` — Phase 1
- `INSTALL_PATH_PLACEHOLDER\workers\feature-worker.md` — Phase 2
- `INSTALL_PATH_PLACEHOLDER\workers\type-migration.md` — Phase 3
- `INSTALL_PATH_PLACEHOLDER\workers\override-cleanup.md` — Phase 4

---

## Commands

| Command | Action |
|---------|--------|
| `analyze` | Scan current workspace, parse overrides, show debt |
| `plan --branches N` | Partition into N file-disjoint branches |
| `execute --phase 1` | Run Shared Worker (shared/core, runs first) |
| `execute --branch N` | Run Feature Worker for branch N |
| `execute --phase 3` | Run Type Migration |
| `execute --phase 4` | Run Override Cleanup (runs last) |
| `status` | Progress across all branches |
| `coderabbit <PR#>` | Fix reviewer comments |

---

## How It Works

```
Phase 1: SHARED (alone) → Phase 2: FEATURES (parallel) → Phase 3: TYPES → Phase 4: CLEANUP
```

- File-disjoint partitioning → zero merge conflicts
- Validation every 5 files → lint + tsc + build + tests
- Never silences rules → no eslint-disable, @ts-ignore, as any
- Never pushes without asking

---

## Framework Auto-Detection

| Signal | Framework | Lint | Build | Test |
|--------|-----------|------|-------|------|
| `@angular/core` | Angular | `npx eslint` | `ng build` | `ng test --watch=false` |
| `react` | React | `npx eslint` | `vite build` | `vitest run` |
| `vue` | Vue | `npx eslint` | `vite build` | `vitest run` |

---

## Hard Rules

1. Never silence — No eslint-disable, @ts-ignore, as any
2. Never break ownership — Check .lint-cleanup/ownership.json
3. Never skip validation — Every 5 files must pass all gates
4. Never auto-push — Always ask user first
5. Never modify lint config — Fix code, not rules
6. Shared first, cleanup last

---

## Scripts

```powershell
# Analyze overrides
& "INSTALL_PATH_PLACEHOLDER\references\override-analyzer.ps1"

# Plan branches
& "INSTALL_PATH_PLACEHOLDER\references\partition-planner.ps1" -InventoryPath .lint-cleanup/inventory.json -BranchCount 3

# Verify fixes
& "INSTALL_PATH_PLACEHOLDER\references\verify-fixes.ps1" -Files @('src/app/file.ts')
```
'@

# Replace placeholder with actual install path
$agentContent = $agentContent -replace 'INSTALL_PATH_PLACEHOLDER', $InstallPath

$agentFile = Join-Path $vsCodePromptsDir 'Lint Agent.agent.md'
Set-Content -Path $agentFile -Value $agentContent -Encoding UTF8
Write-Host "      ✅ Agent registered: $agentFile" -ForegroundColor Green

# --- Step 3: Verify ---
Write-Host "[3/3] Verifying installation..." -ForegroundColor Yellow

$checks = @(
    @{ Path = "$InstallPath\skills\lint-fixer\SKILL.md"; Name = "Core playbook" },
    @{ Path = "$InstallPath\workers\validation.md"; Name = "Validation gates" },
    @{ Path = "$InstallPath\workers\shared-worker.md"; Name = "Shared Worker" },
    @{ Path = "$InstallPath\workers\feature-worker.md"; Name = "Feature Worker" },
    @{ Path = "$InstallPath\references\fix-recipes.md"; Name = "Fix recipes" },
    @{ Path = "$InstallPath\references\verify-fixes.ps1"; Name = "Verify script" },
    @{ Path = "$InstallPath\references\partition-planner.ps1"; Name = "Partition planner" },
    @{ Path = "$InstallPath\references\override-analyzer.ps1"; Name = "Override analyzer" },
    @{ Path = $agentFile; Name = "VS Code agent file" }
)

$allGood = $true
foreach ($check in $checks) {
    if (Test-Path $check.Path) {
        Write-Host "      ✅ $($check.Name)" -ForegroundColor Green
    } else {
        Write-Host "      ❌ MISSING: $($check.Name) ($($check.Path))" -ForegroundColor Red
        $allGood = $false
    }
}

# --- Done ---
Write-Host ""
if ($allGood) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ✅ SETUP COMPLETE" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor White
    Write-Host "  1. Reload VS Code (Ctrl+Shift+P → 'Reload Window')" -ForegroundColor White
    Write-Host "  2. Open any SPA project" -ForegroundColor White
    Write-Host "  3. Type @Lint Agent in Copilot chat" -ForegroundColor White
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Cyan
    Write-Host "    @Lint Agent analyze" -ForegroundColor Gray
    Write-Host "    @Lint Agent plan --branches 3" -ForegroundColor Gray
    Write-Host "    @Lint Agent execute --phase 1" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ⚠️  SETUP INCOMPLETE — Missing files" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Re-run setup or check the install path." -ForegroundColor White
}
