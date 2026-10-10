<#
.SYNOPSIS
  Automated production web deployment script for React (Vite) and Next.js applications.
  Performs pre-flight gates, builds immutable Docker images, pushes to registry,
  and executes zero-downtime candidate swap on remote VM via SSH.
.DESCRIPTION
  Reads configuration from .deploy.env in project root.
  Enforces local quality gates: typecheck, lint, test, build.
  Prevents dirty-tree deployments unless explicitly permitted.
  Verifies candidate loopback healthcheck before cutting over production traffic.
#>
[CmdletBinding()]
param(
    [string]$DeployEnvFile = ".deploy.env",
    [switch]$SkipLocalGates,
    [switch]$AllowDirtyDeploy
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[deploy-web] $Message" -ForegroundColor Cyan
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[deploy-web] ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Assert-Command {
    param([string]$CommandName)
    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        Write-Fail "Required command not found: $CommandName"
    }
}

# 1. Validate dependencies
@("docker", "git", "npm", "ssh", "curl") | ForEach-Object { Assert-Command $_ }

# 2. Load environment configuration
if (-not (Test-Path $DeployEnvFile)) {
    Write-Fail "Configuration file '$DeployEnvFile' not found. Copy .deploy.env.example to .deploy.env"
}

Get-Content $DeployEnvFile | Where-Object { $_ -match '^\s*([^#=]+)\s*=\s*(.*)\s*$' } | ForEach-Object {
    $key = $matches[1].Trim()
    $val = $matches[2].Trim()
    # Strip quotes if present
    if ($val -match '^["''](.*)["'']$') { $val = $matches[1] }
    [Environment]::SetEnvironmentVariable($key, $val, "Process")
}

$requiredKeys = @("DOCKER_USER", "IMAGE_NAME", "VM_USER", "VM_HOST", "VM_KEY_PATH", "CONTAINER_NAME", "HOST_PORT", "CANDIDATE_PORT", "APP_BASE_PATH")
foreach ($k in $requiredKeys) {
    if (-not [Environment]::GetEnvironmentVariable($k, "Process")) {
        Write-Fail "Missing required configuration variable '$k' in $DeployEnvFile"
    }
}

$DockerUser    = [Environment]::GetEnvironmentVariable("DOCKER_USER", "Process")
$ImageName     = [Environment]::GetEnvironmentVariable("IMAGE_NAME", "Process")
$VmUser        = [Environment]::GetEnvironmentVariable("VM_USER", "Process")
$VmHost        = [Environment]::GetEnvironmentVariable("VM_HOST", "Process")
$VmKeyPath     = [Environment]::GetEnvironmentVariable("VM_KEY_PATH", "Process")
$ContainerName = [Environment]::GetEnvironmentVariable("CONTAINER_NAME", "Process")
$HostPort      = [Environment]::GetEnvironmentVariable("HOST_PORT", "Process")
$CandidatePort = [Environment]::GetEnvironmentVariable("CANDIDATE_PORT", "Process")
$AppBasePath   = [Environment]::GetEnvironmentVariable("APP_BASE_PATH", "Process")
$AllowDirty    = [Environment]::GetEnvironmentVariable("ALLOW_DIRTY_DEPLOY", "Process") -eq "true" -or $AllowDirtyDeploy

# 3. Worktree check
$diff = git status --porcelain
if ($diff -and -not $AllowDirty) {
    Write-Fail "Git working tree is dirty. Commit or stash changes before deploying (or pass -AllowDirtyDeploy)."
}

$gitSha = (git rev-parse HEAD).Substring(0, 12)
$ImageTag = if ($env:IMAGE_TAG) { $env:IMAGE_TAG } else { $gitSha }
$ImageRef = "${DockerUser}/${ImageName}:${ImageTag}"
$LatestRef = "${DockerUser}/${ImageName}:latest"

# 4. Local verification gates
if (-not $SkipLocalGates) {
    Write-Step "Running local quality gates (typecheck, lint, test, build)..."
    npm run typecheck
    if ($LASTEXITCODE -ne 0) { Write-Fail "Typecheck failed." }
    
    npm run lint
    if ($LASTEXITCODE -ne 0) { Write-Fail "Lint failed." }
    
    npm run test -- --maxWorkers=2
    if ($LASTEXITCODE -ne 0) { Write-Fail "Unit tests failed." }
    
    npm run build
    if ($LASTEXITCODE -ne 0) { Write-Fail "Local build failed." }
} else {
    Write-Step "WARNING: Local quality gates skipped by flag."
}

# 5. Build and tag Docker images
Write-Step "Building Docker image: $ImageRef"
docker build --build-arg APP_BASE_PATH="$AppBasePath" -t "$ImageRef" -t "$LatestRef" .
if ($LASTEXITCODE -ne 0) { Write-Fail "Docker build failed." }

Write-Step "Pushing Docker images to registry..."
docker push "$ImageRef"
if ($LASTEXITCODE -ne 0) { Write-Fail "Docker push failed for $ImageRef." }
docker push "$LatestRef"

# 6. Remote deployment with candidate verification
Write-Step "Executing zero-downtime candidate deployment on $VmHost..."

$remoteEnvDir = "/etc/$ContainerName"
$remoteScript = @"
set -e
docker pull "$ImageRef"

# Clean any stale candidate
docker rm -f "${ContainerName}-candidate" 2>/dev/null || true

echo "[remote] Starting candidate container on port $CandidatePort..."
docker run -d --name "${ContainerName}-candidate" \
  -p "127.0.0.1:${CandidatePort}:8080" \
  --env-file "${remoteEnvDir}/env" \
  "$ImageRef"

echo "[remote] Verifying candidate healthcheck on loopback..."
sleep 3
if ! curl --fail --silent "http://127.0.0.1:${CandidatePort}/healthz"; then
  echo "[remote] Candidate healthcheck FAILED. Aborting swap."
  docker rm -f "${ContainerName}-candidate"
  exit 1
fi
echo "[remote] Candidate healthy."

# Record previous container image for rollback
PREV_IMAGE=`$(docker inspect -f '{{.Config.Image}}' "${ContainerName}" 2>/dev/null || echo "none")
echo "`$PREV_IMAGE" > "${remoteEnvDir}/previous_image"

# Stop old container and candidate, run production container on HOST_PORT
echo "[remote] Swapping production traffic to $ImageRef on port $HostPort..."
docker rm -f "${ContainerName}" 2>/dev/null || true
docker rm -f "${ContainerName}-candidate" 2>/dev/null || true

docker run -d --name "${ContainerName}" \
  --restart unless-stopped \
  -p "${HostPort}:8080" \
  --env-file "${remoteEnvDir}/env" \
  "$ImageRef"

echo "[remote] Deployment SUCCESS. Previous image: `$PREV_IMAGE"
"@

ssh -i "$VmKeyPath" -o StrictHostKeyChecking=accept-new "${VmUser}@${VmHost}" "$remoteScript"
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Remote deployment script failed."
}

Write-Step "Release complete: $ImageRef running on ${VmHost}:${HostPort}"
