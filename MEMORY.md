# Projekt-Memory

Diese Datei bewahrt stabilen Kontext fuer Menschen und Coding-Assistenten, die
das Repository in einer neuen Sitzung oder auf einem anderen Rechner
uebernehmen. Kurzlebige Aufgaben und lokaler Arbeitsstand gehoeren in
`PROGRESS.md`; Ideen und geplante Features in `INCREMENTAL_ROADMAP.md`.

## Einstieg in eine neue Sitzung

1. `git status` und die letzten Commits pruefen.
2. `MEMORY.md` fuer Architektur und feste Entscheidungen lesen.
3. `PROGRESS.md` fuer offene Arbeiten und bekannte Luecken lesen.
4. `INCREMENTAL_ROADMAP.md` fuer Prioritaeten und noch nicht umgesetztes Design
   lesen.
5. Vor Aenderungen die betroffenen GDScript-Dateien und Tests erneut pruefen;
   die Dokumentation ersetzt nicht den aktuellen Code als letzte Wahrheit.

Am Ende einer groesseren Sitzung wird `PROGRESS.md` aktualisiert. Diese Datei
wird nur geaendert, wenn sich eine dauerhafte Entscheidung, Architekturgrenze
oder wichtige bekannte Falle veraendert.

## Produkt und technische Basis

- Das Projekt ist ein aktives Tower-Defense mit Incremental-Meta-Progression.
- Engine: Godot 4.6, hauptsaechlich GDScript.
- Hauptszene: `main.tscn`; Hauptmenue: `main_menu.tscn`.
- Zielaufloesung: 1920 x 1080, Stretch-Modus `canvas_items`.
- Pixelassets bleiben die visuelle Sprache. Persistente Magie verwendet vor
  allem Cyan und Violett, Economy Gold und unmittelbare Gefahr Rot.
- `.godot/`, Exporte und andere generierte Engine-Dateien bleiben ungetrackt.

## Zentrale Verantwortlichkeiten

- `autoload/progression_system.gd`: persistente Meta-Progression, Aether,
  Account-XP, Kill-Serie, Meilensteine, Forschung und Turm-Unlocks.
- `game_state.gd`: Zustand und Economy des aktuellen Runs, Wellenabschluss,
  Leben, Gold, Supply und Element-Kerne.
- `data/tower_data.gd`: Turmdefinitionen, Elemente, Verfuegbarkeit und
  Turmstatistiken.
- `autoload/ability_system.gd`: Charakterdefinitionen, aktive Abilities,
  Ability-Slots, Cooldowns und Run-Upgrades fuer Abilities.
- `autoload/upgrade_system.gd`: temporaere Run-Upgrades ausserhalb der
  Ability-Upgrades.
- `autoload/item_system.gd`: Items und Inventardaten.
- `main.gd`: Aufbau und Koordination der eigentlichen Spielszene.
- `main_menu.gd`: Hauptmenue und Charakterwahl vor einem neuen Run.
- `ui/meta_progression_ui.gd`: Oberflaeche des Arkanen Archivs.
- `ui/hud.gd`: HUD und Run-Zusammenfassung.

Die Autoload-Namen in `project.godot` sind Teil der impliziten API zwischen den
Systemen. Vor Umbenennungen muessen alle direkten Singleton-Zugriffe geprueft
werden.

## Dauerhafte Designentscheidungen

### Progressionsschleifen

- Sekunden: Kill-Serie erhoeht den Goldmultiplikator und erzeugt regelmaessig
  Aether.
- Minuten: Wellen zahlen Aether und Account-XP; Bosswellen und feste Wellenziele
  sind die wichtigsten Ausschlaege.
- Runs: Das Arkane Archiv gibt dauerhafte Verbesserungen und Turm-Unlocks.
- Turm-Unlocks werden erst beim Beginn des folgenden Runs in den Run-Snapshot
  uebernommen. Ein Kauf veraendert keinen laufenden Versuch.
- Tiefe Runs sollen effizienter sein als schnelles Neustart-Farming.

### Charaktere

- Das Archiv verkauft hauptsaechlich dauerhafte Macht; Charaktere liefern
  Seitwaertsfortschritt und neue Spielstile.
- Fuer den normalen Charakterkader wird keine neue ausgebbare Waehrung
  eingefuehrt. Freischaltung besteht aus einem sichtbaren Spielziel und einer
  einmaligen, moderaten Aether-Rekrutierung.
- Der erste neue Charakter wird als kostenlose Meilenstein-Belohnung vergeben.
- Charakteridentitaet besteht aus Start-Ability, kleiner Passive und einer
  weichen Gewichtung passender Ability-Angebote. Es gibt keine harte
  Elementbindung.
- Charakter-Passiven duerfen weder Aether noch Account-XP vermehren, damit kein
  wirtschaftlich verpflichtender Farm-Charakter entsteht.
- Eine spaetere Charakter-Meisterschaft ist ein nicht ausgebbarer Fortschritt
  fuer Kosmetik und Statistiken, keine zweite Waehrung.
- Die geplante Prestige-Ressource nach Welle 50 bleibt vom Basiskader getrennt.

### UI und Lesbarkeit

- Der Menuepunkt `Charaktere` dient als Sammlung und Rekrutierungsbildschirm;
  die konkrete Auswahl fuer den Run bleibt Teil von `Neues Spiel`.
- Gesperrte Inhalte sollen ihr Ziel und ihren Fortschritt zeigen. Reine
  `???`-Karten verschenken die motivierende Wirkung der Meta-Progression.
- Haeufige Auszahlungen verwenden kurze Animationen; wichtige Zahlen sind
  groesser als Ursache und Fortschrittsdetail.
- Tower-Reichweiten werden ueber `autoload/range_grid.gd` als quadratische
  64-Pixel-Rasterfelder berechnet und gezeichnet. Targeting und Vorschau muessen
  denselben Helper verwenden, damit die sichtbare Kante exakt der Mechanik
  entspricht.
- `GameState.supply_max` enthaelt Basis-, Archiv- und Farm-Supply;
  `get_effective_supply_max()` addiert temporaere Run-Upgrades. UI und
  Platzierungspruefungen beziehen den effektiven Wert zentral aus `GameState`.

## Persistenz

- Persistenter Meta-Save:
  `user://incremental_progression_v1.json`.
- Aktuelle Save-Version: 1.
- Persistiert werden unter anderem Aether, Account-Level und -XP, Bestwelle,
  Runs, Kills, hoechste Serie, Forschungsränge und Meilensteine.
- Charakter-Freischaltungen liegen zur Laufzeit in `AbilitySystem`, sind aber
  noch nicht in den persistenten Meta-Save integriert. Die vorhandenen
  `get_save_data()`- und `load_save_data()`-Hilfen werden derzeit nicht vom
  Progressions-Save aufgerufen.
- Beim Hinzufuegen von Charakterdaten muss die Save-Version erhoeht und eine
  rueckwaertskompatible Migration vorgesehen werden. Bestehende Spielstaende
  duerfen ihre vier bisher offenen Startcharaktere nicht unerwartet verlieren.
- Ein Git-Clone uebertraegt Quellcode und diese Dokumentation, aber keine
  `user://`-Dateien. Ein persoenlicher Laufzeit-Spielstand braucht einen
  separaten Export oder eine separate Sicherung.

## Bekannte technische Fallen

- Die vier aktuellen Charakterdefinitionen setzen `unlocked` auf `true`.
- `AbilitySystem.get_available_abilities_for_unlock()` bietet grundsaetzlich
  alle noch nicht ausgeruesteten Abilities an. Ohne Gewichtung verliert die
  Startcharakterwahl deshalb im Verlauf eines Runs an Bedeutung.
- Aura-Turm-Boni sind keine zeitlich begrenzten Buffs. Sie werden anhand der
  aktuellen Reichweite der Aura-Tuerme gesammelt und gelten, solange die
  raeumlichen Bedingungen erfuellt sind.
- Die Eiswand besitzt noch keine implementierte Wand-Entitaet.
- `ProgressionSystem.begin_run()` erstellt einen Snapshot der permanenten
  Turm-Unlocks. Diese Semantik bei Refactorings erhalten.
- Tests, die Progressions-Singletons veraendern, muessen ihren Zustand
  wiederherstellen, damit kein lokaler Spielstand versehentlich veraendert
  bleibt.

## Test- und Arbeitskonventionen

- Logischer Smoke-Test: `tests/progression_smoke.gd`.
- Visuelle Regression der Spiel-UI: `tests/ui_capture.tscn`.
- Visuelle Regression des Hauptmenues: `tests/main_menu_capture.tscn`.
- UI-Captures landen in `user://ui_audit` und werden nicht als Quellassets
  behandelt.
- Vor einem Balance-Test kann der lokale Incremental-Spielstand mit
  `reset_progress.ps1` oder `reset_progress.cmd` zurueckgesetzt werden.
- Bestehende, nicht zu einer Aufgabe gehoerende Aenderungen im Arbeitsbaum
  gehoeren dem Benutzer und werden nicht verworfen oder ueberschrieben.
