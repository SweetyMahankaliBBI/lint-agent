<#
.SYNOPSIS
    Partition files from override inventory into file-disjoint branches.

.DESCRIPTION
    Reads the override inventory and partitions files into N branches such that:
    1. No file appears in more than one branch (disjoint guarantee)
    2. Each branch has roughly equal override count (balanced load)
    3. Files in the same directory stay together (locality)
    4. Shared/core files go to a dedicated branch (dependency order)

.PARAMETER InventoryPath
    Path to the inventory JSON (output of override-analyzer.ps1).

.PARAMETER BranchCount
    Number of feature branches to create (default: 3).

.PARAMETER SharedDirs
    Directories that go to the Shared Worker branch (comma-separated).
    Default: 'src/app/shared,src/app/core'

.PARAMETER OutputDir
    Directory to write branch plan files. Default: '.lint-cleanup/'

.EXAMPLE
    .\partition-planner.ps1 -InventoryPath .lint-cleanup/inventory.json -BranchCount 3
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$InventoryPath,

    [Parameter(Mandatory = $false)]
    [int]$BranchCount = 3,

    [Parameter(Mandatory = $false)]
    [string]$SharedDirs = 'src/app/shared,src/app/core',

    [Parameter(Mandatory = $false)]
    [string]$OutputDir = '.lint-cleanup',

    [Parameter(Mandatory = $false)]
    [switch]$TeamMode
)

$ErrorActionPreference = 'Stop'

# --- Load inventory ---
if (-not (Test-Path $InventoryPath)) {
    Write-Error "Inventory file not found: $InventoryPath"
    exit 1
}

$inventory = Get-Content $InventoryPath | ConvertFrom-Json
Write-Host "Loaded inventory: $($inventory.totalFiles) files, $($inventory.totalOverrides) overrides" -ForegroundColor Cyan

# --- Ensure output directory ---
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# --- Separate shared files (Phased Mode only) ---
$sharedDirList = $SharedDirs -split ',' | ForEach-Object { $_.Trim().Replace('\', '/') }

$sharedFiles = @()
$featureFiles = @()

if ($TeamMode) {
    # Team Mode: ALL files go into feature branches (no shared reservation)
    Write-Host "TEAM MODE: No shared phase — all directories distributed evenly" -ForegroundColor Magenta
    $featureFiles = $inventory.byFile
} else {
    foreach ($fileEntry in $inventory.byFile) {
        $filePath = $fileEntry.file.Replace('\', '/')
        $isShared = $false
        
        foreach ($dir in $sharedDirList) {
            if ($filePath.StartsWith($dir)) {
                $isShared = $true
                break
            }
        }
        
        if ($isShared) {
            $sharedFiles += $fileEntry
        } else {
            $featureFiles += $fileEntry
        }
    }
}

Write-Host "Shared files: $($sharedFiles.Count) ($($sharedFiles | Measure-Object -Property count -Sum | Select-Object -ExpandProperty Sum) overrides)" -ForegroundColor Yellow
Write-Host "Feature files: $($featureFiles.Count) ($($featureFiles | Measure-Object -Property count -Sum | Select-Object -ExpandProperty Sum) overrides)" -ForegroundColor Yellow

# --- Group feature files by top-level directory ---
$dirGroups = @{}
foreach ($fileEntry in $featureFiles) {
    $filePath = $fileEntry.file.Replace('\', '/')
    # Get the feature directory (e.g., src/app/creditcard)
    $parts = $filePath -split '/'
    if ($parts.Count -ge 3) {
        $topDir = ($parts[0..2]) -join '/'
    } else {
        $topDir = $filePath
    }
    
    if (-not $dirGroups.ContainsKey($topDir)) {
        $dirGroups[$topDir] = @()
    }
    $dirGroups[$topDir] += $fileEntry
}

Write-Host "Feature directories: $($dirGroups.Keys.Count)" -ForegroundColor Yellow

# --- Greedy bin-packing by directory ---
# Sort directories by total override count (descending)
$sortedDirs = $dirGroups.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{
        Dir = $_.Key
        Files = $_.Value
        TotalOverrides = ($_.Value | Measure-Object -Property count -Sum).Sum
    }
} | Sort-Object -Property TotalOverrides -Descending

# Initialize branches
$branchPrefix = if ($TeamMode) { 'lint/team-' } else { 'lint/feature-' }
$branches = @()
for ($i = 0; $i -lt $BranchCount; $i++) {
    $branches += [PSCustomObject]@{
        Index = $i + 1
        Name = "$branchPrefix$($i + 1)"
        Files = @()
        TotalOverrides = 0
        Directories = @()
    }
}

# Assign directories to the branch with lowest current load
foreach ($dirEntry in $sortedDirs) {
    $minBranch = $branches | Sort-Object -Property TotalOverrides | Select-Object -First 1
    $minBranch.Files += $dirEntry.Files
    $minBranch.TotalOverrides += $dirEntry.TotalOverrides
    $minBranch.Directories += $dirEntry.Dir
}

# --- Write shared branch plan (Phased Mode only) ---
if (-not $TeamMode) {
    $sharedPlan = @{
        branch = 'lint/shared'
        phase = 1
        files = $sharedFiles | ForEach-Object { $_.file }
        totalOverrides = ($sharedFiles | Measure-Object -Property count -Sum).Sum
        directories = $sharedDirList
    }
    $sharedPlanPath = Join-Path $OutputDir 'branch-shared.json'
    $sharedPlan | ConvertTo-Json -Depth 5 | Set-Content $sharedPlanPath
    Write-Host "`nShared branch plan → $sharedPlanPath" -ForegroundColor Green
}

# --- Write feature branch plans ---
$branchPhase = if ($TeamMode) { 'team' } else { 2 }
foreach ($branch in $branches) {
    $plan = @{
        branch = $branch.Name
        phase = $branchPhase
        mode = if ($TeamMode) { 'team' } else { 'phased' }
        files = $branch.Files | ForEach-Object { $_.file }
        totalOverrides = $branch.TotalOverrides
        directories = $branch.Directories
    }
    $planPath = Join-Path $OutputDir "branch-$($branch.Index).json"
    $plan | ConvertTo-Json -Depth 5 | Set-Content $planPath
    Write-Host "Feature branch $($branch.Index) plan → $planPath ($($branch.TotalOverrides) overrides, $($branch.Files.Count) files)" -ForegroundColor Green
}

# --- Write summary ---
$summary = @{
    generatedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    mode = if ($TeamMode) { 'team' } else { 'phased' }
    totalFiles = $inventory.totalFiles
    totalOverrides = $inventory.totalOverrides
    featureBranches = $branches | ForEach-Object {
        @{
            name = $_.Name
            files = $_.Files.Count
            overrides = $_.TotalOverrides
            directories = $_.Directories
        }
    }
}
if (-not $TeamMode) {
    $summary.sharedBranch = @{
        name = 'lint/shared'
        files = $sharedFiles.Count
        overrides = ($sharedFiles | Measure-Object -Property count -Sum).Sum
    }
}
$summaryPath = Join-Path $OutputDir 'partition-summary.json'
$summary | ConvertTo-Json -Depth 5 | Set-Content $summaryPath

# --- Print summary ---
Write-Host "`n========================================" -ForegroundColor Cyan
if ($TeamMode) {
    Write-Host "TEAM MODE PARTITION PLAN GENERATED" -ForegroundColor Green
} else {
    Write-Host "PARTITION PLAN GENERATED" -ForegroundColor Green
}
Write-Host "========================================" -ForegroundColor Cyan
if (-not $TeamMode) {
    Write-Host "Shared: $($sharedFiles.Count) files, $(($sharedFiles | Measure-Object -Property count -Sum).Sum) overrides"
}
foreach ($branch in $branches) {
    Write-Host "Branch $($branch.Index): $($branch.Files.Count) files, $($branch.TotalOverrides) overrides"
    foreach ($dir in $branch.Directories) {
        Write-Host "  - $dir"
    }
}
Write-Host "`nDisjoint guarantee: ✅ (each file in exactly one branch)"
if ($TeamMode) {
    Write-Host "Mode: TEAM (no shared phase, override cleanup at end)" -ForegroundColor Magenta
    Write-Host "Next: Each person runs '@lint-agent execute --branch lint/team-N'" -ForegroundColor Yellow
    Write-Host "Final: One person runs '@lint-agent execute --branch lint/override-cleanup'" -ForegroundColor Yellow
}
Write-Host "Plans written to: $OutputDir/"
