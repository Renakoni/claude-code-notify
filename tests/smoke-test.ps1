param(
    [string]$LogPath = "$env:TEMP\claude-code-notify.log",
    [string]$ConfigPath = ""
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$notifyScript = Join-Path $repoRoot 'scripts\notify.ps1'
$types = @('permission', 'complete', 'subagent', 'error')

Write-Host "Claude Code Notify smoke test"
Write-Host "Notify script: $notifyScript"
Write-Host "Log path: $LogPath"
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    Write-Host "Config path: $ConfigPath"
}
Write-Host ""

foreach ($type in $types) {
    Write-Host "Testing sound type: $type"
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $notifyScript, '-Type', $type, '-LogPath', $LogPath)
    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
        $arguments += @('-ConfigPath', $ConfigPath)
    }

    powershell @arguments

    if ($LASTEXITCODE -ne 0) {
        throw "notify.ps1 failed for type '$type' with exit code $LASTEXITCODE"
    }

    Start-Sleep -Milliseconds 250
}

Write-Host ""
Write-Host "Smoke test finished. Recent log lines:"
if (Test-Path $LogPath) {
    Get-Content $LogPath -Tail 20
} else {
    Write-Host "Log file was not created."
}
