#requires -Version 5.1
<#
.SYNOPSIS
    react-verify's gate -- runs typecheck and diff-scoped lint; prints the
    pass/fail table sdlc-verify's OUTPUT CONTRACT expects verbatim.

.DESCRIPTION
    Runs exactly two commands, in this fixed order, and never claims one
    passed unless it actually executed:
      1. npx tsc --noEmit
      2. npx eslint <diff paths>   (full-repo flat config, file list scoped)

    A production bundler build is deliberately NOT part of this gate: it is
    the slowest available check, it re-runs on every fix cycle, and it mostly
    re-proves what tsc already established. The release path still bundles
    (react-ship's container build), so a broken build fails at ship rather
    than escaping entirely. Run the build by hand when the diff touches
    bundler config, tsconfig paths/aliases, asset imports, or env-var reads --
    typecheck cannot speak to those. See react-verify's SKILL.md.

    Illustrative timings on a mid-sized project (ASSUMPTION: not re-timed
    against your project -- measure your own numbers on first run and use
    those as your baseline): typecheck ~10-15s, lint ~20-30s.
    Lint is the slow one because ESLint's flat config is loaded in full
    regardless of how few files are in the diff list -- scoping the FILE list
    does not scope the CONFIG load.

    This script does not retry or auto-fix anything. sdlc-verify (the agent)
    owns the 2-fix-cycle budget and decides whether to re-invoke this script
    after a fix; this script's job is to run once, honestly, and report.

.PARAMETER DiffPaths
    Explicit list of changed .ts/.tsx files to lint. If omitted, the script
    computes it from `git diff --name-only` against HEAD plus any staged
    changes, filtered to *.ts/*.tsx under src/.

.PARAMETER BaseRef
    Git ref to diff against when -DiffPaths is not supplied. Default: HEAD.

.EXAMPLE
    ./gate.ps1
    ./gate.ps1 -DiffPaths src/features/products/api/products.queries.ts
#>
param(
    [string[]]$DiffPaths,
    [string]$BaseRef = 'HEAD'
)

$ErrorActionPreference = 'Stop'
$results = New-Object System.Collections.Generic.List[object]

function Invoke-GateCommand {
    param(
        [string]$Check,
        [string]$CommandDisplay,
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host "-- $Check ------------------------------------------" -ForegroundColor Cyan
    Write-Host "> $CommandDisplay"

    # NOTE (Windows PowerShell 5.1 specifically, not pwsh 7+): merging a
    # native exe's stderr with 2>&1 wraps each stderr line in a
    # NativeCommandError record rather than plain text, and can flip $? to
    # $false even on a true success. $LASTEXITCODE is unaffected by this -- it
    # is set from the process's actual exit code regardless of how stdout/
    # stderr were merged -- so exit-code detection below is reliable even if
    # the printed output looks noisier under 5.1 than under pwsh 7.
    $output = & $Action 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }

    $status = 'FAIL'
    if ($exitCode -eq 0) { $status = 'PASS' }

    $results.Add([pscustomobject]@{
        Check    = $Check
        Command  = $CommandDisplay
        ExitCode = $exitCode
        Result   = $status
        Output   = $output
    })

    return $status
}

function Add-NotRun {
    param([string]$Check, [string]$CommandDisplay, [string]$Reason)

    Write-Host ""
    Write-Host "-- $Check ------------------------------------------" -ForegroundColor Yellow
    Write-Host "NOT RUN: $Reason" -ForegroundColor Yellow

    $results.Add([pscustomobject]@{
        Check    = $Check
        Command  = $CommandDisplay
        ExitCode = 'n/a'
        Result   = 'NOT RUN'
        Output   = @($Reason)
    })
}

# -- Pre-flight: confirm each command actually exists before claiming to run it --
$hasPackageJson = Test-Path 'package.json'
$hasNpx = $null -ne (Get-Command npx -ErrorAction SilentlyContinue)

# -- 1. typecheck ----------------------------------------------------------
if (-not $hasPackageJson) {
    Add-NotRun -Check 'typecheck' -CommandDisplay 'npx tsc --noEmit' -Reason 'no package.json in current directory'
}
elseif (-not $hasNpx) {
    Add-NotRun -Check 'typecheck' -CommandDisplay 'npx tsc --noEmit' -Reason 'npx not found on PATH'
}
else {
    Invoke-GateCommand -Check 'typecheck' -CommandDisplay 'npx tsc --noEmit' -Action {
        npx tsc --noEmit
    } | Out-Null
}

# -- 2. lint (diff-scoped file list, full-repo config) --------------------
if ($DiffPaths) {
    $files = $DiffPaths
}
else {
    $unstaged = git diff --name-only --diff-filter=ACMR $BaseRef 2>$null
    $staged = git diff --name-only --diff-filter=ACMR --cached 2>$null
    $files = @($unstaged) + @($staged) |
        Where-Object { $_ -match '\.(ts|tsx)$' } |
        Where-Object { Test-Path $_ } |
        Select-Object -Unique
}

if (-not $hasNpx) {
    Add-NotRun -Check 'lint' -CommandDisplay 'npx eslint <diff paths>' -Reason 'npx not found on PATH'
}
elseif (-not (Test-Path 'eslint.config.js')) {
    Add-NotRun -Check 'lint' -CommandDisplay 'npx eslint <diff paths>' -Reason 'no eslint.config.js -- run react-sdlc:react-bootstrap first'
}
elseif (-not $files -or $files.Count -eq 0) {
    Add-NotRun -Check 'lint' -CommandDisplay 'npx eslint <diff paths>' -Reason 'diff contains no .ts/.tsx files to lint'
}
else {
    $displayCmd = 'npx eslint ' + ($files -join ' ')
    Invoke-GateCommand -Check 'lint' -CommandDisplay $displayCmd -Action {
        npx eslint @files
    } | Out-Null
}

# -- No build step by design ----------------------------------------------
# A production bundler build is deliberately not part of this gate: slowest
# check available, re-runs every fix cycle, and largely re-proves what tsc
# already established. react-ship's container build still bundles before
# anything reaches an environment, so a broken build fails at ship rather
# than escaping. Run `npm run build` by hand when the diff touches bundler
# config, tsconfig paths/aliases, asset imports, or env-var reads -- tsc
# cannot speak to those. Rationale in react-verify's SKILL.md.

# -- Report -- matches sdlc-verify's OUTPUT CONTRACT table exactly ---------
Write-Host ""
Write-Host "## Gate results"
Write-Host "| Check | Command | Exit code | Result |"
Write-Host "|---|---|---|---|"
foreach ($r in $results) {
    Write-Host "| $($r.Check) | $($r.Command) | $($r.ExitCode) | $($r.Result) |"
}

$failing = $results | Where-Object { $_.Result -eq 'FAIL' }
if ($failing) {
    Write-Host ""
    Write-Host "## Failing lines (verbatim)"
    foreach ($f in $failing) {
        # Print only lines that look like a compiler/linter/bundler error --
        # not the full log. This is a heuristic grep, not a guarantee every
        # tool's error format is caught; if nothing matches, the full
        # captured output for that check is still in $results for a human to
        # inspect directly (this script does not truncate what it captured,
        # only what it prints by default).
        $f.Output | Select-String -Pattern 'error|Error|ERROR' | ForEach-Object { Write-Host $_.Line }
    }
    Write-Host ""
    $firstFail = $failing[0].Check
    Write-Host "GATE-FAIL: $firstFail"
    exit 1
}
else {
    Write-Host ""
    Write-Host "GATE-PASS"
    exit 0
}
