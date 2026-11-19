<#
.SYNOPSIS
    Stops NVDisplay.Container.exe from rewriting nvlog.nvlgstg in a loop.

.DESCRIPTION
    The NVIDIA display container service (nvtopps component) deletes and
    rewrites C:\ProgramData\NVIDIA Corporation\nvtopps\nct\nvlog.nvlgstg about
    once per second (~15 MB/s). This script denies file creation in that
    folder for SYSTEM and Administrators, then restarts the service.

    Run again after a driver update if the disk usage comes back.

.PARAMETER Revert
    Remove the deny rules and restart the service.

.EXAMPLE
    .\nvidia-nvlog-fix.ps1
    .\nvidia-nvlog-fix.ps1 -Revert
#>
#Requires -RunAsAdministrator
param([switch]$Revert)

$ErrorActionPreference = 'Stop'
$nct = 'C:\ProgramData\NVIDIA Corporation\nvtopps\nct'
$service = 'NVDisplay.ContainerLocalSystem'
# SYSTEM and BUILTIN\Administrators
$sids = '*S-1-5-18', '*S-1-5-32-544'

if (-not (Test-Path -LiteralPath $nct)) {
    New-Item -ItemType Directory -Path $nct -Force | Out-Null
}

Stop-Service $service -Force

# Drop any earlier deny rules so the script is safe to run twice.
foreach ($sid in $sids) { icacls $nct /remove:d $sid | Out-Null }

if ($Revert) {
    Write-Host "Deny rules removed from $nct"
} else {
    Remove-Item -LiteralPath "$nct\nvlog.nvlgstg" -Force -ErrorAction SilentlyContinue
    # WD = create files, AD = create folders, DC = delete children.
    foreach ($sid in $sids) { icacls $nct /deny "${sid}:(OI)(CI)(WD,AD,DC)" | Out-Null }
    Write-Host "Writes blocked in $nct"
}

Start-Service $service
Write-Host "$service restarted"
