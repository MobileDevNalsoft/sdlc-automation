<#
.SYNOPSIS
  Diff a checked-in Postman collection against its API manifest, both directions.

.DESCRIPTION
  Run this BEFORE regenerating (C16). The finding that earns this script is
  EXTRA-IN-COLLECTION: someone added a useful request in Postman -- which is what
  Postman is for -- and a naive generator would delete it on the next run.
  Fold it into the manifest instead.

    MISSING-IN-COLLECTION  manifest declares it; the collection has no such request
    EXTRA-IN-COLLECTION    collection has a request the manifest does not declare
    METHOD-MISMATCH        same request name, different verb
    EXAMPLE-MISSING        request has no saved response (C3)

  Exit 0 in sync, 1 drift, 2 could not run. Exit 2 is not exit 0.

  ASCII-only on purpose: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.

.PARAMETER Manifest
  Path to the API manifest JSON.

.PARAMETER Collection
  Path to the Postman v2.1 collection JSON.

.EXAMPLE
  ./audit-collection.ps1 -Manifest docs/api/npt-api-manifest.json `
                         -Collection docs/api/npt-postman-collection.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Manifest,
    [Parameter(Mandatory = $true)][string]$Collection
)

$ErrorActionPreference = 'Continue'

$findings = [System.Collections.Generic.List[object]]::new()
function Add-Finding {
    param($Code, $Request, $Detail)
    $findings.Add([pscustomobject]@{ Code = $Code; Request = $Request; Detail = $Detail })
}
function Fail-NotRun {
    param([string]$Reason)
    Write-Host ''
    Write-Host 'AUDIT: NOT RUN' -ForegroundColor Yellow
    Write-Host "  $Reason"
    Write-Host '  NOT RUN is not a pass.'
    exit 2
}

if (-not (Test-Path -LiteralPath $Manifest))   { Fail-NotRun "Manifest not found: $Manifest" }
if (-not (Test-Path -LiteralPath $Collection)) { Fail-NotRun "Collection not found: $Collection" }
try { $m = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { Fail-NotRun "Manifest is not parseable JSON: $($_.Exception.Message)" }
try { $c = Get-Content -LiteralPath $Collection -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { Fail-NotRun "Collection is not parseable JSON: $($_.Exception.Message)" }
if (-not $m.endpoints -or $m.endpoints.Count -eq 0) { Fail-NotRun 'Manifest has no endpoints.' }

# --- flatten the collection ---------------------------------------------------
# Key on "Folder / Request name" -- the same join key doc-coherence matches (C8).
$collMap = @{}
function Walk-Items {
    param($Items, [string]$Prefix)
    foreach ($it in $Items) {
        if ($null -ne $it.item) {
            $childPrefix = $it.name
            if ($Prefix) { $childPrefix = "$Prefix / $($it.name)" }
            Walk-Items -Items $it.item -Prefix $childPrefix
        } elseif ($null -ne $it.request) {
            $key = $it.name
            if ($Prefix) { $key = "$Prefix / $($it.name)" }
            $respCount = 0
            if ($null -ne $it.response) { $respCount = @($it.response).Count }
            $collMap[$key] = [pscustomobject]@{
                Method        = $it.request.method
                ResponseCount = $respCount
            }
        }
    }
}
Walk-Items -Items $c.item -Prefix ''

# The Smoke folder re-lists requests that already live in their resource folder,
# so it is not an independent surface -- auditing it would double-report
# everything it contains.
$smokeKeys = @($collMap.Keys | Where-Object { $_ -like 'Smoke / *' })

# --- forward: manifest -> collection ------------------------------------------
$declared = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($e in $m.endpoints) {
    $folder = $e.folder
    if (-not $folder) { $folder = 'Default' }
    $name = $e.name
    if (-not $name) { $name = "$($e.method) $($e.path)" }
    $key = "$folder / $name"
    [void]$declared.Add($key)

    if (-not $collMap.ContainsKey($key)) {
        Add-Finding 'MISSING-IN-COLLECTION' $key "manifest declares $($e.method) $($e.path) but the collection has no such request"
        continue
    }
    if ($collMap[$key].Method -ne $e.method) {
        Add-Finding 'METHOD-MISMATCH' $key "manifest says $($e.method); collection says $($collMap[$key].Method)"
    }
    if ($collMap[$key].ResponseCount -eq 0) {
        Add-Finding 'EXAMPLE-MISSING' $key 'no saved response -- a request with no example is a call list, not documentation (C3)'
    }
}

# --- reverse: collection -> manifest ------------------------------------------
foreach ($key in $collMap.Keys) {
    if ($smokeKeys -contains $key) { continue }
    if (-not $declared.Contains($key)) {
        Add-Finding 'EXTRA-IN-COLLECTION' $key 'present in the collection, declared by no manifest endpoint. Usually a hand edit worth KEEPING -- fold it into the manifest rather than regenerating over it'
    }
}

# --- report -------------------------------------------------------------------
Write-Host ''
Write-Host "Collection audit -- $($m.endpoints.Count) declared endpoint(s), $($collMap.Keys.Count) collection request(s) ($($smokeKeys.Count) in Smoke, not audited separately)"
Write-Host ''
if ($findings.Count -eq 0) {
    Write-Host 'AUDIT: IN SYNC' -ForegroundColor Green
    Write-Host '  Every declared endpoint has a request; every request is declared.'
    Write-Host '  Name-level only -- this does not compare bodies, params or URLs.'
    exit 0
}

$findings | Sort-Object Code, Request | Format-Table -AutoSize -Wrap Code, Request, Detail | Out-String | Write-Host

$extra = @($findings | Where-Object { $_.Code -eq 'EXTRA-IN-COLLECTION' })
Write-Host "AUDIT: DRIFT -- $($findings.Count) finding(s)" -ForegroundColor Red
if ($extra.Count -gt 0) {
    Write-Host ''
    Write-Host "  $($extra.Count) EXTRA-IN-COLLECTION finding(s). Decide each one BEFORE running" -ForegroundColor Yellow
    Write-Host '  emit-collection.ps1 -Force, or you will destroy them.' -ForegroundColor Yellow
}
exit 1
