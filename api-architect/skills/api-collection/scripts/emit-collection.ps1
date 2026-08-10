<#
.SYNOPSIS
  Generate a Postman v2.1 collection AND the API reference markdown from one
  API manifest, in one run.

.DESCRIPTION
  Rules C1-C16 in API-COLLECTION.md. Both outputs come from the same manifest in
  the same run, so they cannot describe different versions of the API.

  Refuses to overwrite a collection it did not produce (C16): it stamps a content
  fingerprint into info.description and checks for it. Run audit-collection.ps1
  first, fold any EXTRA-IN-COLLECTION requests into the manifest, then -Force.

  This file is ASCII-only on purpose. Windows PowerShell 5.1 reads a BOM-less
  .ps1 as ANSI, so a literal em-dash in source becomes mojibake and breaks the
  parse. Characters needed in OUTPUT are built from code points below.

  Exit 0 emitted, 1 manifest invalid or refused, 2 could not run.

.PARAMETER Manifest
  Path to the API manifest JSON.

.PARAMETER OutCollection
  Path to write the Postman v2.1 collection.

.PARAMETER OutMarkdown
  Path to write api.md. Omit to skip -- but note C1: skipping means the two
  outputs can come from different manifest versions.

.PARAMETER Force
  Overwrite a collection whose fingerprint does not match (C16).

.EXAMPLE
  ./emit-collection.ps1 -Manifest docs/api/npt-api-manifest.json `
                        -OutCollection docs/api/npt-postman-collection.json `
                        -OutMarkdown docs/reference/api.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Manifest,
    [Parameter(Mandatory = $true)][string]$OutCollection,
    [string]$OutMarkdown,
    [switch]$Force
)

$ErrorActionPreference = 'Continue'

$EM   = [char]0x2014   # em dash
$ARR  = [string]([char]0x2192)  # right arrow

function Fail-NotRun {
    param([string]$Reason)
    Write-Host ''
    Write-Host 'EMIT: NOT RUN' -ForegroundColor Yellow
    Write-Host "  $Reason"
    Write-Host '  NOT RUN is not a pass.'
    exit 2
}
function Fail-Invalid {
    param([string]$Reason)
    Write-Host ''
    Write-Host 'EMIT: FAIL' -ForegroundColor Red
    Write-Host "  $Reason"
    exit 1
}

function Write-Utf8NoBom {
    # Set-Content -Encoding UTF8 on 5.1 emits a BOM; a BOM ahead of a leading '#'
    # stops strict markdown parsers seeing an H1, and Postman is happier without.
    param([string]$Path, [string]$Text)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

# --- load and validate the manifest -------------------------------------------
if (-not (Test-Path -LiteralPath $Manifest)) { Fail-NotRun "Manifest not found: $Manifest" }
try {
    $m = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Fail-NotRun "Manifest is not parseable JSON: $($_.Exception.Message)"
}
if (-not $m.module_name) { Fail-Invalid 'Manifest is missing module_name (required by api-audit too -- C2).' }
if (-not $m.endpoints -or $m.endpoints.Count -eq 0) { Fail-Invalid 'Manifest has no endpoints.' }

$collName = $m.collection_name
if (-not $collName) { $collName = $m.module_name }
$basePath = $m.base_path
if (-not $basePath) { $basePath = '' }
$basePath = $basePath.TrimEnd('/')

$problems = [System.Collections.Generic.List[string]]::new()
foreach ($e in $m.endpoints) {
    if (-not $e.path)   { $problems.Add("An endpoint is missing 'path'.") }
    if (-not $e.method) { $problems.Add("Endpoint '$($e.path)' is missing 'method'.") }
    if ($e.path -match '\{[A-Za-z0-9_]+\}') {
        $problems.Add("C9: endpoint '$($e.path)' uses {brace} form. Use ORDS ':name' form -- one spelling, no translation step.")
    }
}
if ($problems.Count -gt 0) {
    Write-Host ''
    Write-Host 'EMIT: FAIL' -ForegroundColor Red
    $problems | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- deterministic collection id (C12) ----------------------------------------
function Get-DeterministicGuid {
    param([string]$Seed)
    $md5   = [System.Security.Cryptography.MD5]::Create()
    $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Seed))
    $md5.Dispose()
    return (New-Object System.Guid (,$bytes)).ToString()
}
$collectionId = Get-DeterministicGuid "sdlc-automation/api-collection/$collName"

# --- fingerprint (C16) --------------------------------------------------------
$manifestRaw  = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8
$sha          = [System.Security.Cryptography.SHA256]::Create()
$fpBytes      = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($manifestRaw))
$sha.Dispose()
$fingerprint  = ($fpBytes | ForEach-Object { $_.ToString('x2') }) -join ''
$fpMarker     = "generated-by=api-collection"

function Get-Sha256Hex {
    param([string]$Text)
    $h = [System.Security.Cryptography.SHA256]::Create()
    $b = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
    $h.Dispose()
    return (($b | ForEach-Object { $_.ToString('x2') }) -join '')
}

# C16 has to distinguish two cases that look identical from the marker alone:
#   the manifest changed          -> overwrite is correct
#   the FILE was edited after we wrote it -> refuse, that is someone's work
# So the marker carries a content hash of the file as emitted (with the hash slot
# itself blanked, to break the chicken-and-egg). On re-emit we recompute the
# existing file's hash the same way: a mismatch means it changed after we wrote
# it. Checking only for the marker's presence -- which is what this did first --
# let a hand-edit to an already-generated collection be silently destroyed, which
# is the common case, since generating and then tweaking in Postman is the whole
# workflow. Found by testing it (2026-08-10).
$contentSlotRx = 'content-sha256=[0-9a-fA-F]{64}'

if ((Test-Path -LiteralPath $OutCollection) -and -not $Force) {
    $existingRaw = Get-Content -LiteralPath $OutCollection -Raw -Encoding UTF8
    $refuse      = $null
    if ($existingRaw -notmatch [regex]::Escape($fpMarker)) {
        $refuse = 'exists and was not produced by this script.'
    } else {
        $stored = [regex]::Match($existingRaw, $contentSlotRx)
        if (-not $stored.Success) {
            $refuse = 'was produced by an older version of this script and carries no content hash.'
        } else {
            $blanked = [regex]::Replace($existingRaw, $contentSlotRx, 'content-sha256=PENDING')
            if ((Get-Sha256Hex $blanked) -ne $stored.Value.Substring('content-sha256='.Length)) {
                $refuse = 'was edited after this script wrote it -- those edits are not in the manifest.'
            }
        }
    }
    if ($refuse) {
        Write-Host ''
        Write-Host 'EMIT: REFUSED' -ForegroundColor Red
        Write-Host "  $OutCollection $refuse"
        Write-Host '  Run audit-collection.ps1, fold any EXTRA-IN-COLLECTION requests into'
        Write-Host '  the manifest, then re-run with -Force (C16).'
        exit 1
    }
}

# --- helpers ------------------------------------------------------------------
function To-PathSegments {
    param([string]$FullPath)
    return @($FullPath.Trim('/').Split('/') | Where-Object { $_ -ne '' })
}
# Hand-rolled because ConvertTo-Json on Windows PowerShell 5.1 is unusable for
# documentation payloads, in two ways found by running it (2026-08-10):
#   1. It escapes < > ' & as \u003c \u003e \u0027 \u0026. A consumer reading
#      "\u003copaque\u003e" in an example learns nothing.
#   2. It emits "key":  "value" (two spaces) and pads nested arrays to the
#      key's column, so a 3-field object indents 21 characters deep.
# Both are cosmetic to a parser and fatal to a reader, and examples exist to be
# read. Escapes only what JSON actually requires; the file is UTF-8.
function Escape-JsonString {
    param([string]$S)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($ch in $S.ToCharArray()) {
        switch ($ch) {
            '"'      { [void]$sb.Append('\"') }
            '\'      { [void]$sb.Append('\\') }
            "`b"     { [void]$sb.Append('\b') }
            "`f"     { [void]$sb.Append('\f') }
            "`n"     { [void]$sb.Append('\n') }
            "`r"     { [void]$sb.Append('\r') }
            "`t"     { [void]$sb.Append('\t') }
            default  {
                if ([int]$ch -lt 32) { [void]$sb.Append('\u' + ([int]$ch).ToString('x4')) }
                else                 { [void]$sb.Append($ch) }
            }
        }
    }
    return $sb.ToString()
}

function Json-Pretty {
    param($Obj, [int]$Indent = 0)
    if ($null -eq $Obj) { return 'null' }
    $pad     = ' ' * ($Indent * 2)
    $padIn   = ' ' * (($Indent + 1) * 2)

    if ($Obj -is [bool])   { if ($Obj) { return 'true' } else { return 'false' } }
    if ($Obj -is [string]) { return '"' + (Escape-JsonString $Obj) + '"' }
    if ($Obj -is [int] -or $Obj -is [long] -or $Obj -is [double] -or $Obj -is [decimal] -or $Obj -is [single]) {
        return ([string]$Obj)
    }

    if ($Obj -is [System.Collections.IEnumerable]) {
        $items = @($Obj)
        if ($items.Count -eq 0) { return '[]' }
        $parts = @()
        foreach ($i in $items) { $parts += ($padIn + (Json-Pretty -Obj $i -Indent ($Indent + 1))) }
        return "[`n" + ($parts -join ",`n") + "`n$pad]"
    }

    $props = @()
    if ($Obj -is [System.Collections.IDictionary]) {
        foreach ($k in $Obj.Keys) { $props += [pscustomobject]@{ Name = $k; Value = $Obj[$k] } }
    } else {
        foreach ($p in $Obj.PSObject.Properties) { $props += [pscustomobject]@{ Name = $p.Name; Value = $p.Value } }
    }
    $props = @($props | Where-Object { $_.Name -ne '_comment' })
    if ($props.Count -eq 0) { return '{}' }
    $parts = @()
    foreach ($p in $props) {
        $parts += ($padIn + '"' + (Escape-JsonString ([string]$p.Name)) + '": ' + (Json-Pretty -Obj $p.Value -Indent ($Indent + 1)))
    }
    return "{`n" + ($parts -join ",`n") + "`n$pad}"
}

# The outer collection still goes through ConvertTo-Json, which re-escapes those
# four characters inside every string. Unescaping them afterwards keeps the
# checked-in file's diffs readable and stays valid JSON -- Postman reads either
# form identically.
function Unescape-JsonAngles {
    param([string]$S)
    return $S.Replace('\u003c','<').Replace('\u003e','>').Replace('\u0027',"'").Replace('\u0026','&')
}
function Get-ExampleLabel {
    param($Response)
    if ($null -eq $Response.example) { return 'NO EXAMPLE CAPTURED' }
    if ($Response.exampleSource -eq 'hand-written') { return 'EXAMPLE NOT CAPTURED FROM A LIVE CALL' }
    return ''
}

# --- build the collection -----------------------------------------------------
$folders    = [ordered]@{}
$smokeItems = [System.Collections.Generic.List[object]]::new()
$noExample  = [System.Collections.Generic.List[string]]::new()
$noSuccess  = [System.Collections.Generic.List[string]]::new()

foreach ($e in $m.endpoints) {

    $folderName = $e.folder
    if (-not $folderName) { $folderName = 'Default' }
    $reqName = $e.name
    if (-not $reqName) { $reqName = "$($e.method) $($e.path)" }

    $fullPath = "$basePath/$($e.path.TrimStart('/'))"

    # description opens with the unit id so doc-coherence can resolve it
    $descParts = @()
    if ($e.unit) { $descParts += "$($e.unit)" }
    if ($e.summary) { $descParts += $e.summary }
    if ($e.legacyEnvelope) {
        $descParts += "LEGACY RESPONSE ENVELOPE: HTTP is always 200; the real outcome is in response_code (C6)."
    }
    $description = $descParts -join " $EM "

    # --- url object
    $query = @()
    foreach ($q in $e.queryParams) {
        $qv = ''
        if ($null -ne $q.example) { $qv = "$($q.example)" }
        $qd = $q.description
        if ($q.required) { $qd = "REQUIRED. $qd" }
        $query += [ordered]@{
            key         = $q.name
            value       = $qv
            description = $qd
            disabled    = (-not $q.required)   # C11: optional filters ship visible but disabled
        }
    }
    $variables = @()
    foreach ($p in $e.pathParams) {
        $pv = ''
        if ($null -ne $p.example) { $pv = "$($p.example)" }
        $variables += [ordered]@{ key = $p.name; value = $pv; description = $p.description }
    }

    $rawUrl = "{{base_url}}$fullPath"
    if ($query.Count -gt 0) {
        $enabled = @($query | Where-Object { -not $_.disabled })
        if ($enabled.Count -gt 0) {
            $rawUrl += '?' + (($enabled | ForEach-Object { "$($_.key)=$($_.value)" }) -join '&')
        }
    }

    $url = [ordered]@{
        raw  = $rawUrl
        host = @('{{base_url}}')
        path = To-PathSegments $fullPath
    }
    if ($query.Count -gt 0)     { $url.query = $query }
    if ($variables.Count -gt 0) { $url.variable = $variables }

    # --- request
    $headers = @()
    $request = [ordered]@{
        method      = $e.method
        header      = $headers
        url         = $url
        description = $description
    }
    if ($e.auth -eq 'none') {
        $request.auth = [ordered]@{ type = 'noauth' }
    }
    if ($e.requestBody) {
        $ct = $e.requestBody.contentType
        if (-not $ct) { $ct = 'application/json' }
        $headers += [ordered]@{ key = 'Content-Type'; value = $ct }
        $request.header = $headers
        $request.body = [ordered]@{
            mode    = 'raw'
            raw     = (Json-Pretty $e.requestBody.example)
            options = [ordered]@{ raw = [ordered]@{ language = 'json' } }
        }
    }

    # --- saved responses (C3)
    $responses = @()
    $hasAnyExample = $false
    $hasSuccess   = $false
    foreach ($r in $e.responses) {
        if ([int]$r.status -ge 200 -and [int]$r.status -lt 300) { $hasSuccess = $true }
        $label = Get-ExampleLabel $r
        $rName = "$($r.status) $($r.description)"
        if ($label) { $rName = "$($r.status) [$label]" }
        if ($null -ne $r.example) { $hasAnyExample = $true }
        $bodyText = ''
        if ($null -ne $r.example) { $bodyText = (Json-Pretty $r.example) }
        $rHeaders = @()
        if ($r.problem) { $rHeaders += [ordered]@{ key = 'Content-Type'; value = 'application/problem+json' } }
        else            { $rHeaders += [ordered]@{ key = 'Content-Type'; value = 'application/json' } }
        $responses += [ordered]@{
            name                      = $rName
            status                    = $r.description
            code                      = $r.status
            header                    = $rHeaders
            body                      = $bodyText
            _postman_previewlanguage  = 'json'
        }
    }
    if (-not $hasAnyExample) { $noExample.Add("$($e.method) $($e.path)") }
    # An endpoint documented only by its failure modes is documented for the one
    # case nobody needs help with. Worth surfacing separately from "no examples
    # at all", because it reads as complete: there ARE responses, just no 2xx.
    if (-not $hasSuccess) { $noSuccess.Add("$($e.method) $($e.path)") }

    $item = [ordered]@{ name = $reqName; request = $request }
    if ($responses.Count -gt 0) { $item.response = $responses }

    if ($e.postResponseScript) {
        $item.event = @(
            [ordered]@{
                listen = 'test'
                script = [ordered]@{ type = 'text/javascript'; exec = @($e.postResponseScript) }
            }
        )
    }

    if (-not $folders.Contains($folderName)) {
        $folders[$folderName] = [System.Collections.Generic.List[object]]::new()
    }
    $folders[$folderName].Add($item)

    if ($e.smoke) { $smokeItems.Add($item) }
}

$items = @()
foreach ($k in $folders.Keys) {
    $items += [ordered]@{ name = $k; item = @($folders[$k]) }
}
if ($smokeItems.Count -gt 0) {
    # C13: login first, so the token variable is populated for the rest.
    $ordered = @($smokeItems | Sort-Object -Property @{ Expression = { if ($_.request.url.raw -match 'auth/login') { 0 } else { 1 } } })
    $items += [ordered]@{
        name = 'Smoke'
        item = $ordered
        description = "Runnable with: newman run <collection> --folder Smoke --env-var base_url=<host>. If newman is absent that is NOT RUN -- a generated folder is not evidence anything passes (C13)."
    }
}

$collDesc = $m.collection_description
if (-not $collDesc) { $collDesc = "SOURCE: API MANIFEST, NOT VERIFIED AGAINST A DEPLOYED MODULE." }
$collDesc = "$collDesc`n`n$fpMarker manifest-sha256=$fingerprint content-sha256=PENDING"

$variablesOut = @()
if ($m.variables) {
    foreach ($v in $m.variables) {
        $variablesOut += [ordered]@{ key = $v.key; value = $v.value; description = $v.description }
    }
} else {
    $variablesOut += [ordered]@{ key = 'base_url'; value = ''; description = 'Host and port only.' }
    $variablesOut += [ordered]@{ key = 'token';    value = ''; description = 'Bearer token -- never committed with a value (C4).' }
}

$collection = [ordered]@{
    info = [ordered]@{
        _postman_id = $collectionId
        name        = $collName
        description = $collDesc
        schema      = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    }
    item     = $items
    variable = $variablesOut
}
if (-not $m.auth -or $m.auth.type -eq 'bearer') {
    $tokenVar = 'token'
    if ($m.auth -and $m.auth.variable) { $tokenVar = $m.auth.variable }
    $collection.auth = [ordered]@{
        type   = 'bearer'
        bearer = @([ordered]@{ key = 'token'; value = "{{$tokenVar}}"; type = 'string' })
    }
}

# Emit with the hash slot blanked, hash that exact text, then substitute -- so the
# stored value is reproducible from the file itself on the next run.
$collectionText = Unescape-JsonAngles ($collection | ConvertTo-Json -Depth 40)
$contentHash    = Get-Sha256Hex $collectionText
$collectionText = $collectionText.Replace('content-sha256=PENDING', "content-sha256=$contentHash")
Write-Utf8NoBom -Path $OutCollection -Text $collectionText

# --- build api.md (C14) -------------------------------------------------------
$mdWritten = $false
if ($OutMarkdown) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# $collName $EM API Reference")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("GENERATED from ``$(Split-Path -Leaf $Manifest)`` by ``emit-collection.ps1``. Do not hand-edit.")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('|  |  |')
    [void]$sb.AppendLine('|---|---|')
    [void]$sb.AppendLine("| **Module** | ``$($m.module_name)`` |")
    [void]$sb.AppendLine("| **Base path** | ``$basePath`` |")
    $authType = 'bearer'
    if ($m.auth -and $m.auth.type) { $authType = $m.auth.type }
    [void]$sb.AppendLine("| **Auth** | $authType, collection-level variable (C4) |")
    [void]$sb.AppendLine("| **Source of truth** | SOURCE: API MANIFEST, NOT VERIFIED AGAINST A DEPLOYED MODULE (C15) |")
    [void]$sb.AppendLine("| **Collection** | ``$(Split-Path -Leaf $OutCollection)`` |")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Endpoint index')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Method | Path | Unit | Summary |')
    [void]$sb.AppendLine('|---|---|---|---|')
    foreach ($e in $m.endpoints) {
        $u = $e.unit
        if (-not $u) { $u = '-' }
        $s = $e.summary
        if (-not $s) { $s = '' }
        [void]$sb.AppendLine("| $($e.method) | ``$basePath/$($e.path.TrimStart('/'))`` | ``$u`` | $s |")
    }
    [void]$sb.AppendLine()

    $legacy = @($m.endpoints | Where-Object { $_.legacyEnvelope })

    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Endpoints')
    foreach ($e in $m.endpoints) {
        $fullPath = "$basePath/$($e.path.TrimStart('/'))"
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("### $($e.method) $fullPath")
        [void]$sb.AppendLine()
        $bits = @()
        if ($e.unit)   { $bits += "Unit ``$($e.unit)``" }
        if ($e.folder) { $bits += "Collection folder ``$($e.folder) / $($e.name)``" }
        if ($e.auth -eq 'none') { $bits += 'Auth: **none**' } else { $bits += 'Auth: bearer' }
        [void]$sb.AppendLine(($bits -join " $EM "))
        if ($e.summary) {
            [void]$sb.AppendLine()
            [void]$sb.AppendLine($e.summary)
        }
        if ($e.legacyEnvelope) {
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('> **Legacy response envelope.** HTTP status is always 200. The real outcome is carried in `response_code` in the body. See the Legacy response envelope section below.')
        }
        if ($e.pathParams) {
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('**Path variables**')
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('| Name | Description | Example |')
            [void]$sb.AppendLine('|---|---|---|')
            foreach ($p in $e.pathParams) { [void]$sb.AppendLine("| ``:$($p.name)`` | $($p.description) | ``$($p.example)`` |") }
        }
        if ($e.queryParams) {
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('**Query parameters**')
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('| Name | Required | Type | Description |')
            [void]$sb.AppendLine('|---|---|---|---|')
            foreach ($q in $e.queryParams) {
                $req = 'no'
                if ($q.required) { $req = '**yes**' }
                [void]$sb.AppendLine("| ``$($q.name)`` | $req | $($q.type) | $($q.description) |")
            }
        }
        if ($e.requestBody) {
            [void]$sb.AppendLine()
            $ct = $e.requestBody.contentType
            if (-not $ct) { $ct = 'application/json' }
            [void]$sb.AppendLine("**Request body** (``$ct``)")
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('```json')
            [void]$sb.AppendLine((Json-Pretty $e.requestBody.example))
            [void]$sb.AppendLine('```')
        }
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('**Responses**')
        [void]$sb.AppendLine()
        if (-not $e.responses -or $e.responses.Count -eq 0) {
            [void]$sb.AppendLine('`NO EXAMPLE CAPTURED` -- no responses declared in the manifest (C3).')
        } else {
            foreach ($r in $e.responses) {
                $label = Get-ExampleLabel $r
                $ctype = 'application/json'
                if ($r.problem) { $ctype = 'application/problem+json' }
                [void]$sb.AppendLine("**``$($r.status)``** $ARR $($r.description) (``$ctype``)")
                [void]$sb.AppendLine()
                if ($null -eq $r.example) {
                    [void]$sb.AppendLine('`NO EXAMPLE CAPTURED`')
                } else {
                    if ($label) { [void]$sb.AppendLine("``$label``") ; [void]$sb.AppendLine() }
                    [void]$sb.AppendLine('```json')
                    [void]$sb.AppendLine((Json-Pretty $r.example))
                    [void]$sb.AppendLine('```')
                }
                [void]$sb.AppendLine()
            }
        }
    }

    if ($legacy.Count -gt 0) {
        [void]$sb.AppendLine('---')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('## Legacy response envelope')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("These endpoints return HTTP 200 regardless of outcome and carry the real result in ``response_code``. This is ``api-contract`` A2's legacy pattern, documented as delivered rather than as intended $EM see C6.")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Method | Path |')
        [void]$sb.AppendLine('|---|---|')
        foreach ($e in $legacy) { [void]$sb.AppendLine("| $($e.method) | ``$basePath/$($e.path.TrimStart('/'))`` |") }
        [void]$sb.AppendLine()
    }

    Write-Utf8NoBom -Path $OutMarkdown -Text $sb.ToString()
    $mdWritten = $true
}

# --- report -------------------------------------------------------------------
$requestCount = 0
foreach ($k in $folders.Keys) { $requestCount += $folders[$k].Count }

Write-Host ''
Write-Host 'EMIT: OK' -ForegroundColor Green
Write-Host "  collection  $OutCollection"
Write-Host "              $requestCount request(s) in $($folders.Keys.Count) folder(s); smoke folder: $(if ($smokeItems.Count -gt 0) { "$($smokeItems.Count) request(s)" } else { 'none' })"
if ($mdWritten) { Write-Host "  markdown    $OutMarkdown" }
else            { Write-Host '  markdown    SKIPPED -- -OutMarkdown not supplied. C1: the two outputs can now drift.' -ForegroundColor Yellow }
Write-Host "  manifest    sha256=$($fingerprint.Substring(0,16))..."
if ($noExample.Count -gt 0) {
    Write-Host ''
    Write-Host "  $($noExample.Count) endpoint(s) have NO example response (C3) -- rendered as NO EXAMPLE CAPTURED, not invented:" -ForegroundColor Yellow
    $noExample | ForEach-Object { Write-Host "    $_" }
}
if ($noSuccess.Count -gt 0) {
    Write-Host ''
    Write-Host "  $($noSuccess.Count) endpoint(s) declare NO 2xx response (C5) -- documented only by their failures:" -ForegroundColor Yellow
    $noSuccess | ForEach-Object { Write-Host "    $_" }
}
Write-Host ''
Write-Host '  Nothing was executed against a server. A generated collection is not evidence'
Write-Host '  that any endpoint works.'
exit 0
