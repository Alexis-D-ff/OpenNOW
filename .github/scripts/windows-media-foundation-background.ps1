param(
    [Parameter(Mandatory)]
    [ValidateSet("Start", "Run", "Wait")]
    [string]$Action
)
$ErrorActionPreference = "Stop"

$state = Join-Path $env:RUNNER_TEMP "windows-media-foundation"
$log = Join-Path $state "install.log"
$done = Join-Path $state "done"

switch ($Action) {
    "Start" {
        New-Item -ItemType Directory -Force $state | Out-Null
        Start-Process pwsh -WindowStyle Hidden -ArgumentList @(
            "-NoProfile", "-NonInteractive", "-File", "`"$PSCommandPath`"", "Run")
        Write-Host "Started the Windows Media Foundation installation in the background."
    }
    "Run" {
        $started = Get-Date
        try {
            & (Join-Path $PSScriptRoot "ensure-windows-media-foundation.ps1") *> $log
        } catch {
            $_ | Out-String | Add-Content $log
        } finally {
            "Finished after $([int]((Get-Date) - $started).TotalSeconds)s" | Add-Content $log
            New-Item -ItemType File -Force $done | Out-Null
        }
    }
    "Wait" {
        $started = Get-Date
        while (-not (Test-Path $done)) {
            if (((Get-Date) - $started).TotalMinutes -gt 15) {
                throw "Timed out waiting for the background Windows Media Foundation installation."
            }
            Start-Sleep -Seconds 2
        }
        Write-Host "Waited $([int]((Get-Date) - $started).TotalSeconds)s for the background installation."
        Get-Content $log -ErrorAction SilentlyContinue
    }
}
