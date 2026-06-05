<#
.SYNOPSIS
Resets and restarts the entire Lakehouse-Unplugged stack with automatic Polaris credential handling.

.DESCRIPTION
Performs docker compose down (with optional --volumes), starts Polaris, auto-extracts credentials,
and brings up the full stack. Handles credential persistence across restarts.
Now includes a Docker daemon health check to prevent hangs if Docker is not running.

.PARAMETER FullReset
Include --volumes flag to delete all data (SeaweedFS, Polaris, etc.)

.PARAMETER Timeout
Seconds to wait for Polaris to become healthy (default: 60)

.EXAMPLE
# Quick reset (keeps volumes/data)
.\scripts\Reset-Lakehouse.ps1

# Full reset (deletes all data)
.\scripts\Reset-Lakehouse.ps1 -FullReset

# Wait 90 seconds for Polaris
.\scripts\Reset-Lakehouse.ps1 -Timeout 90
#>

param(
    [switch]$FullReset,
    [int]$Timeout = 60
)

$ErrorActionPreference = "Stop"

# Colors for output
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"
$Cyan = "Cyan"
$Gray = "Gray"
$White = "White"

Write-Host "🔄 Resetting Lakehouse-Unplugged stack..." -ForegroundColor $Cyan

# --------------------------------------------------------------------
# Step 0: Verify Docker daemon is running
# --------------------------------------------------------------------
Write-Host "🧠 Checking Docker daemon availability..." -ForegroundColor $Yellow
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0 -or $dockerInfo -match "error during connect") {
        throw "Docker daemon not available"
    }
    Write-Host "✅ Docker daemon is responding" -ForegroundColor $Green
} catch {
    Write-Host "❌ Docker daemon not running or unreachable." -ForegroundColor $Red
    Write-Host "💡 Please start Docker Desktop and verify 'docker info' works before retrying." -ForegroundColor $Cyan
    exit 1
}

# --------------------------------------------------------------------
# Step 1: Stop existing stack
# --------------------------------------------------------------------
Write-Host "⏹️  Stopping existing containers..." -ForegroundColor $Yellow
if ($FullReset) {
    Write-Host "   ⚠️  Full reset: deleting volumes!" -ForegroundColor $Red
    docker compose down --volumes --remove-orphans
} else {
    docker compose down --remove-orphans
}

# --------------------------------------------------------------------
# Step 2: Start Polaris first to generate credentials
# --------------------------------------------------------------------
Write-Host "🚀 Starting Polaris (credential generation)..." -ForegroundColor $Green
docker compose up -d polaris seaweedfs

# --------------------------------------------------------------------
# Step 3: Wait for Polaris API to respond
# --------------------------------------------------------------------
Write-Host "⏳ Waiting for Polaris API to respond (up to $Timeout seconds)..." -ForegroundColor $Yellow
$RetryInterval = 2
$MaxRetries = [math]::Ceiling($Timeout / $RetryInterval)

for ($i = 0; $i -lt $MaxRetries; $i++) {
    try {
        $Response = Invoke-WebRequest -Uri "http://localhost:8181/q/health" -UseBasicParsing -TimeoutSec 15
        if ($Response.StatusCode -eq 200) {
            Write-Host "✅ Polaris API is responding!" -ForegroundColor $Green
            break
        }
    } catch {
        Write-Host "   API check failed: $($_.Exception.Message)" -ForegroundColor $Gray
    }

    Start-Sleep -Seconds $RetryInterval
    Write-Host "   Still waiting... ($($i * $RetryInterval)s elapsed)" -ForegroundColor $Gray

    if ($i -gt 10 -and ($i % 5 -eq 0)) {
        Write-Host "   Polaris logs (last 3 lines):" -ForegroundColor $Gray
        docker logs --tail 3 polaris 2>$null
    }
}

if ($i -eq $MaxRetries) {
    Write-Host "❌ Polaris API did not respond within $Timeout seconds" -ForegroundColor $Red
    Write-Host "   Check logs: docker logs polaris" -ForegroundColor $Red
    Write-Host "   Try manually: curl http://localhost:8181/q/health" -ForegroundColor $Red
    exit 1
}

# --------------------------------------------------------------------
# Step 4: Extract credentials automatically
# --------------------------------------------------------------------
Write-Host "🔑 Extracting Polaris credentials..." -ForegroundColor $Yellow

function Get-PolarisCredentials {
    param(
        [int]$Tail = 200
    )

    $logOutput = docker logs polaris --tail $Tail --since 5m 2>&1
    $credentialMatches = $logOutput | Select-String "root principal credentials:" -AllMatches

    if (-not $credentialMatches) {
        return $null
    }

    # Use the most recent match to avoid stale credentials from earlier runs
    $latestMatch = $credentialMatches[-1].Line
    if ($latestMatch -match "id=(\S+)\s+secret=(\S+)") {
        return [PSCustomObject]@{
            ClientId     = $matches[1]
            ClientSecret = $matches[2]
        }
    }

    return $null
}

$Credentials = Get-PolarisCredentials

if (-not $Credentials) {
    Write-Host "❌ Could not parse Polaris credentials from logs" -ForegroundColor $Red
    Write-Host "   Try checking recent output: docker logs polaris --tail 50" -ForegroundColor $Gray
    exit 1
}

$CLIENT_ID = $Credentials.ClientId
$CLIENT_SECRET = $Credentials.ClientSecret

# Safely update .env
$EnvPath = ".\.env"
$ExistingEnv = if (Test-Path $EnvPath) { Get-Content $EnvPath -Raw } else { "" }

if ($FullReset -or -not ($ExistingEnv -match "POLARIS_CLIENT_ID")) {
    Write-Host "💾 Writing new .env file..." -ForegroundColor $Cyan
    @"
# S3-compatible object storage
S3_ENDPOINT=http://seaweedfs:8333
AWS_ACCESS_KEY_ID=lakehouse
AWS_SECRET_ACCESS_KEY=lakehouse-secret-key
AWS_REGION=us-east-1
AWS_DEFAULT_REGION=us-east-1

# Spark worker instellingen
SPARK_WORKER_MEMORY=2G
SPARK_WORKER_CORES=2

# Polaris (auto-generated - do not edit manually)
POLARIS_CLIENT_ID=$CLIENT_ID
POLARIS_CLIENT_SECRET=$CLIENT_SECRET
"@ | Out-File -FilePath $EnvPath -Encoding utf8
} else {
    Write-Host "🟢 Existing .env found — updating Polaris credentials only..." -ForegroundColor $Yellow
    (Get-Content $EnvPath) |
        ForEach-Object {
            $_ -replace "POLARIS_CLIENT_ID=.*", "POLARIS_CLIENT_ID=$CLIENT_ID" `
               -replace "POLARIS_CLIENT_SECRET=.*", "POLARIS_CLIENT_SECRET=$CLIENT_SECRET"
        } | Set-Content $EnvPath -Encoding utf8
}

Write-Host "✅ Credentials saved to .env" -ForegroundColor $Green
Write-Host "   Client ID: $($CLIENT_ID.Substring(0,8))..." -ForegroundColor $Gray

# --------------------------------------------------------------------
# Step 5: Start remaining services
# --------------------------------------------------------------------
Write-Host "🚀 Starting remaining services..." -ForegroundColor $Green
docker compose --env-file .env up -d

# --------------------------------------------------------------------
# Step 6: Wait for all services to be healthy
# --------------------------------------------------------------------
Write-Host "⏳ Waiting for services to be healthy..." -ForegroundColor $Yellow
Start-Sleep -Seconds 40

$Services = @("polaris", "seaweedfs", "spark-master", "spark-worker", "thrift-server", "dev")
foreach ($Service in $Services) {
    $Status = docker inspect $Service --format='{{.State.Health.Status}}' 2>$null
    if (-not $Status) { $Status = "no healthcheck" }
    switch ($Status) {
        "healthy"   { Write-Host "✅ $Service is healthy" -ForegroundColor $Green }
        "starting"  { Write-Host "⏳ $Service is still starting" -ForegroundColor $Yellow }
        default     { Write-Host "⚠️  $Service status: $Status" -ForegroundColor $Gray }
    }
}

# --------------------------------------------------------------------
# Step 7: Final summary
# --------------------------------------------------------------------
Write-Host "`n----------------------------------------------------" -ForegroundColor $Cyan
Write-Host "✅ Lakehouse-Unplugged stack is ready!" -ForegroundColor $Green
Write-Host "----------------------------------------------------" -ForegroundColor $Cyan
Write-Host "🌐 Services:" -ForegroundColor $Cyan
Write-Host "   SeaweedFS S3:   http://localhost:8333" -ForegroundColor $White
Write-Host "   Spark UI:       http://localhost:8080" -ForegroundColor $White
Write-Host "   Polaris API:    http://localhost:8181" -ForegroundColor $White
Write-Host "   Thrift Server:  localhost:10000" -ForegroundColor $White
Write-Host "   Jupyter:        http://localhost:8888" -ForegroundColor $White
Write-Host "`n🔑 Polaris Credentials (saved to .env):" -ForegroundColor $Cyan
Write-Host "   Client ID:      $($CLIENT_ID.Substring(0, 8))..." -ForegroundColor $White
Write-Host "   Client Secret:  $($CLIENT_SECRET.Substring(0, 8))..." -ForegroundColor $White
Write-Host "`n💡 Next steps:" -ForegroundColor $Cyan
Write-Host "   1. Open VS Code" -ForegroundColor $White
Write-Host "   2. Reopen in dev container (if not automatic)" -ForegroundColor $White
Write-Host "   3. In terminal, run: test_polaris" -ForegroundColor $White
Write-Host "   4. Or manually: docker exec -it dev bash" -ForegroundColor $White
Write-Host "----------------------------------------------------" -ForegroundColor $Cyan
