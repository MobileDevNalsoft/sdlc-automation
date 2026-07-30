#requires -Version 5.1
<#
.SYNOPSIS
    secret-scan's executable engine -- scans a diff (or a whole tree) for
    committed credentials and prints the gate row sdlc-verify's OUTPUT
    CONTRACT expects.

.DESCRIPTION
    Tier 1 check: runs on EVERY task. Any one-line diff can paste a key, a
    diff-scoped scan costs well under a second, and the failure is
    irreversible -- once a credential is pushed it is disclosed, and rotation
    is the only real remedy. Cheap plus unrecoverable is the case for
    always-on.

    Engine selection, reported honestly in the output:
      * 'builtin'  -- the pattern set below. Self-contained, no install.
      * 'gitleaks' -- used IN ADDITION when gitleaks is on PATH, for broader
                     coverage. ASSUMPTION: the gitleaks invocation here is
                     written against its documented CLI but was NOT executed
                     during authoring (gitleaks was absent). If your gitleaks
                     rejects the arguments, the builtin result still stands
                     and the gitleaks row reports NOT RUN -- it never silently
                     degrades to a pass.

    Exit codes:  0 = clean   1 = findings   2 = could not scan

.PARAMETER DiffPaths
    Explicit files to scan. Omit to compute from git (unstaged + staged +
    untracked).

.PARAMETER BaseRef
    Compare against this ref instead of the working tree, e.g. 'origin/main'.

.PARAMETER All
    Scan every tracked file instead of just the diff. Use for a baseline
    sweep or a Tier 3 scheduled run, not for per-task gating.

.EXAMPLE
    .\scan-secrets.ps1
.EXAMPLE
    .\scan-secrets.ps1 -BaseRef origin/main
.EXAMPLE
    .\scan-secrets.ps1 -All
#>
[CmdletBinding()]
param(
    [string[]] $DiffPaths,
    [string]   $BaseRef,
    [switch]   $All
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -- Pattern set ----------------------------------------------------------
# Each rule: Name, Regex, Why. Keep Why short -- it lands in the finding.
$rules = @(
    @{ Name = 'build-inlined-credential'
       Regex = '(?i)\b(VITE|NEXT_PUBLIC|REACT_APP|PUBLIC|EXPO_PUBLIC|GATSBY|NUXT_PUBLIC)_[A-Z0-9_]*(PASSWORD|SECRET|TOKEN|APIKEY|API_KEY|PRIVATE|CREDENTIAL)'
       Why = 'Bundler-inlined prefix: value is substituted at build time and ships inside the client bundle. Already disclosed to anyone who loads the app.' }

    @{ Name = 'hardcoded-credential-literal'
       Regex = '(?i)\b(password|passwd|secret|api[_-]?key|apikey|auth[_-]?token|access[_-]?token|client[_-]?secret|private[_-]?key)\b\s*[:=]\s*["''][^"''\s]{6,}["'']'
       Why = 'Credential assigned as a literal in source.' }

    @{ Name = 'private-key-block'
       Regex = '-----BEGIN\s+(RSA|DSA|EC|OPENSSH|PGP|ENCRYPTED)?\s*PRIVATE KEY-----'
       Why = 'Private key material embedded in a file.' }

    @{ Name = 'authorization-header-literal'
       Regex = '(?i)(authorization\s*[:=]\s*["'']?\s*)?\b(Bearer|Basic)\s+[A-Za-z0-9+/=_.\-]{16,}'
       Why = 'Literal Authorization value. Also leaks into logs and error reports.' }

    @{ Name = 'credential-in-url'
       Regex = '[a-zA-Z][a-zA-Z0-9+.\-]{1,20}://[^/\s:@"'']{1,64}:[^/\s:@"'']{1,64}@'
       Why = 'Credentials embedded in a connection string or URL. Leaks into logs, referrers, and traces.' }

    @{ Name = 'aws-access-key-id'
       Regex = '\b(AKIA|ASIA|ABIA|ACCA)[0-9A-Z]{16}\b'
       Why = 'AWS access key id.' }

    @{ Name = 'google-api-key'
       Regex = '\bAIza[0-9A-Za-z_\-]{35}\b'
       Why = 'Google API key.' }

    @{ Name = 'github-token'
       Regex = '\bgh[pousr]_[A-Za-z0-9]{36,}\b'
       Why = 'GitHub token.' }

    @{ Name = 'slack-token'
       Regex = '\bxox[baprse]-[A-Za-z0-9\-]{10,}\b'
       Why = 'Slack token.' }

    @{ Name = 'jwt-literal'
       Regex = '\beyJ[A-Za-z0-9_\-]{8,}\.eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\b'
       Why = 'Signed JWT committed as a literal.' }

    @{ Name = 'db-signer-embedded-secret'
       Regex = '(?i)(create\s+or\s+replace\s+(function|procedure|package)[\s\S]{0,4000}?)(''[A-Za-z0-9+/]{40,}={0,2}'')'
       Why = 'Long opaque literal inside a stored-procedure body -- signing keys commonly live here, and deployed DB source is normally committed.' }
)

# Filenames that are credential-shaped by convention.
$dangerousNamePattern = '(?i)(^|[\\/])(\.env(\.[^\\/]+)?|.*\.pem|.*\.key|.*\.p8|.*\.p12|.*\.pfx|.*\.jks|.*\.keystore|id_rsa|id_dsa|id_ecdsa|id_ed25519|key\.properties|.*service[_-]?account.*\.json|.*credentials\.json)$'

# Template/sample env files are conventionally committed and hold no real
# values. Excluded from the filename rule so the check stays credible --
# a scanner that cries wolf on .env.example gets switched off.
$dangerousNameExempt = '(?i)(^|[\\/])\.env\.(example|sample|template|dist|defaults?)$|\.(example|sample|template)$'

# Paths never worth scanning (noise, vendored, or generated).
$excludePattern = '(?i)([\\/]|^)(node_modules|\.git|\.next|\.nuxt|dist|build|out|coverage|vendor|Pods|\.dart_tool|__pycache__|\.venv|target)([\\/]|$)|\.(min\.js|min\.css|map|lock|png|jpe?g|gif|webp|ico|svg|pdf|zip|gz|tgz|jar|so|dll|exe|woff2?|ttf|eot|mp4|mp3)$|(^|[\\/])(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|pubspec\.lock|Gemfile\.lock|poetry\.lock|composer\.lock)$'

# A match containing any of these is a placeholder, not a live secret.
$placeholderPattern = '(?i)(example|placeholder|your[_-]?|my[_-]?secret|changeme|change[_-]?me|dummy|sample|test[_-]?(key|token|secret)|fake|redacted|xxxx|<[^>]{1,40}>|\$\{[^}]{1,40}\}|\{\{[^}]{1,40}\}\}|TODO|REPLACE|INSERT[_-]?YOUR|abcdef123456|0{8,}|1{8,}|a{8,}|x{8,})'

$maxFileBytes = 1MB

function Get-RedactedSnippet {
    param([string] $Line, [string] $Match)
    $t = $Line.Trim()
    if ($t.Length -gt 160) { $t = $t.Substring(0, 160) + '...' }
    # Never echo a full credential into a log or a PR comment.
    if ($Match.Length -gt 12) {
        $keep = $Match.Substring(0, 4)
        $t = $t.Replace($Match, ($keep + ('*' * 8) + '[redacted ' + $Match.Length + ' chars]'))
    }
    return $t
}

# -- Build the file list --------------------------------------------------
# git writes advisory noise to stderr (CRLF warnings, detached-HEAD notes).
# Under $ErrorActionPreference='Stop', PowerShell 5.1 promotes native stderr
# to a terminating NativeCommandError -- so a harmless CRLF warning would
# abort the whole scan. Scope the preference around each call; 2>$null alone
# does not prevent the promotion.
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

$insideRepo = @(Invoke-GitLines rev-parse --is-inside-work-tree).Count -gt 0

$files = @()
# Truthiness, not .Count: under StrictMode, .Count on an unassigned
# [string[]] param throws, while [bool] of it is safely $false.
if ($DiffPaths) {
    $files = @($DiffPaths)
}
elseif (-not $insideRepo) {
    Write-Output '## Secret scan'
    Write-Output ''
    Write-Output '| Check | Engine | Findings | Result |'
    Write-Output '|---|---|---|---|'
    Write-Output '| secret-scan | n/a | n/a | NOT RUN (not a git repository, and no -DiffPaths given) |'
    exit 2
}
elseif ($All) {
    $files = @(Invoke-GitLines ls-files)
}
else {
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    if ($BaseRef) {
        foreach ($f in (Invoke-GitLines diff --name-only --diff-filter=ACMR "$BaseRef...HEAD")) { [void]$set.Add($f) }
    }
    foreach ($f in (Invoke-GitLines diff --name-only --diff-filter=ACMR))          { [void]$set.Add($f) }
    foreach ($f in (Invoke-GitLines diff --name-only --diff-filter=ACMR --cached)) { [void]$set.Add($f) }
    foreach ($f in (Invoke-GitLines ls-files --others --exclude-standard))         { [void]$set.Add($f) }
    $files = @($set)
}

$files = @($files | Where-Object { $_ -and ($_ -notmatch $excludePattern) -and (Test-Path -LiteralPath $_ -PathType Leaf) })

# -- Scan -----------------------------------------------------------------
$findings = New-Object System.Collections.ArrayList
$skippedTooBig = New-Object System.Collections.ArrayList

foreach ($file in $files) {

    if (($file -match $dangerousNamePattern) -and ($file -notmatch $dangerousNameExempt)) {
        [void]$findings.Add([pscustomobject]@{
            File = $file; Line = 0; Rule = 'credential-shaped-file'
            Why = 'This file type holds credentials by convention. Confirm it is gitignored and was never committed -- check `git log --all -- <file>`, not just the working tree.'
            Snippet = '(filename match)'
        })
    }

    $info = Get-Item -LiteralPath $file
    if ($info.Length -gt $maxFileBytes) { [void]$skippedTooBig.Add($file); continue }

    # @() is required: Get-Content returns a bare string for a single-line
    # file, and StrictMode rejects .Count on a scalar.
    try { $lines = @(Get-Content -LiteralPath $file -ErrorAction Stop) } catch { continue }
    if ($lines.Count -eq 0) { continue }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        foreach ($rule in $rules) {
            $m = [regex]::Match($line, $rule.Regex)
            if (-not $m.Success) { continue }
            if ($m.Value -match $placeholderPattern) { continue }
            if ($line -match $placeholderPattern -and $rule.Name -ne 'private-key-block') { continue }

            [void]$findings.Add([pscustomobject]@{
                File = $file; Line = ($i + 1); Rule = $rule.Name; Why = $rule.Why
                Snippet = (Get-RedactedSnippet -Line $line -Match $m.Value)
            })
            break   # one finding per line is enough to block
        }
    }
}

# -- Optional gitleaks pass (additive, never authoritative) ---------------
$gitleaksAvailable = $null -ne (Get-Command gitleaks -ErrorAction SilentlyContinue)
$gitleaksRow = '| gitleaks | -- | -- | NOT RUN (not on PATH -- builtin engine still ran) |'
$gitleaksFound = 0
if ($gitleaksAvailable) {
    $report = Join-Path ([System.IO.Path]::GetTempPath()) ('gitleaks-' + [guid]::NewGuid().ToString('N') + '.json')
    # ASSUMPTION: `gitleaks dir` is the current subcommand for filesystem scans
    # (older builds used `detect --no-git`). Untested during authoring.
    $null = & gitleaks dir . --report-format json --report-path $report --no-banner 2>&1
    $glExit = $LASTEXITCODE
    if ((Test-Path -LiteralPath $report) -and ($glExit -eq 0 -or $glExit -eq 1)) {
        try {
            $raw = Get-Content -LiteralPath $report -Raw
            if ($raw -and $raw.Trim()) {
                $parsed = $raw | ConvertFrom-Json
                if ($parsed) { $gitleaksFound = @($parsed).Count }
            }
            $gitleaksRow = "| gitleaks | gitleaks | $gitleaksFound | $(if ($gitleaksFound -gt 0) { 'FAIL' } else { 'PASS' }) |"
        } catch {
            $gitleaksRow = '| gitleaks | gitleaks | -- | NOT RUN (report unparseable -- builtin engine still ran) |'
        }
        Remove-Item -LiteralPath $report -ErrorAction SilentlyContinue
    } else {
        $gitleaksRow = "| gitleaks | gitleaks | -- | NOT RUN (exit $glExit, arguments likely rejected -- builtin engine still ran) |"
    }
}

# -- Report ---------------------------------------------------------------
$builtinCount = $findings.Count
$totalCount = $builtinCount + $gitleaksFound
$scope = if ($All) { 'whole tree' } elseif ($DiffPaths) { 'supplied paths' } else { 'diff' }

Write-Output '## Secret scan'
Write-Output ''
Write-Output "Scope: $scope | files scanned: $($files.Count)"
Write-Output ''
Write-Output '| Check | Engine | Findings | Result |'
Write-Output '|---|---|---|---|'
Write-Output "| secret-scan | builtin | $builtinCount | $(if ($builtinCount -gt 0) { 'FAIL' } else { 'PASS' }) |"
Write-Output $gitleaksRow

if ($skippedTooBig.Count -gt 0) {
    Write-Output ''
    Write-Output "NOT SCANNED (over $($maxFileBytes/1MB)MB -- these are not passes):"
    foreach ($f in $skippedTooBig) { Write-Output "  - $f" }
}

if ($builtinCount -gt 0) {
    Write-Output ''
    Write-Output '### Findings (blocking)'
    foreach ($f in $findings) {
        $loc = if ($f.Line -gt 0) { "$($f.File):$($f.Line)" } else { $f.File }
        Write-Output ''
        Write-Output "**$loc** -- $($f.Rule)"
        Write-Output "  $($f.Why)"
        Write-Output "  > $($f.Snippet)"
    }
    Write-Output ''
    Write-Output 'Remediation: move the value to a secret store the client never reads, and'
    Write-Output 'terminate the credentialed call server-side. Relocating it to a runtime'
    Write-Output 'global, a fetched config file, or localStorage does not fix this -- it stays'
    Write-Output 'browser-reachable. If the value was ever pushed, treat it as compromised and'
    Write-Output 'ROTATE it; scrubbing history does not un-disclose what was published.'
}

if ($totalCount -gt 0) { exit 1 } else { exit 0 }
