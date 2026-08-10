<#
.SYNOPSIS
  Verify that a design-document set agrees with its traceability registry.

.DESCRIPTION
  Reads docs/traceability.json and checks, for every unit, that the PRD, the
  schema document, the API reference and the Postman collection all actually
  contain what the registry claims they contain -- then checks the reverse, so
  a table or request nobody claims surfaces too.

  Seven finding codes:
    PRD-MISSING         unit id absent from the PRD
    SCHEMA-MISSING      declared table absent from the schema document
    API-MISSING         declared endpoint absent from api.md
    COLLECTION-MISSING  declared request absent from the collection
    SOURCE-MISSING      a BUILT unit names a source path that does not exist
    ORPHAN-TABLE        schema document defines a prefixed table no unit claims
    ORPHAN-REQUEST      collection holds a request no unit claims

  Exit 0 clean, 1 drift found, 2 could not run. Exit 2 is NOT exit 0: a checker
  that could not read its registry has reported nothing, and reporting nothing
  as clean defeats every other check here.

  WHAT THIS CANNOT DO: it matches names, so it finds absence, not disagreement.
  A Field Properties row saying Varchar2(100) against a VARCHAR2(240) column
  passes -- both documents mention the field. Do not read a green run as "the
  documents agree".

.PARAMETER Registry
  Path to traceability.json. Default: docs/traceability.json under -RepoRoot.

.PARAMETER RepoRoot
  Root the registry's relative paths resolve against. Default: current location.

.PARAMETER Markdown
  Also regenerate the human-readable traceability.md beside the registry.

.EXAMPLE
  ./check-coherence.ps1
  ./check-coherence.ps1 -Registry docs/traceability.json -Markdown
#>
[CmdletBinding()]
param(
    [string]$Registry,
    [string]$RepoRoot = (Get-Location).Path,
    [switch]$Markdown
)

$ErrorActionPreference = 'Continue'

if (-not $Registry) { $Registry = Join-Path $RepoRoot 'docs/traceability.json' }

# This file is deliberately ASCII-only: Windows PowerShell 5.1 reads a BOM-less
# .ps1 as ANSI, so a literal em-dash in source becomes mojibake and breaks the
# parse. Verified the hard way (2026-08-10). The generated markdown IS UTF-8, so
# the two characters it needs are built from code points instead of typed.
$EM  = [char]0x2014   # em dash
$MID = [char]0x00B7   # middot

$findings = [System.Collections.Generic.List[object]]::new()
function Add-Finding {
    param($Code, $Unit, $Detail)
    $findings.Add([pscustomobject]@{ Code = $Code; Unit = $Unit; Detail = $Detail })
}

function Fail-NotRun {
    param([string]$Reason)
    Write-Host ''
    Write-Host 'COHERENCE: NOT RUN' -ForegroundColor Yellow
    Write-Host "  $Reason"
    Write-Host '  NOT RUN is not a pass. Fix the cause and re-run.'
    exit 2
}

# --- load registry ------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Registry)) {
    Fail-NotRun "Registry not found: $Registry"
}
try {
    $reg = Get-Content -LiteralPath $Registry -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Fail-NotRun "Registry is not parseable JSON: $Registry -- $($_.Exception.Message)"
}
if (-not $reg.units -or $reg.units.Count -eq 0) {
    Fail-NotRun "Registry has no units: $Registry"
}
if (-not $reg.app -or -not $reg.app.objectPrefix) {
    Fail-NotRun "Registry is missing app.objectPrefix, which the ORPHAN-TABLE check needs."
}

# --- load artifacts -----------------------------------------------------------
function Resolve-Artifact {
    param([string]$Relative, [string]$Label)
    if (-not $Relative) { Fail-NotRun "Registry artifacts.$Label is not set." }
    $p = Join-Path $RepoRoot $Relative
    if (-not (Test-Path -LiteralPath $p)) {
        Fail-NotRun "artifacts.$Label points at a file that does not exist: $Relative"
    }
    return $p
}

$prdPath        = Resolve-Artifact $reg.artifacts.prd        'prd'
$schemaPath     = Resolve-Artifact $reg.artifacts.schema     'schema'
$apiPath        = Resolve-Artifact $reg.artifacts.api        'api'
$collectionPath = Resolve-Artifact $reg.artifacts.collection 'collection'

$prdText    = Get-Content -LiteralPath $prdPath    -Raw -Encoding UTF8
$schemaText = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8
$apiLines   = Get-Content -LiteralPath $apiPath          -Encoding UTF8

try {
    $collection = Get-Content -LiteralPath $collectionPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Fail-NotRun "Collection is not parseable JSON: $($reg.artifacts.collection) -- $($_.Exception.Message)"
}

# --- flatten the collection to "Folder / Request" -----------------------------
$collectionRequests = [System.Collections.Generic.List[string]]::new()
function Walk-Items {
    param($Items, [string]$Prefix)
    foreach ($it in $Items) {
        if ($null -ne $it.item) {
            $childPrefix = $it.name
            if ($Prefix) { $childPrefix = "$Prefix / $($it.name)" }
            Walk-Items -Items $it.item -Prefix $childPrefix
        } elseif ($null -ne $it.request) {
            if ($Prefix) { $collectionRequests.Add("$Prefix / $($it.name)") }
            else         { $collectionRequests.Add($it.name) }
        }
    }
}
Walk-Items -Items $collection.item -Prefix ''

# --- forward checks -----------------------------------------------------------
$claimedTables   = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$claimedRequests = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

foreach ($u in $reg.units) {

    if ($u.status -eq 'WITHDRAWN') {
        # A withdrawn unit still has to be findable in the PRD, so inbound
        # references land somewhere -- but nothing else about it is checked.
        if ($prdText -notmatch [regex]::Escape($u.id)) {
            Add-Finding 'PRD-MISSING' $u.id "Withdrawn unit is not mentioned in the PRD; inbound references have nowhere to land."
        }
        foreach ($t in $u.tables)             { [void]$claimedTables.Add($t) }
        foreach ($r in $u.collectionRequests) { [void]$claimedRequests.Add($r) }
        continue
    }

    if ($prdText -notmatch [regex]::Escape($u.id)) {
        Add-Finding 'PRD-MISSING' $u.id "id not found in $($reg.artifacts.prd)"
    }

    foreach ($t in $u.tables) {
        [void]$claimedTables.Add($t)
        # Central tables are referenced, not defined here -- exempt.
        if ($t -match '^(XXINT_|XXCUST_)') { continue }
        if ($schemaText -notmatch [regex]::Escape($t)) {
            Add-Finding 'SCHEMA-MISSING' $u.id "table $t not found in $($reg.artifacts.schema)"
        }
    }

    foreach ($e in $u.endpoints) {
        $parts  = $e -split ' ', 2
        $method = $parts[0]
        $path   = $parts[1]
        # The negative lookahead stops a short path from matching a longer one:
        # without it '/npt/leave' matches the row documenting
        # '/npt/leave/requests' and a genuinely undocumented endpoint reads as
        # covered. Bare substring matching here is a false PASS, not a shortcut.
        $pathRx = [regex]::Escape($path) + '(?![A-Za-z0-9_/{:-])'
        $hit = $false
        foreach ($line in $apiLines) {
            if ($line -match $pathRx -and $line -match "\b$method\b") { $hit = $true; break }
        }
        if (-not $hit) {
            Add-Finding 'API-MISSING' $u.id "no line in $($reg.artifacts.api) carries both '$method' and '$path'"
        }
    }

    foreach ($r in $u.collectionRequests) {
        [void]$claimedRequests.Add($r)
        if (-not ($collectionRequests -contains $r)) {
            Add-Finding 'COLLECTION-MISSING' $u.id "request '$r' not found in $($reg.artifacts.collection)"
        }
    }

    if ($u.status -eq 'BUILT') {
        if (-not $u.sourceFiles -or $u.sourceFiles.Count -eq 0) {
            Add-Finding 'SOURCE-MISSING' $u.id "status is BUILT but sourceFiles is empty"
        } else {
            foreach ($f in $u.sourceFiles) {
                if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $f))) {
                    Add-Finding 'SOURCE-MISSING' $u.id "status is BUILT but $f does not exist"
                }
            }
        }
    }
}

# --- reverse checks -----------------------------------------------------------
$prefix = $reg.app.objectPrefix
foreach ($m in [regex]::Matches($schemaText, "\b$([regex]::Escape($prefix))_[A-Z0-9_]+_T\b")) {
    if (-not $claimedTables.Contains($m.Value)) {
        Add-Finding 'ORPHAN-TABLE' '-' "$($m.Value) is defined in the schema document but no unit claims it"
        [void]$claimedTables.Add($m.Value)   # report once
    }
}

foreach ($r in $collectionRequests) {
    if (-not $claimedRequests.Contains($r)) {
        Add-Finding 'ORPHAN-REQUEST' '-' "collection request '$r' is claimed by no unit"
    }
}

# --- regenerate traceability.md ----------------------------------------------
if ($Markdown) {
    $mdPath = Join-Path (Split-Path -Parent $Registry) 'traceability.md'
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# $($reg.app.code) $EM Traceability")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("GENERATED FROM $(Split-Path -Leaf $Registry) BY check-coherence.ps1 $EM DO NOT HAND-EDIT.")
    [void]$sb.AppendLine()
    $appIdText = 'unassigned'
    if ($null -ne $reg.app.appId) { $appIdText = "$($reg.app.appId)" }
    [void]$sb.AppendLine("Application code ``$($reg.app.code)`` $MID app_id ``$appIdText`` $MID object prefix ``$($reg.app.objectPrefix)``")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| ID | Screen | Status | Access | Tables | Endpoints |')
    [void]$sb.AppendLine('|---|---|---|---|---|---|')
    foreach ($u in $reg.units) {
        $acc = @()
        if ($u.access.isAdmin)                { $acc += 'IS_ADMIN=Y' }
        if ($u.access.personas.Count -gt 0)   { $acc += ($u.access.personas -join '+') }
        if ($u.access.derived)                { $acc += ($u.access.derived | ForEach-Object { "derived:$_" }) }
        if ($u.access.groups.Count -gt 0)     { $acc += ($u.access.groups -join ', ') }
        $acc += $u.access.accessType
        [void]$sb.AppendLine("| ``$($u.id)`` | $($u.screen) | $($u.status) | $($acc -join " $MID ") | $(($u.tables) -join '<br>') | $(($u.endpoints) -join '<br>') |")
    }
    # UTF-8 WITHOUT a BOM. Set-Content -Encoding UTF8 on Windows PowerShell 5.1
    # emits one, and a BOM ahead of the leading '#' stops strict markdown
    # parsers seeing an H1. Verified 2026-08-10.
    [System.IO.File]::WriteAllText($mdPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Regenerated $mdPath"
}

# --- report -------------------------------------------------------------------
Write-Host ''
Write-Host "Coherence check $EM $($reg.units.Count) unit(s), prefix $prefix"
Write-Host ''
if ($findings.Count -eq 0) {
    Write-Host 'COHERENCE: PASS' -ForegroundColor Green
    Write-Host '  Every unit resolves in all four artifacts; no orphans.'
    Write-Host "  Name-level only $EM this does not assert the documents agree on types."
    exit 0
}

$findings | Sort-Object Code, Unit | Format-Table -AutoSize -Wrap Code, Unit, Detail | Out-String | Write-Host
Write-Host "COHERENCE: FAIL $EM $($findings.Count) finding(s)" -ForegroundColor Red
Write-Host '  Propagation is incomplete. Edit the named artifacts; do not annotate.'
exit 1
