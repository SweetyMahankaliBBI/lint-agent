<#
.SYNOPSIS
    Parse an ESLint override/suppression file and produce a structured inventory.

.DESCRIPTION
    Reads eslint.config.file-overrides.mjs (flat config style) or .eslintrc overrides
    and extracts every (file, rule) pair being suppressed. Outputs JSON inventory
    with breakdowns by rule, file, and directory.

.PARAMETER OverridePath
    Path to the override file. Auto-detected if omitted.

.PARAMETER OutputPath
    Path to write the JSON inventory. Default: .lint-cleanup/inventory.json

.PARAMETER Format
    Override file format: 'flat' (ESLint 9 flat config) or 'legacy' (.eslintrc).
    Auto-detected from filename if omitted.

.EXAMPLE
    .\override-analyzer.ps1
    .\override-analyzer.ps1 -OverridePath eslint.config.file-overrides.mjs -OutputPath .lint-cleanup/inventory.json
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$OverridePath = '',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = '.lint-cleanup/inventory.json',

    [Parameter(Mandatory = $false)]
    [ValidateSet('flat', 'legacy', 'auto')]
    [string]$Format = 'auto'
)

$ErrorActionPreference = 'Stop'

# --- Auto-detect override file ---
if (-not $OverridePath) {
    $candidates = @(
        'eslint.config.file-overrides.mjs',
        'eslint.config.file-overrides.js',
        'eslint.config.file-overrides.ts',
        '.eslintrc.overrides.json',
        '.eslintrc.overrides.js'
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $OverridePath = $candidate
            break
        }
    }
    if (-not $OverridePath) {
        Write-Error "No override file found. Searched: $($candidates -join ', ')"
        exit 1
    }
}

Write-Host "Override file: $OverridePath" -ForegroundColor Cyan

# --- Detect format ---
if ($Format -eq 'auto') {
    if ($OverridePath -match '\.mjs$|flat') { $Format = 'flat' }
    else { $Format = 'legacy' }
}

# --- Read and parse ---
$content = Get-Content $OverridePath -Raw

# Structures to collect
$overrides = @()  # Each entry: { file, rule }
$fileRules = @{}  # file → [rules]
$ruleFiles = @{}  # rule → [files]
$dirOverrides = @{}  # directory → count

if ($Format -eq 'flat') {
    # Parse flat config format (ESLint 9+)
    # Pattern: { files: ['path/to/file.ts'], rules: { 'rule': 'off' } }
    
    # Extract file blocks using regex
    # Match: files: [...], followed by rules: {...}
    $blockPattern = "files:\s*\[([^\]]+)\][^}]*rules:\s*\{([^}]+)\}"
    $matches = [regex]::Matches($content, $blockPattern)
    
    foreach ($match in $matches) {
        $filesStr = $match.Groups[1].Value
        $rulesStr = $match.Groups[2].Value
        
        # Extract file paths
        $fileMatches = [regex]::Matches($filesStr, "'([^']+)'|""([^""]+)""")
        $files = @()
        foreach ($fm in $fileMatches) {
            $filePath = if ($fm.Groups[1].Value) { $fm.Groups[1].Value } else { $fm.Groups[2].Value }
            $files += $filePath
        }
        
        # Extract rules
        $ruleMatches = [regex]::Matches($rulesStr, "'([^']+)'\s*:\s*'off'|""([^""]+)""\s*:\s*""off""")
        $rules = @()
        foreach ($rm in $ruleMatches) {
            $rule = if ($rm.Groups[1].Value) { $rm.Groups[1].Value } else { $rm.Groups[2].Value }
            $rules += $rule
        }
        
        # Build pairs
        foreach ($file in $files) {
            foreach ($rule in $rules) {
                $overrides += [PSCustomObject]@{ file = $file; rule = $rule }
                
                if (-not $fileRules.ContainsKey($file)) { $fileRules[$file] = @() }
                $fileRules[$file] += $rule
                
                if (-not $ruleFiles.ContainsKey($rule)) { $ruleFiles[$rule] = @() }
                $ruleFiles[$rule] += $file
                
                # Directory tracking
                $dir = Split-Path $file -Parent
                $dir = $dir.Replace('\', '/')
                if (-not $dirOverrides.ContainsKey($dir)) { $dirOverrides[$dir] = 0 }
                $dirOverrides[$dir]++
            }
        }
    }
} else {
    # Parse legacy .eslintrc format
    Write-Host "Legacy format parsing — using JSON structure" -ForegroundColor Yellow
    
    try {
        $eslintrc = $content | ConvertFrom-Json
        if ($eslintrc.overrides) {
            foreach ($override in $eslintrc.overrides) {
                $files = @($override.files)
                $rules = @()
                if ($override.rules) {
                    $override.rules.PSObject.Properties | ForEach-Object {
                        if ($_.Value -eq 'off' -or $_.Value -eq 0) {
                            $rules += $_.Name
                        }
                    }
                }
                
                foreach ($file in $files) {
                    foreach ($rule in $rules) {
                        $overrides += [PSCustomObject]@{ file = $file; rule = $rule }
                        if (-not $fileRules.ContainsKey($file)) { $fileRules[$file] = @() }
                        $fileRules[$file] += $rule
                        if (-not $ruleFiles.ContainsKey($rule)) { $ruleFiles[$rule] = @() }
                        $ruleFiles[$rule] += $file
                    }
                }
            }
        }
    } catch {
        Write-Error "Failed to parse legacy format: $_"
        exit 1
    }
}

# --- Build output ---
$byRule = $ruleFiles.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{
        rule = $_.Key
        count = $_.Value.Count
        files = $_.Value | Sort-Object -Unique
    }
} | Sort-Object -Property count -Descending

$byFile = $fileRules.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{
        file = $_.Key
        count = $_.Value.Count
        rules = $_.Value | Sort-Object -Unique
    }
} | Sort-Object -Property count -Descending

$byDirectory = $dirOverrides.GetEnumerator() | ForEach-Object {
    $dirFiles = $fileRules.Keys | Where-Object { (Split-Path $_ -Parent).Replace('\', '/') -eq $_.Key }
    [PSCustomObject]@{
        dir = $_.Key
        overrides = $_.Value
        files = ($fileRules.Keys | Where-Object { (Split-Path $_ -Parent).Replace('\', '/') -eq $_.Key }).Count
    }
} | Sort-Object -Property overrides -Descending

$output = [PSCustomObject]@{
    generatedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    overrideFile = $OverridePath
    format = $Format
    totalOverrides = $overrides.Count
    totalFiles = $fileRules.Keys.Count
    totalRules = $ruleFiles.Keys.Count
    byRule = $byRule
    byFile = $byFile
    byDirectory = $byDirectory
}

# --- Ensure output directory ---
$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# --- Write output ---
$output | ConvertTo-Json -Depth 5 | Set-Content $OutputPath -Encoding UTF8
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "OVERRIDE ANALYSIS COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total overrides: $($overrides.Count)"
Write-Host "Total files: $($fileRules.Keys.Count)"
Write-Host "Total rules: $($ruleFiles.Keys.Count)"
Write-Host ""
Write-Host "Top 10 rules by count:" -ForegroundColor Yellow
$byRule | Select-Object -First 10 | ForEach-Object {
    Write-Host "  $($_.count.ToString().PadLeft(4)) | $($_.rule)"
}
Write-Host ""
Write-Host "Output: $OutputPath"
