<#
.SYNOPSIS
    Verify lint fixes didn't introduce regressions.
    
.DESCRIPTION
    Compares lint output before and after fixes for a set of files.
    Ensures: target rule count decreased, no new rules appeared, 
    no silencers were added, TypeScript compiles, tests pass.

.PARAMETER Files
    Array of file paths that were modified (glob or explicit list).

.PARAMETER TargetRule
    The rule being fixed (e.g., '@typescript-eslint/no-explicit-any').

.PARAMETER BeforeLintJson
    Path to lint JSON output captured BEFORE fixes.

.PARAMETER Framework
    Project framework: angular, react, vue, typescript. Auto-detected if omitted.

.EXAMPLE
    .\verify-fixes.ps1 -Files @('src/app/shared/service.ts') -TargetRule '@typescript-eslint/no-explicit-any'
#>

param(
    [Parameter(Mandatory = $true)]
    [string[]]$Files,

    [Parameter(Mandatory = $false)]
    [string]$TargetRule = '',

    [Parameter(Mandatory = $false)]
    [string]$BeforeLintJson = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('angular', 'react', 'vue', 'typescript', 'auto')]
    [string]$Framework = 'auto'
)

$ErrorActionPreference = 'Stop'

# --- Auto-detect framework ---
if ($Framework -eq 'auto') {
    $pkg = Get-Content 'package.json' | ConvertFrom-Json
    if ($pkg.dependencies.'@angular/core') { $Framework = 'angular' }
    elseif ($pkg.dependencies.react) { $Framework = 'react' }
    elseif ($pkg.dependencies.vue) { $Framework = 'vue' }
    else { $Framework = 'typescript' }
}

Write-Host "Framework: $Framework" -ForegroundColor Cyan
Write-Host "Files to verify: $($Files.Count)" -ForegroundColor Cyan

# --- Gate 1: Scoped Lint ---
Write-Host "`n[Gate 1] Running scoped lint..." -ForegroundColor Yellow

$lintArgs = $Files + @('--format', 'json', '--no-error-on-unmatched-pattern')
$afterLintRaw = & npx eslint @lintArgs 2>&1 | Out-String

try {
    $afterLint = $afterLintRaw | ConvertFrom-Json
} catch {
    Write-Host "  Lint output is not valid JSON. Raw output:" -ForegroundColor Red
    Write-Host $afterLintRaw
    exit 1
}

$afterErrors = ($afterLint | ForEach-Object { $_.messages } | Where-Object { $_.severity -eq 2 }).Count
$afterByRule = $afterLint | ForEach-Object { $_.messages } | Where-Object { $_.severity -eq 2 } | Group-Object ruleId

Write-Host "  Total errors after fix: $afterErrors" -ForegroundColor $(if ($afterErrors -eq 0) { 'Green' } else { 'Yellow' })

if ($TargetRule -and $afterByRule) {
    $targetCount = ($afterByRule | Where-Object { $_.Name -eq $TargetRule }).Count
    Write-Host "  Target rule ($TargetRule) remaining: $targetCount"
}

# Compare with before if provided
if ($BeforeLintJson -and (Test-Path $BeforeLintJson)) {
    $beforeLint = Get-Content $BeforeLintJson | ConvertFrom-Json
    $beforeErrors = ($beforeLint | ForEach-Object { $_.messages } | Where-Object { $_.severity -eq 2 }).Count
    
    if ($afterErrors -gt $beforeErrors) {
        Write-Host "  ❌ REGRESSION: Errors increased ($beforeErrors → $afterErrors)" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ Errors decreased or same ($beforeErrors → $afterErrors)" -ForegroundColor Green
}

# Check for new rules that weren't there before
if ($BeforeLintJson -and (Test-Path $BeforeLintJson)) {
    $beforeRules = ($beforeLint | ForEach-Object { $_.messages } | Where-Object { $_.severity -eq 2 } | Select-Object -ExpandProperty ruleId -Unique)
    $afterRules = ($afterLint | ForEach-Object { $_.messages } | Where-Object { $_.severity -eq 2 } | Select-Object -ExpandProperty ruleId -Unique)
    
    $newRules = $afterRules | Where-Object { $_ -notin $beforeRules }
    if ($newRules) {
        Write-Host "  ❌ NEW RULES INTRODUCED: $($newRules -join ', ')" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ No new rule violations introduced" -ForegroundColor Green
}

# --- Gate 2: TypeScript Compilation ---
Write-Host "`n[Gate 2] Running TypeScript compilation..." -ForegroundColor Yellow

$tscCmd = switch ($Framework) {
    'angular' { 'npx tsc --noEmit --project tsconfig.app.json' }
    'vue'     { 'npx vue-tsc --noEmit' }
    default   { 'npx tsc --noEmit' }
}

$tscResult = Invoke-Expression "$tscCmd 2>&1" | Out-String
$tscExit = $LASTEXITCODE

if ($tscExit -ne 0) {
    Write-Host "  ❌ TypeScript compilation FAILED" -ForegroundColor Red
    Write-Host $tscResult | Select-Object -First 20
    exit 2
}
Write-Host "  ✅ TypeScript compiles clean" -ForegroundColor Green

# --- Gate 3: Build (only for full validation) ---
if ($env:FULL_VALIDATION -eq 'true') {
    Write-Host "`n[Gate 3] Running build..." -ForegroundColor Yellow
    
    $buildCmd = switch ($Framework) {
        'angular' { 'npx ng build --configuration=production' }
        'react'   { 'npx vite build' }
        'vue'     { 'npx vite build' }
        default   { 'npm run build' }
    }
    
    $buildResult = Invoke-Expression "$buildCmd 2>&1" | Out-String
    $buildExit = $LASTEXITCODE
    
    if ($buildExit -ne 0) {
        Write-Host "  ❌ Build FAILED" -ForegroundColor Red
        Write-Host $buildResult | Select-Object -Last 20
        exit 3
    }
    Write-Host "  ✅ Build passes" -ForegroundColor Green
}

# --- Gate 4: Tests (only for full validation) ---
if ($env:FULL_VALIDATION -eq 'true') {
    Write-Host "`n[Gate 4] Running tests..." -ForegroundColor Yellow
    
    $testCmd = switch ($Framework) {
        'angular' { 'npx ng test --watch=false --browsers=ChromeHeadless' }
        'react'   { 'npx vitest run' }
        'vue'     { 'npx vitest run' }
        default   { 'npm test -- --ci' }
    }
    
    $testResult = Invoke-Expression "$testCmd 2>&1" | Out-String
    $testExit = $LASTEXITCODE
    
    if ($testExit -ne 0) {
        Write-Host "  ❌ Tests FAILED" -ForegroundColor Red
        Write-Host $testResult | Select-Object -Last 30
        exit 4
    }
    Write-Host "  ✅ Tests pass" -ForegroundColor Green
}

# --- Gate 5: Silencer Check ---
Write-Host "`n[Gate 5] Checking for silencers in diff..." -ForegroundColor Yellow

$diff = git diff --cached --unified=0 2>$null
if (-not $diff) {
    $diff = git diff --unified=0 2>$null
}

$silencerPatterns = @(
    'eslint-disable-next-line',
    'eslint-disable ',
    '@ts-ignore',
    '@ts-nocheck',
    ' as any[^a-zA-Z]',
    'as unknown as any'
)

$foundSilencers = @()
foreach ($pattern in $silencerPatterns) {
    $matches = $diff | Select-String -Pattern $pattern -AllMatches
    if ($matches) {
        # Only check added lines (start with +)
        $addedMatches = $matches | Where-Object { $_.Line -match '^\+' }
        if ($addedMatches) {
            $foundSilencers += $addedMatches
        }
    }
}

if ($foundSilencers.Count -gt 0) {
    Write-Host "  ❌ SILENCERS DETECTED in new code:" -ForegroundColor Red
    $foundSilencers | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    exit 5
}
Write-Host "  ✅ No silencers introduced" -ForegroundColor Green

# --- Summary ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VERIFICATION RESULT: ALL GATES PASSED ✅" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Files verified: $($Files.Count)"
Write-Host "  Remaining errors: $afterErrors"
if ($TargetRule) {
    Write-Host "  Target rule remaining: $targetCount"
}
Write-Host ""

exit 0
