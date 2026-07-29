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
- `autoload/run_schedule.gd`: einzige Quelle fuer die Wellen-Kadenzen eines Runs
  (Perk, Ability-Upgrade, Element-Kern, Schmiede, Boss).
- `autoload/music_manager.gd`: Hintergrundmusik mit Crossfade je Spielzustand.
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
- Die Karte wird **einmal pro Run** erzeugt und bleibt danach stabil. Eine Karte,
  die sich mitten im Run aendert, entwertet jeden Turmaufbau und nimmt dem Ort
  seine Identitaet. Die frueher vorhandene Pfad-Regenerierung alle 3 Wellen ist
  bewusst entfernt.
- Items sind Run-Loot und ueberleben einen Run nicht. `GameState.reset()` leert
  das Inventar ueber `ItemSystem.reset()`; equipte Items sterben ohnehin mit den
  Turm-Nodes.
- Alle Wellen-Kadenzen stehen in `autoload/run_schedule.gd` und werden nirgends
  dupliziert. Wer ein Intervall aendert, aendert genau eine Datei; HUD-Vorschau,
  Fahrplan-Panel und die Panel-Logik in `main.gd` folgen automatisch.

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
- Die Stadt (`city`) hat einen eigenen Basis-Supply (4); zusaetzlich zaehlt
  `stored_farms * Farm-Bonus` der aufgenommenen Farmen obendrauf. Deshalb fragt
  `TowerManager` das Supply eines Gebaeudes ueber `tower.get_supply_bonus()` ab,
  nicht ueber `TowerData.get_supply_bonus(typ)`. Das Aufnehmen von Farmen aendert
  das Supply-Maximum nicht — es macht nur Felder frei.
- Welle `RunSchedule.FINAL_WAVE` (30) ist das regulaere Run-Ende. Danach waehlt
  der Spieler zwischen Endlos-Modus (`Main.endless_mode`) und Abschluss mit
  Sieg-Auswertung. Beide Abschluss-Bildschirme teilen sich
  `HUD.show_run_summary(summary, is_victory)`.

## Persistenz

- Persistenter Meta-Save:
  `user://incremental_progression_v1.json`. Der Dateiname bleibt bewusst
  `_v1`, auch wenn die interne Save-Version steigt — Umbenennen wuerde
  bestehende Saves verwaisen.
- Aktuelle Save-Version: 2.
- Persistiert werden unter anderem Aether, Account-Level und -XP, Bestwelle,
  Runs, Kills, hoechste Serie, Forschungsränge, Meilensteine und
  `recruited_characters`.
- Charakter-Rekrutierungen gehoeren `ProgressionSystem`
  (`recruited_characters`, `recruit_character()`); `AbilitySystem` besitzt nur
  die Definitionen und delegiert `is_character_unlocked()`. Basis-Charaktere
  (`"base": true`) stehen nie im Rekrutierungs-Dict.
- Migration v1 -> v2: fehlender `recruited_characters`-Schluessel ergibt ein
  leeres Dict; Basis-4 bleiben frei, Rekrutierbare gesperrt. Erfuellte
  Zielbedingungen aus alten Stats machen Charaktere rekrutierbar, gewaehren sie
  aber nie automatisch — auch bei Kosten 0 klickt der Spieler selbst.
- Ein Git-Clone uebertraegt Quellcode und diese Dokumentation, aber keine
  `user://`-Dateien. Ein persoenlicher Laufzeit-Spielstand braucht einen
  separaten Export oder eine separate Sicherung.

## Bekannte technische Fallen

- Charakter-Passiven laufen ausschliesslich ueber
  `AbilitySystem.get_passive_modifier(key, default)`. Neue Passiven brauchen
  nur einen Modifier-Key in `CHARACTERS` plus einen Hook an der Wirkstelle;
  die Hooks duerfen nie Aether oder Account-XP anfassen. **Jeder** Charakter hat
  eine Passive, auch die vier Basis-Charaktere; die Charakterkarte im Hauptmenue
  und das Roster zeigen sie an.
- Status-Effekte mit Schaden ueber Zeit ticken in festen Intervallen
  (`Enemy.BURN_TICK_INTERVAL`), nicht pro Frame. `int(wert * delta)` ist bei
  60 FPS jeden Frame 0 und der Bruchteil geht verloren — genau daran hat Brennen
  lange gar keinen Schaden gemacht.
- Nahkampf-Statuseffekte (`Tower._apply_melee_effects`) werden einzeln geprueft,
  nicht per `match special_type`. Ein `match` band den Effekt an die Gravur und
  machte Items wie den Erdkern wirkungslos, weil sie nur den Wert (`stun_chance`)
  setzen, nicht den Typ. Cleave und Stun koexistieren dadurch.
- Item-Stats wirken nur, wenn ihr `stat`-Key in `Tower` real ausgelesen wird.
  Element-gebundene Boni laufen ueber `<element>_damage` und werden gegen
  `Tower.get_effective_element()` geprueft. Ein Template mit unbekanntem Key ist
  ein stiller Totalausfall — das Item existiert, tut aber nichts.
- `TowerData.MAX_LEVEL` (7, also 8 Stufen) gilt nur fuer die sechs upgradebaren
  Basistuerme. Element- und Kombinationstuerme sind in `can_upgrade()` zusaetzlich
  ueber die Elementstufe gedeckelt und behalten ihre 3 Stufen. Wer eine Stufe
  ergaenzt, muss **jedes** Array-Feld des Turms verlaengern:
  `TowerData.get_stat()` klemmt den Index und friert sonst lautlos auf dem alten
  Wert ein. `tests/progression_smoke.gd` prueft das inzwischen fuer alle Array-Felder.
- Die Raritaets-Skala hat fuenf Stufen bis `legendary` und liegt in drei getrennten
  Tabellen: `ItemSystem.RARITIES`/`RARITY_ORDER`, `ItemInventoryUI.RARITY_NAMES`
  und `SELL_PRICES`. `_roll_rarity()` enthaelt zusaetzlich eine hartcodierte
  absteigende Liste; fehlt eine Rarität dort, wird ihr Gewicht mitgezaehlt aber nie
  gewaehlt und alle anderen Raritaeten werden still verduennt. Der Smoke-Test
  prueft alle drei Tabellen gegen `RARITY_ORDER`.
- Legendary droppt nur von Bossen ab `RunSchedule.LEGENDARY_DROP_WAVE`; alle
  anderen Gegnerzweige in `_roll_rarity()` muessen das Gewicht **explizit** auf 0
  setzen, weil `RARITIES.duplicate(true)` das Basisgewicht mitbringt.
- Die Schmiede erlaubt pro Besuch nur einen Raritaetsschritt pro Item
  (`forged_wave` am Item-Instanz-Dictionary). Das ist der Schutz gegen
  Raritaets-Waesche und ersetzt eine Gold-Gebuehr bewusst: Gold ist bei den
  Run-Einkommen kein Gate, Zeit schon.
- Panel-Oeffnungs- und Schliessanimationen laufen ueber
  `UITheme.animate_panel_open()` / `animate_panel_close()`. Wer ein neues Overlay
  baut, ruft die Helper auf statt das Fade+Scale-Tween erneut zu kopieren.
- Der Cursor wechselt kontextabhaengig ueber `CursorManager.set_context()`.
  Wichtig: fuer jeden Kontext ist eine **eigene** eingefaerbte Grafik registriert —
  frueher lag dieselbe Textur auf allen Shapes, ein Wechsel war unsichtbar.
  UI-Buttons bekommen den Hand-Cursor zentral in `UITheme.style_button()`.
- Fehlende `char_*`-Portraits erzeugt `IconSystem` prozedural aus der
  Charakter-ID (Rahmen, Elementfarbe, eine von vier Kopfbedeckungen). Eine echte
  PNG-Datei gewinnt immer. Die Kopfbedeckung haengt an der Position in
  `CHARACTERS`, nicht an einem Hash — ein Hash kollidierte ausgerechnet bei den
  beiden Charakteren desselben Elements.
- Neue Ability-Angebote werden ueber `_pick_weighted_new_abilities()` zur
  Element-Affinitaet des Charakters gewichtet (`AFFINITY_WEIGHT`);
  Upgrade-Angebote bleiben uniform.
- Ein nacktes `enemy.new()` ohne Szene crasht bei `apply_burn`/`take_damage`
  (`status_indicator`/`health_bar` fehlen) — Passiv-Hooks dort nicht headless
  ueber Instanzen testen.
- Nach neuen `class_name`-Skripten muss der globale Klassen-Cache regeneriert
  werden (`--headless --editor --quit-after 3`), sonst schlagen Szenenstarts
  mit "Could not find type" fehl.
- Aura-Turm-Boni sind keine zeitlich begrenzten Buffs. Sie werden anhand der
  aktuellen Reichweite der Aura-Tuerme gesammelt und gelten, solange die
  raeumlichen Bedingungen erfuellt sind.
- Die Eiswand besitzt noch keine implementierte Wand-Entitaet.
- Fehlende Assets duerfen nie zu leeren Feldern fuehren: `ItemSystem` schneidet
  eine einzelne 16x16-Zelle aus dem Kategorie-Sammelicon und faerbt sie in der
  Raritaetsfarbe, `IconSystem` faellt auf die `FALLBACKS`-Tabelle zurueck, Tuerme
  ohne Sprite auf einen einheitlichen Platzhalter. Was wirklich fehlt, steht in
  `ASSETS_TODO.md`.
- Die Item-Sammelicons (`weapons`, `accessories`, `gems`, `special`) sind dicht
  gepackte 16x16-Raster ohne Trennlinien. Nie das ganze Sheet als Textur
  zurueckgeben — die Zelle je Item kommt aus `_get_fallback_cell_index()` und
  bleibt fuer ein Item dauerhaft dieselbe.
- Die Panel-Buttons der HUD liegen bewusst ueber der HUD-Leiste
  (`HUD.ICON_ROW_Y`). Auf Leistenhoehe verdeckt sie der Tower-Shop, sobald genug
  Tuerme freigeschaltet sind — er waechst aus der Mitte nach links.
- `chain_targets > 0` allein loest den Kettensprung in `bullet.gd` aus. Ein
  `special_type == "chain"` zusaetzlich zu verlangen wuerde das Kettenglied-Item
  auf Tuermen ohne Ketten-Spezialisierung wirkungslos machen.
- Musik ist optional: fehlt eine Datei in `assets/music/`, ist der Zustands-
  wechsel ein No-Op. Tracks lassen sich ohne Codeaenderung nachreichen.
- `ProgressionSystem.begin_run()` erstellt einen Snapshot der permanenten
  Turm-Unlocks. Diese Semantik bei Refactorings erhalten.
- Tests, die Progressions-Singletons veraendern, muessen ihren Zustand
  wiederherstellen, damit kein lokaler Spielstand versehentlich veraendert
  bleibt.
- Ein Laufzeitfehler in der `_run()`-Coroutine eines `SceneTree`-Tests bricht die
  Coroutine ab, ohne den Prozess zu beenden: `quit()` wird nie erreicht und der
  Headless-Lauf haengt scheinbar grundlos. Auf stdout ist nichts zu sehen, der
  Fehler steht auf stderr — Testlaeufe daher immer mit `2>&1` aufzeichnen.
  Haeufigster Auslöser: ein untypisiertes Array-Literal an einen `Array[Vector2]`
  -Parameter (z. B. `enemy.setup_extended([...], ...)`). Pfade vorher in eine
  `var path: Array[Vector2] = [...]` schreiben.
- Zeitbasierte Asserts in Tests brauchen keine echten Timer: Status-Effekte lassen
  sich deterministisch mit synthetischen Deltas pruefen
  (`enemy._update_status_effects(1.0 / 60.0)` in einer Schleife). Das reproduziert
  auch den frame-abhaengigen Rundungsbug, den ein grober Delta verdecken wuerde.
- Feste Grid-Zellen in Tests sind flaky: der Pfad wird pro Run zufaellig erzeugt und
  kann jede vorher gewaehlte Zelle blockieren. Zellen ueber
  `TowerManager.can_place_at()` zur Laufzeit suchen.

## Test- und Arbeitskonventionen

- Logischer Smoke-Test: `tests/progression_smoke.gd`.
- Funktionaler Smoke-Test in einer echten `main.tscn`: `tests/feature_smoke.gd`
  (Icon-Fallbacks, Turm-Platzhalter, Boss-Leiste, Fahrplan, Inventar-Reset,
  Kettenglied, Stadt/Farm-Aufnahme).
- Visuelle Regression der Spiel-UI: `tests/ui_capture.tscn`.
- Visuelle Regression des Hauptmenues: `tests/main_menu_capture.tscn`.
- Visuelle Regression des Charakter-Rosters: `tests/character_roster_capture.tscn`.
- UI-Captures landen in `user://ui_audit` und werden nicht als Quellassets
  behandelt.
- Vor einem Balance-Test kann der lokale Incremental-Spielstand mit
  `reset_progress.ps1` oder `reset_progress.cmd` zurueckgesetzt werden.
- Bestehende, nicht zu einer Aufgabe gehoerende Aenderungen im Arbeitsbaum
  gehoeren dem Benutzer und werden nicht verworfen oder ueberschrieben.
