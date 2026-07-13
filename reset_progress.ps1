param(
    [switch]$Backup
)

$ErrorActionPreference = 'Stop'
$projectName = 'tower defense'
$saveDirectory = Join-Path $env:APPDATA "Godot\app_userdata\$projectName"
$saveFile = Join-Path $saveDirectory 'incremental_progression_v1.json'

if (-not (Test-Path -LiteralPath $saveFile)) {
    Write-Host "Kein Progress gefunden. Der Spielstand ist bereits frisch."
    Write-Host "Pfad: $saveFile"
    exit 0
}

if ($Backup) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupFile = "$saveFile.$timestamp.bak"
    Copy-Item -LiteralPath $saveFile -Destination $backupFile
    Write-Host "Backup erstellt: $backupFile"
}

Remove-Item -LiteralPath $saveFile
Write-Host "Progress erfolgreich zurueckgesetzt."
Write-Host "Beim naechsten Spielstart beginnt ein neuer Spielstand."
