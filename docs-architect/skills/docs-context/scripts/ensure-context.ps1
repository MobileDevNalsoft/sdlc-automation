<#
.SYNOPSIS
  Detect and optionally establish the 3-tier agent context.

.DESCRIPTION
  Tier 1  .code-review-graph/graph.db   AST / blast radius   (external CLI)
  Tier 2  graphify-out/graph.json       structural graph     (external CLI)
  Tier 3  llmwiki/*.md                  architecture memory  (AGENT-AUTHORED)

  Reports one row per tier using the four states sdlc-core's evidence
  contract requires. A tier whose tool is absent is NOT RUN -- never PASS.

  Tier 3 can be SCAFFOLDED here but never COMPLETED here: there is no llmwiki
  tool. This script writes placeholder files that an agent must then fill in,
  and reports them as STUB so nobody mistakes a placeholder for real content.

.PARAMETER Mode
  Detect  - report only, change nothing (default)
  Ensure  - create what is missing
  Refresh - incrementally update what already exists

.EXAMPLE
  ./ensure-context.ps1
  ./ensure-context.ps1 -Mode Ensure
  ./ensure-context.ps1 -Mode Refresh
#>
[CmdletBinding()]
param(
    [ValidateSet('Detect', 'Ensure', 'Refresh')]
    [string]$Mode = 'Detect',

    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Continue'

$results = [System.Collections.Generic.List[object]]::new()
function Add-Result {
    param($Tier, $Artifact, $Result, $Detail)
    $results.Add([pscustomobject]@{
        Tier = $Tier; Artifact = $Artifact; Result = $Result; Detail = $Detail
    })
}

function Test-Tool {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { return $null }
    return $cmd.Source
}

Write-Host "docs-context: mode=$Mode root=$RepoRoot"
Write-Host ''

# ---------------------------------------------------------------- Tier 1 ----
# TWO verified gotchas, both found by running this (2026-07-31):
#
# 1. `code-review-graph` operates on the CURRENT WORKING DIRECTORY. It has no
#    --path flag. Invoked without cd-ing first, it builds a graph of wherever
#    the agent happens to be and cheerfully reports success -- so a caller
#    would get a graph of the wrong repo with no error. Every invocation below
#    is wrapped in Push-Location.
#
# 2. `status` is NOT a read-only probe: in a repo with no graph it CREATES
#    .code-review-graph/ and migrates an empty DB, then reports
#    "Nodes: 0 ... Last updated: never". So "does the directory exist" is not a
#    valid existence test -- the node count is.
$crgPath = Join-Path $RepoRoot '.code-review-graph/graph.db'
$crgTool = Test-Tool 'code-review-graph'

function Invoke-Crg {
    param([string]$Root, [string[]]$CrgArgs)
    Push-Location $Root
    try { return (& code-review-graph @CrgArgs 2>&1 | Out-String) }
    finally { Pop-Location }
}

function Get-CrgNodeCount {
    param([string]$Root)
    try {
        $out = Invoke-Crg -Root $Root -CrgArgs @('status')
        if ($out -match 'Nodes:\s*(\d+)') { return [int]$Matches[1] }
    } catch { }
    return -1
}

if ($null -eq $crgTool) {
    Add-Result 1 '.code-review-graph/graph.db' 'NOT RUN' 'code-review-graph not on PATH'
}
else {
    $nodes = Get-CrgNodeCount -Root $RepoRoot

    if ($nodes -gt 0 -and $Mode -ne 'Refresh') {
        Add-Result 1 '.code-review-graph/graph.db' 'PRESENT' "$nodes nodes"
    }
    elseif ($Mode -eq 'Detect') {
        Add-Result 1 '.code-review-graph/graph.db' 'MISSING' 'empty graph; run -Mode Ensure'
    }
    elseif ($Mode -eq 'Refresh' -and $nodes -gt 0) {
        Invoke-Crg -Root $RepoRoot -CrgArgs @('update') | Out-Null
        $n2 = Get-CrgNodeCount -Root $RepoRoot
        Add-Result 1 '.code-review-graph/graph.db' 'REFRESHED' "$n2 nodes"
    }
    else {
        Invoke-Crg -Root $RepoRoot -CrgArgs @('build') | Out-Null
        $n2 = Get-CrgNodeCount -Root $RepoRoot
        if ($n2 -gt 0) { Add-Result 1 '.code-review-graph/graph.db' 'CREATED' "$n2 nodes" }
        else { Add-Result 1 '.code-review-graph/graph.db' 'NOT RUN' 'build produced 0 nodes -- check language support for this stack' }
    }
}

# ---------------------------------------------------------------- Tier 2 ----
# VERIFIED 2026-07-31: `graphify update <path>` writes graph.json under the
# TARGET path, but writes its incremental-extraction cache (manifest.json,
# keyed by absolute paths) into ./graphify-out relative to the CURRENT
# WORKING DIRECTORY. Invoking it from elsewhere therefore litters the caller's
# directory with a half-populated graphify-out/. Always run it from $RepoRoot.
$gfPath = Join-Path $RepoRoot 'graphify-out/graph.json'
$gfTool = Test-Tool 'graphify'

function Invoke-Graphify {
    param([string]$Root)
    Push-Location $Root
    try { & graphify update $Root *>&1 | Out-Null }
    finally { Pop-Location }
}

if ($null -eq $gfTool) {
    Add-Result 2 'graphify-out/graph.json' 'NOT RUN' 'graphify not on PATH'
}
elseif (Test-Path $gfPath) {
    if ($Mode -eq 'Refresh') {
        Invoke-Graphify -Root $RepoRoot
        Add-Result 2 'graphify-out/graph.json' 'REFRESHED' 'graphify update'
    }
    else {
        $sizeKb = [math]::Round((Get-Item $gfPath).Length / 1KB, 1)
        Add-Result 2 'graphify-out/graph.json' 'PRESENT' "$sizeKb KB"
    }
}
elseif ($Mode -eq 'Detect') {
    Add-Result 2 'graphify-out/graph.json' 'MISSING' 'run -Mode Ensure'
}
else {
    Invoke-Graphify -Root $RepoRoot
    if (Test-Path $gfPath) { Add-Result 2 'graphify-out/graph.json' 'CREATED' 'graphify update' }
    else { Add-Result 2 'graphify-out/graph.json' 'NOT RUN' 'graphify produced no graph.json' }
}

# ---------------------------------------------------------------- Tier 3 ----
# There is NO llmwiki tool. This tier is authored. The most this script can
# honestly do is scaffold placeholders and label them STUB.
$wikiDir   = Join-Path $RepoRoot 'llmwiki'
$wikiIndex = Join-Path $wikiDir 'index.md'
$stubMark  = '<!-- STUB: written by docs-context, NOT yet filled in by an agent -->'

if (Test-Path $wikiIndex) {
    $isStub = (Get-Content $wikiIndex -Raw -ErrorAction SilentlyContinue) -match [regex]::Escape($stubMark)
    if ($isStub) { Add-Result 3 'llmwiki/index.md' 'STUB' 'placeholder only -- an agent must write it' }
    else         { Add-Result 3 'llmwiki/index.md' 'PRESENT' 'authored' }
}
elseif ($Mode -eq 'Detect') {
    Add-Result 3 'llmwiki/index.md' 'MISSING' 'run -Mode Ensure to scaffold'
}
else {
    if (-not (Test-Path $wikiDir)) { New-Item -ItemType Directory -Path $wikiDir -Force | Out-Null }

    $files = @{
        'index.md'        = "# LLM Wiki Index`n`n$stubMark`n`nRouting map for agents. Keep this file LINKS, not content.`n`n- [Architecture](architecture.md)`n- [Deployment](deployment.md)`n- [Conventions](conventions.md)`n`n## Context rules for this repo`n`n1. Read this index before opening source files.`n2. Use the AST graph for blast radius; the structural graph for cross-stack relationships.`n3. After structural changes, refresh both graphs and update these documents.`n"
        'architecture.md' = "# Architecture`n`n$stubMark`n`nSystem design, entry points, components, data flow. Written from what the code ACTUALLY does -- where that differs from the intended design, record the real behaviour and note the gap.`n"
        'deployment.md'   = "# Deployment`n`n$stubMark`n`nBuild, environments, CI/CD, and how secrets are supplied. Never record a secret VALUE here.`n"
        'conventions.md'  = "# Conventions`n`n$stubMark`n`nCoding standards, state management, API patterns. Prefer linking to the owning skill over restating it.`n"
    }
    foreach ($f in $files.Keys) {
        $p = Join-Path $wikiDir $f
        if (-not (Test-Path $p)) { Set-Content -Path $p -Value $files[$f] -Encoding utf8 }
    }
    Add-Result 3 'llmwiki/index.md' 'STUB' 'scaffolded -- an agent must now write it'
}

# ---------------------------------------------------------------- report ----
Write-Host '## 3-tier context'
Write-Host '| Tier | Artifact | Result | Detail |'
Write-Host '|---|---|---|---|'
foreach ($r in $results) {
    Write-Host ("| {0} | {1} | {2} | {3} |" -f $r.Tier, $r.Artifact, $r.Result, $r.Detail)
}
Write-Host ''

# Only these two states mean a tier is actually usable. Anything else -- MISSING,
# NOT RUN, STUB -- is not. Enumerating the GOOD states rather than the bad ones
# is deliberate: a future state added to this script defaults to "not usable"
# instead of silently counting as success.
$goodStates = @('PRESENT', 'CREATED', 'REFRESHED')

$notRun  = @($results | Where-Object { $_.Result -eq 'NOT RUN' })
$stubs   = @($results | Where-Object { $_.Result -eq 'STUB' })
$missing = @($results | Where-Object { $_.Result -eq 'MISSING' })
$unusable = @($results | Where-Object { $goodStates -notcontains $_.Result })

if ($missing.Count -gt 0) {
    Write-Host "CONTEXT-MISSING: $($missing.Count) tier(s) absent. Re-run with -Mode Ensure."
}
if ($notRun.Count -gt 0) {
    Write-Host "CONTEXT-INCOMPLETE: $($notRun.Count) tier(s) NOT RUN (tool absent). This is NOT a pass --"
    Write-Host "an agent relying on a tier that was never built will get confident wrong answers."
}
if ($stubs.Count -gt 0) {
    Write-Host "CONTEXT-STUB: $($stubs.Count) llmwiki file(s) are placeholders. Dispatch docs-onboarding to author them."
}
if ($unusable.Count -eq 0) {
    Write-Host 'CONTEXT-OK: all three tiers present and usable.'
}
else {
    Write-Host "CONTEXT-NOT-OK: $($unusable.Count) of $($results.Count) tier(s) unusable."
    exit 1
}
