# Projektfortschritt

Letzte Aktualisierung: 2026-07-17

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
  Kryomant, Geomant und Aeromant sind die Basis-Charaktere (`"base": true`).
- Das Charakter-MVP ist implementiert: Aschenweberin, Gezeitenhueter,
  Sturmjaeger und Runenwaechter sind rekrutierbar (Zielbedingung aus
  `total_kills`/`best_wave`/`highest_streak` plus Aetherkosten; Aschenweberin
  kostenlos). Rekrutierungen liegen persistent in
  `ProgressionSystem.recruited_characters` (Save-Version 2, Migration von v1 =
  fehlender Schluessel ergibt leeres Dict).
- Der Menuepunkt `Charaktere` oeffnet `ui/character_roster_ui.gd`: gesperrte
  Karten zeigen Name, Silhouette, Spielstil, Passive und Zielfortschritt; der
  Menue-Button traegt ein `NEU!`-Badge, wenn jemand rekrutierbar ist.
- Charakter-Passiven laufen zentral ueber
  `AbilitySystem.get_passive_modifier()`; Hooks in `enemy.gd` (Brenndauer,
  Slow-Bonusschaden), `ability_system.gd` (Kettensprung/-reichweite) und
  `game_state.gd` (Startleben). Neue Ability-Angebote werden mit
  `AFFINITY_WEIGHT` zur Element-Affinitaet des Charakters gewichtet.
- VFX-Juice-Pass: Feedback fuer Tower-Pickup/-Abbruch, Fehlplatzierung
  (ZU TEUER/BLOCKIERT/KEIN SUPPLY), Gold-Ausgaben (`spawn_gold_number` mit
  `is_spend`), Upgrade-Punch, Wellenstart-Banner, Leben-Verlust, Aether-Gewinn,
  Account-Level-Up, Meilensteine, Streak-Stufen, Element-Kern, Forschungskauf,
  Game Over und Rekrutierung. HUD-Effekte laufen via `parent_override` im
  UI-CanvasLayer; `screen_flash` funktioniert jetzt auch im Hauptmenue und bei
  pausiertem Baum.
- Smoke-Test und visuelle Capture-Szenen liegen unter `tests/`.
- Tower zeigen ihre Stufe direkt in der Spielwelt. Angriffs-, Nahkampf-,
  Fallen- und Aura-Reichweiten verwenden ein gemeinsames quadratisches
  64-Pixel-Raster fuer Anzeige und Trefferpruefung.
- Item-Aufnahmen erzeugen animierte Toasts rechts ueber dem HUD. Ein eigener
  arkaner Cursor sowie Wellen-, Supply- und Nahkampf-VFX ergaenzen das Feedback.
- Supply zeigt immer `verwendet/effektives Maximum`; Archiv-, Farm- und
  Run-Boni werden zentral aufgeschluesselt und nicht mehr gegeneinander
  ueberschrieben.
- Die sechs Stufen aller Basistuerme besitzen vollstaendige, geglaettete Werte.
  Insbesondere Schwert-Schaden und Gegnertyp-Multiplikatoren erzeugen auf
  Stufe 2/3 keine garantierten One-Shots mehr.

## In Arbeit im lokalen Arbeitsbaum

Keine offenen Aenderungen: `git status` ist sauber, alle zuvor hier notierten
Aenderungen (Range-Raster, Supply, Tower-Level, Item-Toasts, Cursor, VFX,
Balancing) sind im Commit `1887792` ("added more chars") enthalten und liegen
auf `origin/main`. Ein frischer Clone entspricht dem aktuellen Stand.

## Bekannte Luecken

- Charakter-Portraits (`char_*`-Icons) existieren noch nicht als Assets; das
  Roster faellt leise auf die Element-Icons zurueck.
- Der Gezeitenhueter-Bonus greift nicht auf Chain-Segmente von Bullets
  (`bullet.gd` uebergibt dort keinen Tower-Typ) — akzeptierte MVP-Luecke.
- Die Passiv-Hooks in `enemy.gd` (Brenndauer, Slow-Bonus) sind nur manuell
  verifizierbar; der Smoke-Test prueft sie ueber `get_passive_modifier`, weil
  ein nacktes `enemy.new()` ohne Szenen-Nodes bei `apply_burn` crasht.
- Aetherkosten (90/120/160), Unlock-Ziele und `AFFINITY_WEIGHT` sind
  Arbeitswerte und noch nicht in echten Runs ausbalanciert.
- Die Eiswand-Ability enthaelt weiterhin einen expliziten Platzhalter fuer die
  zu spawnende Wand-Entitaet.
- Die lokalen Dokumentationsaenderungen wurden in dieser Umgebung nicht mit
  einem Markdown-Linter geprueft.
- Godot liegt weiterhin nicht auf `PATH`; die Executable liegt im Ordner
  `Downloads/Godot_v4.6.3-stable_win64.exe/` (der Ordner traegt die
  `.exe`-Endung, die eigentliche Datei liegt darin).

## Naechste empfohlene Arbeitsschritte

1. Balance-Pass: 3-5 Runs pro Charakter spielen (Reset via
   `reset_progress.ps1`) und Aetherkosten, Passiv-Werte, Unlock-Ziele und
   `AFFINITY_WEIGHT` festschreiben; danach die Roadmap-Tabelle aktualisieren.
2. Charakter-Portrait-Assets (`char_*`) zeichnen und in `IconSystem`
   registrieren.
3. Spaetere Charaktere aus der Roadmap (Chronomantin, Arkanist, Konstrukteur,
   Seelenhirtin) benoetigen neue Abilities, bevor sie als Daten ergaenzt werden
   koennen.
4. Optional: Mid-Run-Toast, wenn eine Unlock-Bedingung erstmals erfuellt wird
   (Hook in `register_kill`/`register_wave_completed`).

## Verifikation

Von einer Shell mit erreichbarer Godot-Executable im Repository:

```powershell
godot --headless --path . --script res://tests/progression_smoke.gd
godot --path . res://tests/ui_capture.tscn
godot --path . res://tests/main_menu_capture.tscn
godot --path . res://tests/character_roster_capture.tscn
```

Hinweis: Nach neuen `class_name`-Skripten einmal
`godot --headless --path . --editor --quit-after 3` ausfuehren, damit der
globale Klassen-Cache regeneriert wird.

Die Capture-Tests schreiben Bilder nach `user://ui_audit`. Fuer einen sauberen
manuellen Progressionsstart stehen `reset_progress.ps1` und
`reset_progress.cmd` bereit.

Letzte Verifikation dieser Sitzung (2026-07-16): Progressions-Smoke-Test
(inkl. neuer Rekrutierungs-, Migrations- und Passiv-Asserts), der vollstaendige
UI-Capture-Test, die Hauptmenue-Capture und die neue Roster-Capture liefen mit
Godot 4.6.3 erfolgreich durch; der Roster-Screenshot wurde visuell geprueft.

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
