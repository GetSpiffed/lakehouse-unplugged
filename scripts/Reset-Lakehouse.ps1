<#
.SYNOPSIS
Resets and restarts the Lakehouse-Unplugged stack.

.DESCRIPTION
Stops the Compose stack, optionally removes its named volumes, and starts the
full stack. RustFS bucket initialization and Polaris JDBC bootstrap are handled
by idempotent one-shot Compose services.

.PARAMETER FullReset
Remove all Compose-managed volumes, including RustFS, Polaris, Trino, and
Airflow data. Existing data is retained unless this switch is explicitly used.

.PARAMETER Timeout
Seconds to wait for initialization and service health checks (default: 120).

.EXAMPLE
.\scripts\Reset-Lakehouse.ps1

.EXAMPLE
.\scripts\Reset-Lakehouse.ps1 -FullReset
#>

param(
    [switch]$FullReset,
    [int]$Timeout = 120
)

$ErrorActionPreference = "Stop"

$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"
$Cyan = "Cyan"
$Gray = "Gray"
$White = "White"

function Get-ComposeContainerId {
    param([string]$Service)

    return (docker compose ps -q $Service 2>$null | Select-Object -First 1)
}

function Wait-ForCompletedService {
    param(
        [string]$Service,
        [int]$TimeoutSeconds
    )

    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $Deadline) {
        $ContainerId = Get-ComposeContainerId -Service $Service
        if ($ContainerId) {
            $State = docker inspect $ContainerId --format='{{.State.Status}}:{{.State.ExitCode}}' 2>$null
            if ($State -eq "exited:0") {
                Write-Host "✅ $Service completed successfully" -ForegroundColor $Green
                return
            }
            if ($State -match '^exited:(?!0$)') {
                throw "$Service failed ($State). Check: docker compose logs $Service"
            }
        }
        Start-Sleep -Seconds 2
    }

    throw "Timed out waiting for $Service. Check: docker compose logs $Service"
}

function Wait-ForHealthyService {
    param(
        [string]$Service,
        [int]$TimeoutSeconds
    )

    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $Deadline) {
        $ContainerId = Get-ComposeContainerId -Service $Service
        if ($ContainerId) {
            $Health = docker inspect $ContainerId --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>$null
            if ($Health -eq "healthy") {
                Write-Host "✅ $Service is healthy" -ForegroundColor $Green
                return
            }
            if ($Health -eq "exited" -or $Health -eq "dead") {
                throw "$Service stopped before becoming healthy. Check: docker compose logs $Service"
            }
        }
        Start-Sleep -Seconds 2
    }

    throw "Timed out waiting for $Service. Check: docker compose logs $Service"
}

Write-Host "🔄 Resetting Lakehouse-Unplugged stack..." -ForegroundColor $Cyan
Write-Host "🧠 Checking Docker daemon availability..." -ForegroundColor $Yellow

try {
    $DockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0 -or $DockerInfo -match "error during connect") {
        throw "Docker daemon not available"
    }
    Write-Host "✅ Docker daemon is responding" -ForegroundColor $Green
} catch {
    Write-Host "❌ Docker daemon not running or unreachable." -ForegroundColor $Red
    Write-Host "💡 Start Docker Desktop and verify 'docker info' before retrying." -ForegroundColor $Cyan
    exit 1
}

Write-Host "⏹️  Stopping existing containers..." -ForegroundColor $Yellow
if ($FullReset) {
    Write-Host "   ⚠️  Full reset: deleting all Compose-managed volumes." -ForegroundColor $Red
    docker compose down --volumes --remove-orphans
} else {
    docker compose down --remove-orphans
}

Write-Host "🚀 Starting the stack..." -ForegroundColor $Green
docker compose --env-file .env up -d
if ($LASTEXITCODE -ne 0) {
    throw "docker compose up failed"
}

Write-Host "⏳ Verifying initialization and health..." -ForegroundColor $Yellow
foreach ($Service in @("polaris-admin", "object-storage-init", "polaris-bootstrap")) {
    Wait-ForCompletedService -Service $Service -TimeoutSeconds $Timeout
}
foreach ($Service in @("rustfs", "polaris", "trino")) {
    Wait-ForHealthyService -Service $Service -TimeoutSeconds $Timeout
}

docker compose ps

Write-Host "`n----------------------------------------------------" -ForegroundColor $Cyan
Write-Host "✅ Lakehouse-Unplugged stack is ready!" -ForegroundColor $Green
Write-Host "----------------------------------------------------" -ForegroundColor $Cyan
Write-Host "🌐 Services:" -ForegroundColor $Cyan
Write-Host "   RustFS Console: http://localhost:9001" -ForegroundColor $White
Write-Host "   S3 API:         http://localhost:9000" -ForegroundColor $White
Write-Host "   Spark UI:       http://localhost:8080" -ForegroundColor $White
Write-Host "   Polaris API:    http://localhost:8181" -ForegroundColor $White
Write-Host "   Trino UI:       http://localhost:8088" -ForegroundColor $White
Write-Host "   Thrift Server:  localhost:10000" -ForegroundColor $White
Write-Host "   Jupyter:        http://localhost:8888" -ForegroundColor $White
Write-Host "`n💡 Credentials and generic S3 settings are read from .env." -ForegroundColor $Gray
Write-Host "----------------------------------------------------" -ForegroundColor $Cyan
