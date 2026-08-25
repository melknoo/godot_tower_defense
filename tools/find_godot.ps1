# Gemeinsame Godot-Binary-Aufloesung fuer deploy_itch.ps1.
# Dot-sourcen:  . "$PSScriptRoot\tools\find_godot.ps1"
#
# Bevorzugt wird immer die *_console.exe-Variante: nur sie schreibt auf
# stdout/stderr, das die PowerShell/cmd-Umleitung mitbekommt. Die normale
# .exe laeuft als GUI-Subsystem-Prozess und liefert kein Log.

function Get-GodotPath {
	param(
		# Optionaler Kandidat aus deploy.env (GODOT_PATH). Env-Variable hat Vorrang.
		[string] $Configured = ""
	)

	$candidates = @()

	if ($env:GODOT) { $candidates += $env:GODOT }
	if ($Configured) { $candidates += $Configured }

	foreach ($c in $candidates) {
		if (Test-Path -LiteralPath $c -PathType Leaf) { return (Resolve-Path -LiteralPath $c).Path }
	}

	# Godot-Downloads liegen ueblicherweise als ENTPACKTER ORDNER namens
	# "Godot_v4.x.y-stable_win64.exe" im Downloads-Verzeichnis (der Ordnername
	# traegt die .exe-Endung - das ist kein Tippfehler).
	$searchRoots = @(
		(Join-Path $env:USERPROFILE "Downloads"),
		(Join-Path $env:LOCALAPPDATA "Programs"),
		"C:\Program Files\Godot",
		"C:\Godot"
	)

	$found = @()
	foreach ($root in $searchRoots) {
		if (-not (Test-Path -LiteralPath $root)) { continue }
		$found += Get-ChildItem -Path $root -Recurse -Depth 2 -Filter "Godot_v4.*_win64_console.exe" -File -ErrorAction SilentlyContinue
		$found += Get-ChildItem -Path $root -Recurse -Depth 2 -Filter "Godot_v4.*_win64.exe" -File -ErrorAction SilentlyContinue
	}

	if ($found.Count -gt 0) {
		# Console-Variante zuerst, danach nach Versionsnummer im Namen absteigend.
		$best = $found |
			Sort-Object @{ Expression = { if ($_.Name -like "*_console.exe") { 0 } else { 1 } } },
			            @{ Expression = { $_.Name }; Descending = $true } |
			Select-Object -First 1
		return $best.FullName
	}

	$cmd = Get-Command godot -ErrorAction SilentlyContinue
	if ($cmd) { return $cmd.Source }

	throw "Godot-Binary nicht gefunden. Setze `$env:GODOT oder GODOT_PATH in deploy.env auf die Godot-*_console.exe."
}
