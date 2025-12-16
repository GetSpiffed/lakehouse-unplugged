<#
.SYNOPSIS
    Forcefully stops all Docker Desktop related processes and WSL2 memory.

.DESCRIPTION
    Terminates all Docker Desktop processes including the main application,
    backend services, proxy, and WSL2 virtual machine memory. Use when 
    Docker Desktop is unresponsive or needs a complete reset.

.NOTES
    Requires Administrator privileges for some processes.
    Will silently continue if processes are not found.
#>

[CmdletBinding()]
param()

Write-Host "🛑 Stopping Docker Desktop processes..." -ForegroundColor Yellow

$dockerProcesses = @(
    "Docker Desktop",
    "com.docker.backend", 
    "com.docker.service",
    "com.docker.proxy",
    "vmmem"
)

foreach ($process in $dockerProcesses) {
    try {
        $proc = Get-Process -Name $process -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "  Terminating $process (PID: $($proc.Id))..." -ForegroundColor Gray
            Stop-Process -Name $process -Force -ErrorAction Stop
            Write-Host "  ✅ Stopped $process" -ForegroundColor Green
        } else {
            Write-Host "  ℹ️  $process not running" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  ⚠️  Failed to stop $process`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n✅ Docker Desktop shutdown complete" -ForegroundColor Cyan
Write-Host "`n💡 Next steps:" -ForegroundColor White
Write-Host "   • Start Docker Desktop again from Start Menu" -ForegroundColor White
Write-Host "   • Or run: Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'" -ForegroundColor White