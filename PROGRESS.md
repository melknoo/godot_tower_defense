# Projektfortschritt

Letzte Aktualisierung: 2026-07-13

Diese Datei beschreibt den veraenderlichen Arbeitsstand. Sie soll am Ende
jeder groesseren Arbeitssitzung aktualisiert werden. Dauerhafte Architektur-
und Designentscheidungen stehen in `MEMORY.md`; geplante Ausbaustufen in
`INCREMENTAL_ROADMAP.md`.

## Aktueller Stand

- Das Godot-4.6-Projekt startet ueber `main.tscn` und besitzt eine spielbare
  Tower-Defense-Kernschleife mit Wellen, Bossen, Gold, Zinsen, Supply und Leben.
- Schwert und Farm sind die Starttuerme. Bogen, Zauberer, Fallensteller, Kanone
  und Aura werden dauerhaft ueber das Arkane Archiv freigeschaltet und stehen
  jeweils ab dem folgenden Run zur Verfuegung.
- Die persistente Incremental-Progression ist implementiert: Aether,
  Account-XP, Account-Level, Kill-Serien, Wellenmeilensteine, Run-Abschlussbonus,
  Forschung in drei Stufen und Auto-Wellenstart.
- Das Archiv besitzt eine eigene UI. Aether und Account-Fortschritt werden im
  HUD sowie in der Run-Zusammenfassung angezeigt.
- Elemente, Element-Kerne, Run-Upgrades, Ability-Upgrades, Items, Inventar und
  Aura-Tuerme existieren als eigene Systeme.
- Das Hauptmenue besitzt eine Charakterauswahl fuer neue Runs. Pyromant,
  Kryomant, Geomant und Aeromant sind aktuell alle standardmaessig offen.
- Das Charakterkonzept mit Aether-Rekrutierung, Zielbedingungen, Passiven und
  spaeterer kosmetischer Meisterschaft ist in `INCREMENTAL_ROADMAP.md`
  dokumentiert.
- Smoke-Test und visuelle Capture-Szenen liegen unter `tests/`.

## In Arbeit im lokalen Arbeitsbaum

Zum Zeitpunkt dieser Aktualisierung gibt es nicht committete Aenderungen in:

- `ui/pause_menu.gd`: Sicherheitsabfrage unterscheidet zwischen Rueckkehr ins
  Hauptmenue und vollstaendigem Beenden des Spiels.
- `tests/ui_capture.gd`: Capture und Assertions fuer den Beenden-Dialog.
- `tests/main_menu_capture.gd`: angepasste Screenshot-Nummerierung.
- `INCREMENTAL_ROADMAP.md`, `PROGRESS.md` und `MEMORY.md`: Charakterplanung und
  uebertragbarer Projektkontext.

Diese Dateien muessen gemeinsam committed und in das Remote-Repository gepusht
werden, bevor ein frischer Clone auf einem anderen Rechner den Stand enthaelt.

## Bekannte Luecken

- Der Hauptmenuepunkt `Charaktere` ist noch ein Platzhalter und erzeugt nur eine
  Debug-Ausgabe.
- Alle vier vorhandenen Charaktere sind freigeschaltet. Eine persistente
  Rekrutierung mit Unlock-Bedingungen und Aetherkosten fehlt.
- Charaktere unterscheiden sich praktisch nur durch ihre Start-Ability. Es gibt
  noch keine Passiven und keine gewichteten Ability-Angebote.
- Die Eiswand-Ability enthaelt ebenfalls noch einen expliziten Platzhalter fuer
  die zu spawnende Wand-Entitaet.
- Das persistente Progressions-Save schreibt derzeit keine
  Charakter-Freischaltungen. Die Save-Version ist noch 1.
- Die lokalen Dokumentationsaenderungen wurden in dieser Umgebung nicht mit
  einem Markdown-Linter geprueft.
- Eine Godot-Executable war in der aktuellen Shell nicht ueber `PATH`
  auffindbar; die Tests wurden in dieser Sitzung deshalb nicht ausgefuehrt.

## Naechste empfohlene Arbeitsschritte

1. Die laufenden Pausemenue-Aenderungen in Godot pruefen und danach zusammen
   mit den Tests und Dokumentationsdateien committen und pushen.
2. Ein persistentes Datenmodell fuer Charakter-Unlocks mit Save-Migration
   anlegen.
3. Den Charakterbildschirm als Sammlung, Fortschrittsanzeige und
   Rekrutierungsoberflaeche implementieren.
4. Zunaechst einen neuen Charakter vollstaendig vertikal umsetzen, bevor der
   gesamte geplante Kader hinzugefuegt wird. Die Aschenweberin ist dafuer der
   einfachste Kandidat, weil `Inferno` bereits existiert.
5. Passiven und Ability-Gewichtung erst nach funktionierender Rekrutierung
   ergaenzen und anschliessend die Aetherkosten in echten Runs testen.

## Verifikation

Von einer Shell mit erreichbarer Godot-Executable im Repository:

```powershell
godot --headless --path . --script res://tests/progression_smoke.gd
godot --path . res://tests/ui_capture.tscn
godot --path . res://tests/main_menu_capture.tscn
```

Die Capture-Tests schreiben Bilder nach `user://ui_audit`. Fuer einen sauberen
manuellen Progressionsstart stehen `reset_progress.ps1` und
`reset_progress.cmd` bereit.

## Uebergabe-Checkliste

Vor dem Wechsel auf einen anderen Rechner:

1. `git status` pruefen und relevante Quell-, Test- und Markdown-Dateien
   committen.
2. Den Commit zum gemeinsamen Remote pushen.
3. Falls auch der persoenliche Spielstand benoetigt wird, die Datei
   `user://incremental_progression_v1.json` separat sichern; sie ist kein Teil
   des Git-Repositories.
4. Auf dem neuen Rechner Repository klonen, Godot 4.6 verwenden und zuerst
   `MEMORY.md`, diese Datei und `INCREMENTAL_ROADMAP.md` lesen.
5. Smoke-Test ausfuehren und den offenen Arbeitsstand mit `git status` pruefen.
