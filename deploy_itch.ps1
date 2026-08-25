# Lokaler Deploy nach itch.io: Windows- und Web-Export + butler-Push in die
# Channels "windows" und "web".
#
# Portiert aus D:\surv_like\deploy_itch.ps1 (dort zusaetzlich Android + GitHub-CI).
#
# Voraussetzungen (einmalig):
#   1. deploy.env aus deploy.env.example anlegen (mindestens BUTLER_API_KEY)
#   2. itch.io-Projekt anlegen, Kind of project = HTML (siehe unten $ITCH_TARGET)
#
# Aufruf:
#   .\deploy_itch.ps1                 # Tests, beide Exporte, Push
#   .\deploy_itch.ps1 -NoPush         # nur bauen, nichts hochladen
#   .\deploy_itch.ps1 -SkipWindows    # nur Web
#   .\deploy_itch.ps1 -Strict         # Abbruch, wenn Branch/Worktree nicht sauber
#
# PowerShell 5.1: kein &&/||, kein Ternary. Godot schreibt auf stderr -> Aufrufe
# laufen ueber cmd /c mit Log-Datei (sonst NativeCommandError).

[CmdletBinding()]
param(
	[switch] $SkipTests,
	[switch] $SkipWindows,
	[switch] $SkipWeb,
	[switch] $NoPush,
	[switch] $Strict,
	[string] $Version = "",
	[string] $VersionSuffix = "local"
)

$ErrorActionPreference = "Stop"

$proj        = $PSScriptRoot
$EXPORT_NAME = "ArcaneDefense"
$ITCH_TARGET = "melleeee/arcane-defense"
$exportRoot  = Join-Path $proj "export"
$logDir      = Join-Path $exportRoot "_logs"
$counterFile = Join-Path $proj ".deploy_build_number"

function Write-Step   { param([string] $m) Write-Output ""; Write-Output "=== $m ===" }
function Write-Info   { param([string] $m) Write-Output "    $m" }
function Fail         { param([string] $m) Write-Output ""; Write-Output "ABBRUCH: $m"; exit 1 }

# ---------------------------------------------------------------- deploy.env
# KEY=VALUE, # als Kommentar. Echte Umgebungsvariablen haben Vorrang.
function Import-DeployEnv {
	param([string] $Path)
	if (-not (Test-Path -LiteralPath $Path)) { return }
	foreach ($line in (Get-Content -LiteralPath $Path)) {
		$t = $line.Trim()
		if ($t -eq "" -or $t.StartsWith("#")) { continue }
		$i = $t.IndexOf("=")
		if ($i -lt 1) { continue }
		$key = $t.Substring(0, $i).Trim()
		$val = $t.Substring($i + 1).Trim()
		if ($val.Length -ge 2) {
			if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
				$val = $val.Substring(1, $val.Length - 2)
			}
		}
		$existing = [Environment]::GetEnvironmentVariable($key, "Process")
		if ([string]::IsNullOrEmpty($existing)) {
			[Environment]::SetEnvironmentVariable($key, $val, "Process")
		}
	}
}

Import-DeployEnv (Join-Path $proj "deploy.env")

# ---------------------------------------------------------------- Godot-Aufruf
# Godot wird ueber einen kleinen Batch-Wrapper gestartet. Warum dieser Umweg:
#  - Umleitung auf cmd-Ebene (> log 2>&1) schreibt direkt in die Datei. Godots
#    Export-Log ist mehrere hundert KB; .NET-Pipes (Start-Process
#    -RedirectStandardOutput) laufen dabei ohne aktives Leeren voll.
#  - Der Exit-Code kommt aus einer Marker-Datei: Start-Process -PassThru liefert
#    .ExitCode in PS 5.1 NICHT zuverlaessig. In einer .cmd-Datei wird
#    %ERRORLEVEL% dagegen pro Zeile zur Laufzeit expandiert.
#  - Start-Process -PassThru dient nur noch dem Timeout (WaitForExit mit Frist).
function Invoke-Godot {
	param(
		[string[]] $GodotArgs,
		[string]   $LogName,
		[int]      $TimeoutMinutes = 30,
		[switch]   $IgnoreErrors
	)
	if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
	$log      = Join-Path $logDir $LogName
	$codeFile = Join-Path $logDir ($LogName + ".exitcode")
	$runner   = Join-Path $logDir ($LogName + ".cmd")
	if (Test-Path -LiteralPath $codeFile) { Remove-Item -Force -LiteralPath $codeFile }

	# Argumente selbst quoten: "Windows Desktop" enthaelt ein Leerzeichen.
	$argStr = ($GodotArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
	# Das Leerzeichen vor ">" ist PFLICHT: "echo %ERRORLEVEL%> datei" wird von cmd als
	# "echo 0> datei" gelesen, und die 0 direkt vor ">" ist dort die Handle-Nummer von
	# stdin -> die Datei bleibt leer, der Exit-Code geht verloren.
	Set-Content -LiteralPath $runner -Encoding ascii -Value @(
		"@echo off",
		"`"$godot`" $argStr > `"$log`" 2>&1",
		"echo %ERRORLEVEL% > `"$codeFile`""
	)

	$started = Get-Date
	$p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$runner`"" -NoNewWindow -PassThru
	$timedOut = -not $p.WaitForExit($TimeoutMinutes * 60 * 1000)

	if ($timedOut) {
		try { $p.Kill() } catch { }
		# cmd zu killen beendet Godot nicht mit - nur die in diesem Lauf
		# gestarteten Godot-Prozesse abraeumen.
		Get-Process -ErrorAction SilentlyContinue |
			Where-Object { $_.Path -eq $godot -and $_.StartTime -ge $started } |
			ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
		Write-Output (Get-LogTail $log 40)
		Fail "Godot-Aufruf nach $TimeoutMinutes min abgebrochen. Vollstaendiges Log: $log"
	}

	$code = -1
	if (Test-Path -LiteralPath $codeFile) {
		$rawCode = Get-Content -LiteralPath $codeFile -Raw
		if ($null -ne $rawCode) {
			$parsed = 0
			if ([int]::TryParse($rawCode.Trim(), [ref] $parsed)) { $code = $parsed }
		}
	}
	if ($code -ne 0 -and -not $IgnoreErrors) {
		Write-Output (Get-LogTail $log 40)
		Fail "Godot-Aufruf fehlgeschlagen (Exit $code). Vollstaendiges Log: $log"
	}
	return $code
}

# Nur den Schwanz des Logs zeigen - das komplette Export-Log wuerde die
# eigentliche Fehlermeldung aus jedem Terminal-Puffer schieben.
function Get-LogTail {
	param([string] $Path, [int] $Lines = 40)
	if (-not (Test-Path -LiteralPath $Path)) { return "(kein Log: $Path)" }
	return ((Get-Content -LiteralPath $Path -Tail $Lines) -join "`n")
}

function Get-SizeMb {
	param([string] $Path)
	return [math]::Round((Get-Item -LiteralPath $Path).Length / 1MB, 1)
}

# Godot meldet Export-Fehler nicht zuverlaessig per Exit-Code - deshalb wird jedes
# erwartete Artefakt zusaetzlich auf Existenz und Mindestgroesse geprueft.
function Assert-Artifact {
	param([string] $Path, [double] $MinMb = 5.0)
	if (-not (Test-Path -LiteralPath $Path)) { Fail "Erwartetes Artefakt fehlt: $Path" }
	$mb = Get-SizeMb $Path
	if ($mb -lt $MinMb) { Fail "Artefakt verdaechtig klein ($mb MB, erwartet >= $MinMb MB): $Path" }
	Write-Info ("{0}  ({1} MB)" -f (Split-Path $Path -Leaf), $mb)
}

# =================================================================== PREFLIGHT
Write-Step "Preflight"

. (Join-Path $proj "tools\find_godot.ps1")
try {
	$godot = Get-GodotPath -Configured $env:GODOT_PATH
} catch {
	Fail $_.Exception.Message
}
Write-Info "Godot:  $godot"

if ($env:ITCH_TARGET) { $ITCH_TARGET = $env:ITCH_TARGET }
Write-Info "Target: $ITCH_TARGET"

$branch = ""
try { $branch = (& git -C $proj rev-parse --abbrev-ref HEAD).Trim() } catch { $branch = "" }
$dirty = ""
try { $dirty = (& git -C $proj status --porcelain) -join "`n" } catch { $dirty = "" }

if ($branch -ne "") { Write-Info "Branch: $branch" }

# Lokal ist ein unsauberer Worktree normal - das ist der Sinn des Scripts -, soll
# aber sichtbar sein. Mit -Strict wird daraus ein Abbruch (fuer echte Releases).
$dirtyCount = 0
if ($dirty -ne "") { $dirtyCount = ($dirty -split "`n").Count }
if ($dirtyCount -gt 0) {
	if ($Strict) {
		Write-Output $dirty
		Fail "Arbeitsverzeichnis ist nicht sauber ($dirtyCount Eintraege)."
	}
	Write-Info "HINWEIS: $dirtyCount uncommittete Aenderung(en) - der Build enthaelt deinen Arbeitsstand."
}

if (-not $NoPush) {
	if ([string]::IsNullOrEmpty($env:BUTLER_API_KEY)) {
		Fail "BUTLER_API_KEY fehlt (deploy.env oder Umgebungsvariable). Key: itch.io -> Settings -> API keys."
	}
}

# =================================================================== VERSION
# config/version aus project.godot + lokaler Build-Zaehler.
$baseVersion = "0.0.0"
$pg = Get-Content -LiteralPath (Join-Path $proj "project.godot") -Raw
$m = [regex]::Match($pg, '(?m)^config/version="([^"]+)"')
if ($m.Success) { $baseVersion = $m.Groups[1].Value }

$buildNumber = 0
if (Test-Path -LiteralPath $counterFile) {
	$raw = (Get-Content -LiteralPath $counterFile -Raw).Trim()
	$parsed = 0
	if ([int]::TryParse($raw, [ref] $parsed)) { $buildNumber = $parsed }
}
$nextBuild = $buildNumber + 1

if ($Version -ne "") {
	$userVersion = $Version
} else {
	$userVersion = "$baseVersion.$nextBuild"
	if ($VersionSuffix -ne "") { $userVersion = "$userVersion-$VersionSuffix" }
}
Write-Info "Version: $userVersion"

# =================================================================== TESTS
if ($SkipTests) {
	Write-Step "Tests uebersprungen (-SkipTests)"
} else {
	Write-Step "Smoke-Tests"
	foreach ($t in @("progression_smoke", "feature_smoke")) {
		Write-Info "$t ..."
		Invoke-Godot -GodotArgs @(
			"--headless", "--path", $proj, "--script", "res://tests/$t.gd"
		) -LogName "test_$t.log" -TimeoutMinutes 10 | Out-Null
	}
	Write-Info "Tests gruen."
}

# =================================================================== IMPORT
Write-Step "Import-Cache waermen"
Invoke-Godot -GodotArgs @("--headless", "--path", $proj, "--import") -LogName "import.log" -IgnoreErrors | Out-Null
Write-Info "Fertig."

# =================================================================== WINDOWS
$winDir = Join-Path $exportRoot "windows"
if (-not $SkipWindows) {
	Write-Step "Export Windows"
	# Verzeichnis leeren: butler pusht den GANZEN Ordner, Altbestaende wuerden mitgehen.
	if (Test-Path -LiteralPath $winDir) { Remove-Item -Recurse -Force -LiteralPath $winDir }
	New-Item -ItemType Directory -Force -Path $winDir | Out-Null

	Invoke-Godot -GodotArgs @(
		"--headless", "--path", $proj, "--export-release", "Windows Desktop",
		"export/windows/$EXPORT_NAME.exe"
	) -LogName "export_windows.log" | Out-Null

	Assert-Artifact (Join-Path $winDir "$EXPORT_NAME.exe") 5.0
	Assert-Artifact (Join-Path $winDir "$EXPORT_NAME.pck") 1.0
}

# =================================================================== WEB
# Browser-Build (HTML5). Laeuft zwingend auf gl_compatibility statt Forward+ -
# der Web-Export-Template enthaelt nur den GL-Renderer. Ohne thread_support, damit
# die itch-Seite die "SharedArrayBuffer support"-Option nicht braucht.
$webDir = Join-Path $exportRoot "web"
if (-not $SkipWeb) {
	Write-Step "Export Web (HTML5)"
	if (Test-Path -LiteralPath $webDir) { Remove-Item -Recurse -Force -LiteralPath $webDir }
	New-Item -ItemType Directory -Force -Path $webDir | Out-Null

	Invoke-Godot -GodotArgs @(
		"--headless", "--path", $proj, "--export-release", "Web",
		"export/web/index.html"
	) -LogName "export_web.log" | Out-Null

	# Get-SizeMb rundet auf 1 Nachkommastelle -> alles unter ~50 KB ist "0.0 MB".
	# index.html (~5 KB) und index.js (~0.3 MB) daher nur auf Existenz pruefen.
	Assert-Artifact (Join-Path $webDir "index.html") 0.0
	Assert-Artifact (Join-Path $webDir "index.js")   0.0
	Assert-Artifact (Join-Path $webDir "index.wasm") 20.0
	Assert-Artifact (Join-Path $webDir "index.pck")  1.0
}

if ($NoPush) {
	Write-Step "Fertig (-NoPush: kein Upload)"
	Write-Info "Version waere gewesen: $userVersion"
	Write-Info "Artefakte: $exportRoot"
	exit 0
}

# =================================================================== BUTLER
Write-Step "butler bereitstellen"
$butlerDir = Join-Path $proj "tools\butler"
$butler    = Join-Path $butlerDir "butler.exe"

if (-not (Test-Path -LiteralPath $butler)) {
	Write-Info "Lade butler (GitHub-Release - broth.itch.ovh ist nicht immer erreichbar)."
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/itchio/butler/releases/latest" -Headers @{ "User-Agent" = "arcane-defense-deploy" }
	$asset = $rel.assets | Where-Object { $_.name -like "*windows-amd64*" -and $_.name -notlike "*sha256*" } | Select-Object -First 1
	if (-not $asset) { Fail "Kein windows-amd64-Asset im neuesten butler-Release gefunden." }

	$tmpZip = Join-Path $env:TEMP "butler-windows-amd64.zip"
	$tmpDir = Join-Path $env:TEMP "butler-dl"
	Write-Info $asset.browser_download_url
	Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip -UseBasicParsing
	if (Test-Path -LiteralPath $tmpDir) { Remove-Item -Recurse -Force -LiteralPath $tmpDir }
	Expand-Archive -LiteralPath $tmpZip -DestinationPath $tmpDir -Force

	$exe = Get-ChildItem -Path $tmpDir -Recurse -Filter "butler.exe" -File | Select-Object -First 1
	if (-not $exe) { Fail "butler.exe im Archiv nicht gefunden." }
	if (-not (Test-Path -LiteralPath $butlerDir)) { New-Item -ItemType Directory -Force -Path $butlerDir | Out-Null }
	# butler.exe braucht die begleitenden DLLs aus demselben Ordner.
	Copy-Item -Path (Join-Path $exe.DirectoryName "*") -Destination $butlerDir -Recurse -Force
	Remove-Item -Force -LiteralPath $tmpZip -ErrorAction SilentlyContinue
	Remove-Item -Recurse -Force -LiteralPath $tmpDir -ErrorAction SilentlyContinue
}

# butler schreibt Fortschritt teilweise auf stderr. Unter $ErrorActionPreference='Stop'
# wuerde PS 5.1 daraus einen terminierenden NativeCommandError machen und die
# Retry-Schleife ueberspringen -> fuer alle butler-Aufrufe bewusst auf 'Continue'
# stellen und ausschliesslich ueber $LASTEXITCODE entscheiden.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"

& $butler -V
if ($LASTEXITCODE -ne 0) {
	$ErrorActionPreference = $prevEap
	Fail "butler laeuft nicht (Exit $LASTEXITCODE)."
}

# =================================================================== PUSH
# Kanalname = Verzeichnisname unter export/.
$channels = @()
if (-not $SkipWindows) { $channels += "windows" }
if (-not $SkipWeb)     { $channels += "web" }
if ($channels.Count -eq 0) { Fail "Nichts zu pushen (beide Ziele uebersprungen)." }

foreach ($channel in $channels) {
	Write-Step "Push -> ${ITCH_TARGET}:$channel"
	$dir = Join-Path $exportRoot $channel
	$ok = $false
	for ($i = 1; $i -le 3; $i++) {
		& $butler push $dir "${ITCH_TARGET}:$channel" --userversion $userVersion
		if ($LASTEXITCODE -eq 0) { $ok = $true; break }
		Write-Info "Versuch $i fehlgeschlagen - neuer Versuch in 15s..."
		Start-Sleep -Seconds 15
	}
	if (-not $ok) {
		$ErrorActionPreference = $prevEap
		Fail "butler push '$channel' nach 3 Versuchen fehlgeschlagen. Zaehler bleibt bei $buildNumber."
	}
}
$ErrorActionPreference = $prevEap

# Zaehler erst nach erfolgreichem Push hochsetzen - fehlgeschlagene Laeufe
# sollen keine Build-Nummern verbrennen.
if ($Version -eq "") { Set-Content -LiteralPath $counterFile -Value $nextBuild -Encoding ascii }

Write-Step "Deploy fertig"
Write-Info "Version:  $userVersion"
Write-Info ("Channels: {0}" -f ($channels -join ", "))
Write-Info "Status:   tools\butler\butler.exe status $ITCH_TARGET"
