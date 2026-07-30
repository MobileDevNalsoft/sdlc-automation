#requires -Version 5.1
<#
.SYNOPSIS
    dependency-audit's runner. Decides whether the check should fire at all,
    runs the ecosystem's audit tool, applies expiring suppressions, and emits
    a four-state gate row.

.DESCRIPTION
    Tier 2 (conditional): by default this only audits when the diff touches a
    dependency-defining file -- a manifest, a lockfile, a container base image,
    or a pinned CI action version. An audit result is a pure function of the
    dependency tree, so re-running it for a diff that changed no dependency
    buys nothing and slows every task.

    Tier 3 (scheduled): pass -Force to audit regardless of the diff. Advisories
    are published against code nobody edited, so a clock-driven run is the only
    thing that catches those. Use a lower -Level for scheduled runs.

    States: PASS / FAIL / SKIPPED / NOT RUN. SKIPPED means no trigger was in
    the diff. NOT RUN means the tool is missing or its invocation failed.
    Neither is a pass, and neither may be rendered as one.

    Exit codes: 0 = pass or skipped   1 = findings   2 = could not audit

.PARAMETER Level
    Minimum severity that fails. 'high' for gates, 'moderate' for scheduled.

.PARAMETER Force
    Audit even when no trigger path is in the diff (Tier 3 / manual).

.PARAMETER BaseRef
    Compare against this ref instead of the working tree.

.PARAMETER AllowlistPath
    Suppression file. Defaults to ./audit-allowlist.json when present.

.PARAMETER IncludeDev
    Include dev dependencies. Off by default: dev-only advisories don't ship,
    and gating on them is how a check earns itself a disable.

.EXAMPLE
    .\dependency-audit.ps1
.EXAMPLE
    .\dependency-audit.ps1 -Force -Level moderate
#>
[CmdletBinding()]
param(
    [ValidateSet('low','moderate','high','critical')]
    [string] $Level = 'high',
    [switch] $Force,
    [string] $BaseRef,
    [string] $AllowlistPath,
    [switch] $IncludeDev
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rows      = New-Object System.Collections.ArrayList
$details   = New-Object System.Collections.ArrayList
$applied   = New-Object System.Collections.ArrayList
$expiring  = New-Object System.Collections.ArrayList
$expired   = New-Object System.Collections.ArrayList

function Add-Row {
    param([string]$Eco,[string]$Command,[string]$ExitCode,[string]$Result,[string]$Note)
    [void]$rows.Add([pscustomobject]@{
        Eco = $Eco; Command = $Command; ExitCode = $ExitCode; Result = $Result; Note = $Note
    })
}

# git writes advisory noise to stderr (CRLF warnings, detached-HEAD notes).
# Under $ErrorActionPreference='Stop', PowerShell 5.1 promotes native stderr
# to a terminating NativeCommandError -- so a harmless CRLF warning would
# abort the whole audit. Scope the preference around each call instead of
# relying on 2>$null, which does not prevent the promotion.
function Invoke-GitLines {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]] $GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try   { $out = & git @GitArgs 2>$null }
    catch { return @() }
    finally { $ErrorActionPreference = $prev }
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($out | Where-Object { $_ -is [string] -and $_ })
}

# Same promotion problem applies to every audit tool: npm writes progress and
# errors to stderr, and any of it would abort the run under 'Stop'. Capture
# stdout and the real exit code without letting stderr become terminating.
function Invoke-NativeCapture {
    param([string] $Exe, [string[]] $Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $out  = ''
    $code = -1
    try {
        $out  = (& $Exe @Arguments 2>$null | Out-String)
        $code = $LASTEXITCODE
    }
    catch { $out = ''; $code = -1 }
    finally { $ErrorActionPreference = $prev }
    return [pscustomobject]@{ Out = $out; Exit = $code }
}

# -- Trigger detection ---------------------------------------------------
$triggerPattern = '(^|[\\/])(package\.json|package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|\.npmrc|pubspec\.(yaml|lock)|requirements[^\\/]*\.txt|poetry\.lock|Pipfile\.lock|go\.(mod|sum)|Gemfile\.lock|pom\.xml|[^\\/]+\.csproj|Dockerfile[^\\/]*|[^\\/]+\.dockerfile|docker-compose[^\\/]*\.ya?ml)$|[\\/]\.(github|gitlab)[\\/].*\.ya?ml$'

$insideRepo = @(Invoke-GitLines rev-parse --is-inside-work-tree).Count -gt 0

$triggered = $false
$triggerFiles = @()
if ($Force) {
    $triggered = $true
}
elseif (-not $insideRepo) {
    # Cannot compute a diff, so cannot claim the check was correctly skipped.
    Add-Row 'n/a' 'n/a' 'n/a' 'NOT RUN' 'not a git repository; cannot determine whether dependencies changed (use -Force to audit anyway)'
}
else {
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    if ($BaseRef) {
        foreach ($f in (Invoke-GitLines diff --name-only --diff-filter=ACMR "$BaseRef...HEAD")) { [void]$set.Add($f) }
    }
    foreach ($f in (Invoke-GitLines diff --name-only --diff-filter=ACMR))          { [void]$set.Add($f) }
    foreach ($f in (Invoke-GitLines diff --name-only --diff-filter=ACMR --cached)) { [void]$set.Add($f) }
    foreach ($f in (Invoke-GitLines ls-files --others --exclude-standard))         { [void]$set.Add($f) }
    $triggerFiles = @(@($set) | Where-Object { $_ -and ($_ -match $triggerPattern) })
    $triggered = $triggerFiles.Count -gt 0
}

# -- Allowlist -----------------------------------------------------------
$suppressions = @()
if (-not $AllowlistPath) { if (Test-Path 'audit-allowlist.json') { $AllowlistPath = 'audit-allowlist.json' } }
if ($AllowlistPath -and (Test-Path -LiteralPath $AllowlistPath)) {
    try {
        $al = Get-Content -LiteralPath $AllowlistPath -Raw | ConvertFrom-Json
        if ($al.PSObject.Properties.Name -contains 'suppressions') { $suppressions = @($al.suppressions) }
        $today = Get-Date
        foreach ($s in $suppressions) {
            if (-not $s.id -or -not $s.expires) { continue }
            $exp = $null
            if (-not [datetime]::TryParse($s.expires, [ref]$exp)) { continue }
            $daysLeft = ($exp - $today).TotalDays
            if ($daysLeft -lt 0)      { [void]$expired.Add("$($s.id) ($($s.package)) expired $($s.expires)") }
            elseif ($daysLeft -le 14) { [void]$expiring.Add("$($s.id) ($($s.package)) expires $($s.expires)") }
        }
    } catch {
        [void]$details.Add("Allowlist at $AllowlistPath could not be parsed -- treating as empty. No suppressions applied.")
        $suppressions = @()
    }
}
$activeIds = @()
foreach ($s in $suppressions) {
    if (-not $s.id -or -not $s.expires) { continue }
    $exp = $null
    if ([datetime]::TryParse($s.expires, [ref]$exp) -and $exp -ge (Get-Date)) { $activeIds += $s.id }
}

# -- Node / npm ----------------------------------------------------------
$sev = @{ low = 0; moderate = 1; high = 2; critical = 3 }

if (Test-Path 'package.json') {
    $hasNpm = $null -ne (Get-Command npm -ErrorAction SilentlyContinue)
    $cmdDisplay = "npm audit --audit-level=$Level" + $(if ($IncludeDev) { '' } else { ' --omit=dev' })

    if (-not $triggered) {
        Add-Row 'node' $cmdDisplay '-' 'SKIPPED' 'no dependency files in diff (result is unchanged from last run)'
    }
    elseif (-not $hasNpm) {
        Add-Row 'node' $cmdDisplay '-' 'NOT RUN' 'npm not found on PATH'
    }
    else {
        # NOT $args -- that is a PowerShell automatic variable, and assigning
        # to it then splatting silently passes the wrong argument list.
        $npmArgs = @('audit', "--audit-level=$Level", '--json')
        if (-not $IncludeDev) { $npmArgs += '--omit=dev' }
        # Never 2>&1: merging a native command's stderr into stdout corrupts
        # the JSON payload, since npm writes progress and warnings to stderr.
        $res     = Invoke-NativeCapture 'npm' $npmArgs
        $raw     = $res.Out
        $npmExit = $res.Exit

        $parsed = $null
        try { $parsed = $raw | ConvertFrom-Json } catch { $parsed = $null }

        # Parsing successfully is NOT the same as having an audit report.
        # npm emits its own errors as valid JSON ({"error":{"code":"ENOLOCK"}}),
        # which parses fine, contains no vulnerabilities, and would otherwise
        # be counted as a clean pass -- a false green on a command that failed.
        # Require the report shape before trusting a zero count.
        $isReport = $false
        if ($null -ne $parsed) {
            $names = $parsed.PSObject.Properties.Name
            $isReport = ($names -contains 'auditReportVersion') -or
                        (($names -contains 'metadata') -and ($names -contains 'vulnerabilities'))
        }
        $npmErrCode = $null
        if (($null -ne $parsed) -and ($parsed.PSObject.Properties.Name -contains 'error')) {
            if ($parsed.error -and ($parsed.error.PSObject.Properties.Name -contains 'code')) {
                $npmErrCode = [string]$parsed.error.code
            } else {
                $npmErrCode = 'unspecified'
            }
        }

        if (-not $isReport) {
            $reason = 'npm audit did not return an audit report'
            if ($npmErrCode) { $reason = "npm audit failed: $npmErrCode" }
            if ($raw -match 'ENOLOCK' -or $raw -match 'requires an existing lockfile' -or $npmErrCode -eq 'ENOLOCK') {
                $reason = 'no lockfile present -- run `npm install` first so there is a resolved tree to audit'
            }
            elseif ($null -eq $parsed) {
                $reason = 'npm audit output was not parseable JSON'
            }
            Add-Row 'node' $cmdDisplay "$npmExit" 'NOT RUN' $reason
        }
        else {
            $counts = $null
            if ($parsed.PSObject.Properties.Name -contains 'metadata') { $counts = $parsed.metadata.vulnerabilities }

            $offenders = New-Object System.Collections.ArrayList
            $suppressedHere = New-Object System.Collections.ArrayList

            if ($parsed.PSObject.Properties.Name -contains 'vulnerabilities') {
                foreach ($p in $parsed.vulnerabilities.PSObject.Properties) {
                    $v = $p.Value
                    if (-not $v.severity) { continue }
                    if (-not $sev.ContainsKey($v.severity)) { continue }
                    if ($sev[$v.severity] -lt $sev[$Level]) { continue }

                    # Collect advisory ids for this package, if present.
                    $ids = @()
                    if ($v.PSObject.Properties.Name -contains 'via') {
                        foreach ($via in @($v.via)) {
                            if ($via -and $via.PSObject -and ($via.PSObject.Properties.Name -contains 'url')) {
                                $m = [regex]::Match([string]$via.url, 'GHSA-[0-9a-z\-]+')
                                if ($m.Success) { $ids += $m.Value }
                            }
                        }
                    }
                    $isSuppressed = $false
                    foreach ($id in $ids) { if ($activeIds -contains $id) { $isSuppressed = $true } }

                    if ($isSuppressed) { [void]$suppressedHere.Add("$($p.Name) [$($v.severity)] ($(($ids | Select-Object -Unique) -join ', '))") }
                    else               { [void]$offenders.Add("$($p.Name) [$($v.severity)]") }
                }
            }

            foreach ($s in $suppressedHere) { [void]$applied.Add($s) }

            $summary = if ($counts) { "critical=$($counts.critical) high=$($counts.high) moderate=$($counts.moderate) low=$($counts.low)" } else { 'counts unavailable' }

            if ($offenders.Count -gt 0) {
                Add-Row 'node' $cmdDisplay "$npmExit" 'FAIL' $summary
                [void]$details.Add("At or above '$Level' (node): " + (($offenders | Sort-Object -Unique) -join ', '))
            }
            else {
                $note = $summary
                if ($suppressedHere.Count -gt 0) { $note += " ($($suppressedHere.Count) suppressed)" }
                Add-Row 'node' $cmdDisplay "$npmExit" 'PASS' $note
            }
        }
    }
}

# -- Dart / Flutter ------------------------------------------------------
if (Test-Path 'pubspec.yaml') {
    $hasOsv = $null -ne (Get-Command osv-scanner -ErrorAction SilentlyContinue)
    $cmdDisplay = 'osv-scanner --lockfile=pubspec.lock'
    if (-not $triggered) {
        Add-Row 'dart' $cmdDisplay '-' 'SKIPPED' 'no dependency files in diff'
    }
    elseif (-not (Test-Path 'pubspec.lock')) {
        Add-Row 'dart' $cmdDisplay '-' 'NOT RUN' 'pubspec.lock not present -- run `flutter pub get` first'
    }
    elseif (-not $hasOsv) {
        Add-Row 'dart' $cmdDisplay '-' 'NOT RUN' 'osv-scanner not on PATH (install from github.com/google/osv-scanner)'
    }
    else {
        # ASSUMPTION: osv-scanner's flags and exit codes were not executed
        # during authoring. A non-0/1 exit is reported NOT RUN, never PASS.
        $osvRes  = Invoke-NativeCapture 'osv-scanner' @('--lockfile=pubspec.lock')
        $out     = $osvRes.Out
        $osvExit = $osvRes.Exit
        if ($osvExit -eq 0) {
            Add-Row 'dart' $cmdDisplay "$osvExit" 'PASS' 'no advisories reported'
        }
        elseif ($osvExit -eq 1) {
            Add-Row 'dart' $cmdDisplay "$osvExit" 'FAIL' 'advisories reported -- see detail below'
            [void]$details.Add("osv-scanner output:`n" + $out.Trim())
        }
        else {
            Add-Row 'dart' $cmdDisplay "$osvExit" 'NOT RUN' "unexpected exit $osvExit; invocation likely rejected"
        }
    }
}

# -- Container base images (documented gap, not silent) ------------------
if ((Test-Path 'Dockerfile') -or (Get-ChildItem -Filter 'Dockerfile*' -File -ErrorAction SilentlyContinue)) {
    # NOT COVERED, not NOT RUN. This is a permanent, documented scope gap --
    # image scanning was never wired in. Counting it as NOT RUN would make
    # every single run return INCOMPLETE, and a check that is always
    # incomplete gets ignored, which costs more than the gap it flags.
    # Visible but verdict-neutral is the honest treatment.
    Add-Row 'container' 'image scan (trivy/grype)' '-' 'NOT COVERED' 'base-image CVEs are outside this script''s scope -- run a container scanner separately; this is a known gap, not a pass and not a failure'
}

if ($rows.Count -eq 0) {
    Add-Row 'n/a' 'n/a' '-' 'NOT RUN' 'no recognised manifest found (package.json / pubspec.yaml)'
}

# -- Report --------------------------------------------------------------
Write-Output '## Dependency audit'
Write-Output ''
$tier = if ($Force) { 'Tier 3 (forced/scheduled)' } else { 'Tier 2 (conditional on diff)' }
Write-Output "Mode: $tier | threshold: $Level | dev deps: $(if ($IncludeDev) { 'included' } else { 'excluded' })"
if ($triggerFiles.Count -gt 0) {
    Write-Output "Triggered by: $(($triggerFiles | Select-Object -First 8) -join ', ')"
} elseif (-not $Force -and $insideRepo) {
    Write-Output 'Triggered by: nothing -- no dependency-defining file in the diff'
}
Write-Output ''
Write-Output '| Ecosystem | Command | Exit | Result | Detail |'
Write-Output '|---|---|---|---|---|'
foreach ($r in $rows) {
    Write-Output "| $($r.Eco) | ``$($r.Command)`` | $($r.ExitCode) | $($r.Result) | $($r.Note) |"
}

if ($applied.Count -gt 0) {
    Write-Output ''
    Write-Output '### Suppressions applied (visible by design)'
    foreach ($a in ($applied | Sort-Object -Unique)) { Write-Output "  - $a" }
}
if ($expiring.Count -gt 0) {
    Write-Output ''
    Write-Output '### Suppressions expiring within 14 days'
    foreach ($e in $expiring) { Write-Output "  - $e" }
}
if ($expired.Count -gt 0) {
    Write-Output ''
    Write-Output '### EXPIRED suppressions -- no longer suppressing, decide now'
    foreach ($e in $expired) { Write-Output "  - $e" }
}
if ($details.Count -gt 0) {
    Write-Output ''
    Write-Output '### Detail'
    foreach ($d in $details) { Write-Output $d }
}

# 'NOT COVERED' is deliberately excluded from the verdict: it marks a permanent
# scope gap, not a check that failed to run today. Only NOT RUN -- a tool that
# should have worked and didn't -- makes a result INCOMPLETE.
$anyFail   = @($rows | Where-Object { $_.Result -eq 'FAIL'    }).Count -gt 0
$anyNotRun = @($rows | Where-Object { $_.Result -eq 'NOT RUN' }).Count -gt 0
$anyPass   = @($rows | Where-Object { $_.Result -eq 'PASS'    }).Count -gt 0
$anySkip   = @($rows | Where-Object { $_.Result -eq 'SKIPPED' }).Count -gt 0

Write-Output ''
if ($anyFail) {
    Write-Output 'Verdict: FAIL'
    exit 1
}
elseif ($anyNotRun) {
    Write-Output 'Verdict: INCOMPLETE (a check could not run -- this is not a pass)'
    exit 2
}
elseif ((-not $anyPass) -and $anySkip) {
    # Every runnable row was SKIPPED. Reporting this as PASS would claim an
    # audit happened when none did -- the same defect as calling an unexecuted
    # command passing. Exit 0 because skipping was correct, but say so.
    Write-Output 'Verdict: SKIPPED (no dependency-defining files changed -- nothing was audited)'
    exit 0
}
elseif (-not $anyPass) {
    Write-Output 'Verdict: NOTHING TO AUDIT (no supported manifest found)'
    exit 0
}
else {
    Write-Output 'Verdict: PASS'
    exit 0
}
