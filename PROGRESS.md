# Projektfortschritt

Letzte Aktualisierung: 2026-08-19

## UI-Redesign (siehe design_handoff_ui_system/README_design.md)

Umsetzung läuft phasenweise nach der "Implementation Order" in
`design_handoff_ui_system/README_design.md`. Tokens/StyleBox-Fabriken in
`ui/ui_theme.gd` (Autoload `UI`).

- **Phase 1 (Tokens zentralisieren): fertig.** `UI` als Autoload registriert,
  Theme global gesetzt, alle alten `UITheme.style_*`-Aufrufe/Pergament-Reste
  aus den 18 UI-Scripts entfernt, Pixel-Operator/Silkscreen-Fonts eingebunden.
  Dabei auch mehrere durch die Migration sichtbar gewordene Lesbarkeits-Bugs
  gefixt (hartkodierte dunkle Schrift auf hellen Alt-Buttons, die auf dem
  neuen dunklen Theme unlesbar wurde) und einen echten Crash im
  Pause-Menü-Bestätigungsdialog behoben.
- **Phase 2 (Kontrast & Hierarchie): fertig.** Typo-Skala auf die 5 erlaubten
  Größen (16/20/24/32/48) vereinheitlicht, Panel-Padding wo sinnvoll auf 24
  normalisiert, Primär-/Sekundär-/Danger-Button-Rollen pro Panel vergeben.
  `ui/ability_upgrade_ui.gd` war in Phase 1 übersehen worden (nutzte eigene
  StyleBoxes statt der alten `UITheme`) — in Phase 2 nachgezogen: Radius 0,
  Panel-Material, Farb-Tokens.
- **Phase3b (Shop-Row/Bottombar-Kollision, siehe
  `design_handoff_ui_system/Phase3b_ShopRow_Konzept.md`): fertig**, alle 3
  Schritte je ein eigener Commit:
  1. `ui/shop/shop_card.gd`(+`.tscn`) — feste Karten-Box (Icon-Slot =
     `UI.SLOT_SIZE`, Cost-Row, Name mit `clip_text`+Ellipsis) statt
     textabhängiger Breite; neue `UI.shop_card(state)`-StyleBox-Fabrik.
  2. `ui/tower_shop.gd` instanziert `ShopCard` statt handgebauter
     Icon/Label/Badge-Nodes; alte Corner-Sprite-Selektion entfernt.
  3. Bottombar ist jetzt eine echte HBox (`main.gd::_setup_bottom_bar`):
     Tower-Shop bekam einen echten `ScrollContainer` statt manuellem
     Control+Positions-Hack, `hud.gd`s Wellenstatus-Panel verlor sein
     Anchor-Overlay (`offset_left=-785` etc.) und ist jetzt Geschwister-Kind
     derselben HBox — die Kollision ist strukturell ausgeschlossen statt
     durch Pixel-Werte vermieden. `HUD.ICON_ROW_Y` musste angepasst werden,
     da die neue Bottombar (echte ShopCard-Höhe) höher ist als die alte
     Button-Reihe.
  - Bekannte, damals bewusst nicht angefasste Diskrepanz (inzwischen behoben,
    siehe unten): Türme ohne Sprite-Asset zeigten einen sichtbaren
    `BG_3`-Platzhalter statt still leer zu bleiben (Absicht laut
    Konzept-Doku §2 R4).

## Turm-Sprites via `tools/spritegen/` (2026-08-19)

Alle sieben Basistürme haben jetzt ein echtes, animiertes Sprite statt des
Polygon-Platzhalters: `wizard` (`tower_wizard.png`, erzeugt in `c0aeb16`) sowie neu
`cannon`, `trapper`, `aura` und der Fusionsturm `steam`. Jeder Turm bekam außerdem
Stufen-Varianten an drei Meilensteinen (`_level_2`/`_level_5`/`_level_8`, bei `steam`
`_level_2`/`_level_3` wegen nur 3 Ausbaustufen), mit Fallback in
`tower.gd::_setup_standard_sprite()` auf die nächstniedrigere vorhandene Stufe.
Details siehe `ASSETS_TODO.md` §1 und `tools/spritegen/run_all.py`.
- **Phase 3 (Element-/Rarity-Codierung): offen.** `UI.el()`/`UI.rarity()` an
  Turmkarten, Ability-Cooldowns, Item-Slots, Synergiezeilen anschließen.
  `ui/ability_upgrade_ui.gd::_get_element_color()` nutzt noch ein eigenes,
  unvollständiges 4-Elemente-Set statt `UI.el()` — Kandidat für Phase 3.
- **Phase 4 (HUD-Umbau): fertig**, auf Wunsch vor Phase 3 umgesetzt; 5 Schritte,
  je ein eigener Commit:
  1. `ui/hud.gd`: HUD-Root von bottom-anchored Streifen auf `FULL_RECT`
     umgestellt, alter Streifen unverändert in neuen `BottomStrip`-Container
     verschoben (No-op), leere `TopBar` (64px, oben) angelegt.
  2. HP/Wellen/Ressourcen-Gruppen (Gold · Kerne · Supply) in die TopBar
     gezogen; `seed_label` entfernt (war nirgends mit Text befüllt — totes
     UI-Element), `bonus_preview_label` in die Wellenvorschau verschoben.
     Bewusste Abweichung vom Wireframe: kein "3/12"-Wellenbalken, da das
     Spiel keine feste Wellen-Gesamtzahl kennt (endloser Run).
  3. Alle 9 Panel-Buttons (Inventar, Kerne, Upgrades, Synergien, Fahrplan,
     Schmiede, Statistik, Archiv, Pause) als 56×56-Icon-Cluster ans rechte
     TopBar-Ende gedockt — auf Nutzerwunsch *nicht* auf 3 Buttons
     konsolidiert, alle Panels bleiben 1 Klick entfernt.
  4. Permanente Meta-Anzeige (Aether/Archiv-Stufe/XP/Meilenstein) entfernt:
     `ui/meta_progression_ui.gd` (der `[U]`-Button) zeigt dieselben Werte
     bereits eigenständig — ein zweites Label wäre Duplikat gewesen.
     Ability-Bar wurde erste Spalte der `main.gd`-BottomBar-HBox (Breite 320,
     wie im Wireframe) statt absolut positioniert.
  5. `ui/tower_info.gd`: rechts angedockt (400px, unter der Topbar, Höhe
     gedeckelt via `ScrollContainer`) statt als Popup neben dem Turm.
     1280×720 geprüft: `get_viewport_rect()` bleibt bei
     `content_scale_mode=canvas_items` unabhängig von der Fenstergröße auf
     der 1920×1080-Design-Leinwand — der im README genannte 360px-Breakpoint
     wäre daher totes Code gewesen, bewusst nicht umgesetzt.
  - Beim Umbau aufgefallene, nicht Phase-4-spezifische Falle: `Control.
    set_anchors_preset()` mit einem frisch aus einer `.tscn` geladenen Node
    (gespeicherte `offset_right/bottom`-Werte aus dem Editor-Default) friert
    die Größe auf den alten Wert ein, statt zu strecken — betraf sowohl den
    HUD-Root als auch die erste TopBar-Fassung (`PanelContainer`). Fix:
    manuelle Anchor/Offset-Zuweisung (Muster aus Phase3b's `BottomStrip`)
    statt `set_anchors_preset()`.
- **Phase 3 (Element-/Rarity-Codierung): offen** (übersprungen zugunsten von
  Phase 4). `UI.el()`/`UI.rarity()` an Turmkarten, Ability-Cooldowns,
  Item-Slots, Synergiezeilen anschließen. `ui/ability_upgrade_ui.gd::
  _get_element_color()` nutzt noch ein eigenes, unvollständiges
  4-Elemente-Set statt `UI.el()` — Kandidat für Phase 3.
- **Phase 5 (Polish): offen.** Scrim + Hartschatten, Tooltip-Delay, Zahlen-
  Flash, Panel-Einblendung 80 ms.

### Bekannte Test-Altlast (nicht Phase3b, vorher entstanden)
`tests/ui_capture.gd` prüft an vier Stellen noch
`get_theme_stylebox("panel") is StyleBoxTexture` für Inventar/Element-Kerne/
Aktive-Upgrades/Ability-Bar — seit Phase 1 (Umstieg auf flache `StyleBoxFlat`-
Panels) strukturell veraltet und schlägt seitdem fehl. Nicht in diesem Zug
gefixt (außerhalb des Phase3b-Auftrags), aber hier vermerkt, damit es nicht
als neue Regression missverstanden wird.

Verifikation: `tests/progression_smoke.gd` + `tests/feature_smoke.gd`
(headless) plus `tests/ui_capture.tscn` für visuelle Screenshots unter
`user://ui_audit/`.

## Playtest-Notizen Runde 2 (2026-07-28)

Sechzehn Beobachtungen aus einer Spielsession abgearbeitet, in zwei Phasen.

**Phase A — drei kaputte Mechaniken (waren keine Politur, sondern Ausfaelle):**
- Brennen machte **nie** Schaden: `enemy.gd` rechnete pro Frame
  `int(burn_damage * delta)`, was bei 60 FPS jeden Frame 0 ergab. Laeuft jetzt
  ueber einen festen 0,5-s-Tick (`BURN_TICK_INTERVAL`).
- Ein feuer-graviertes Schwert brannte gar nicht an — `_apply_melee_effects()`
  hatte keinen Burn-Zweig.
- Der Erdkern-Stun wirkte nur mit Erd-Gravur, weil der Wurf an
  `special_type == "stun"` hing. Nahkampf-Effekte werden jetzt einzeln geprueft;
  Cleave und Stun koexistieren. Entscheidung: Stun wirkt unabhaengig von der Gravur.
- Der Feuerrubin war komplett wirkungslos: der Stat-Key `fire_damage` wurde in
  `tower.gd` nirgends gelesen. Jetzt greift generisch `<element>_damage` gegen
  `get_effective_element()`, und TowerInfo zeigt eine Elementarschaden-Zeile.
  `chain_damage` (Blitzkristall) war derselbe Blindgaenger.
- Nebenbefund behoben: `engrave()` verwarf vorhandene Item-Boni bis zum naechsten
  Recalc.

**Phase B — Politur und Payoff:**
- Sniper-Tower-Altlasten entfernt (drei `allowed_towers`, zwei tote `match`-Zweige);
  er tauchte vorher in Item-Tooltips als gueltiger Turm auf.
- Die Stadt gibt eigenes Supply (4) plus den Beitrag aufgenommener Farmen.
- `UITheme.center_button_icon()` und `animate_panel_open/close()` als zentrale
  Helper; zehn kopierte Panel-Tweens abgeloest, `ability_upgrade_ui` und
  `tower_info` erstmals animiert.
- Turm-Statistik faehrt von rechts ein statt die Bildmitte zu belegen.
- Die Schmiede nennt nur noch die Ziel-Raritaet, nicht das Ergebnis-Item.
- Item-Kisten liegen ueber Gegnern (`ItemDrop.z_index = 1`).
- `VFX.spawn_impact_ring()` aus den Bausteinen des Platzier-Effekts; ausgeloest bei
  Crits, schweren Treffern, Upgrades und fuenf Ability-Einschlaegen.
- Kontextabhaengiger Cursor (`CursorManager.set_context()`) mit eigener Grafik pro
  Kontext; vorher lag dieselbe Textur auf allen Shapes.
- Ability-Indikator: gefuellte Flaeche, Puls, markierte Zielgegner, roter Zustand
  wenn kein Gegner im Radius, und ein Spielfeld-Kreis fuer globale Abilities.
- Upgrade-Vorschau datengetrieben ueber `UPGRADE_PREVIEW_STATS`: zeigt „jetzt →
  nachher" fuer jeden Turmtyp, beim Aura-Turm den Buff-Prozentwert statt
  „Schaden: 0".
- Alle vier Basis-Charaktere haben jetzt eine Passive (Brennschaden, Slow-Staerke,
  Stun-Chance, Feuerrate); Anzeige auf der Charakterkarte im Hauptmenue.
  `IconSystem` erzeugt fehlende `char_*`-Portraits prozedural. Die Auswahl steht
  dafuer in **drei** Spalten: mit der zusaetzlichen Passiv-Zeile lief sie bei zwei
  Spalten unten aus dem Bild und der Start-Button war nicht mehr erreichbar.
  Die Kartenhoehe richtet sich nach dem Textinhalt — wer die Beschreibungen
  verlaengert, muss die Gesamthoehe erneut pruefen (aktuell 22 px Puffer bei 1080).
- **Payoff:** `MAX_LEVEL` 5 → 7 (8 Stufen) fuer die sechs upgradebaren Basistuerme,
  Gravur-Skalierung dafuer gekappt. Neue Raritaet `legendary` (×4,5) aus
  Boss-Drops ab Welle 20 (7,2 % gemessen) und der Schmiede, mit drei
  Exklusiv-Items. Forschungsraenge angehoben (logistics/fortification 10,
  starting_funds 12, compound_interest 8, chrono 4). Meilensteine bei Welle 30
  und 35 schliessen die Luecke am regulaeren Run-Ende.
- Drei stille Item-System-Ausfaelle mitgefixt: `stat2`/`value2` wurden nie
  angewendet, Proc-Werte skalierten mit der Raritaet (Executioner: 36 % statt
  12 %), und `berserker_mark` hatte einen Stat-Key ohne Leser.

**Verifikation:** `progression_smoke` und `feature_smoke` gruen (41 Checks, um
Brand-, Stun-, Element-Schaden- und Raritaets-Asserts erweitert), `ui_capture` und
`character_roster_capture` gruen und visuell geprueft. Legendary-Gating und
Schmiede-Sperre separat gegengemessen.

**Offen:** `tests/main_menu_capture.tscn` ist rot — der Test findet den
Optionen-Button nicht. Der Fehler besteht auch auf unveraendertem `HEAD`
(im Worktree gegengeprueft) und ist ein Testproblem, kein Menuefehler.

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
- Reichweiten-Raster (Angriff, Aura, Kanonen-Mindestreichweite) sind nur noch
  beim ausgewaehlten Turm sichtbar und werden bei jeder Auswahl mit den
  aktuellen Werten neu aufgebaut.
- Das Inventar kennt beim Equippen den Zielturm (`filter_tower`): kompatible
  Items sind gruen umrandet, inkompatible gedimmt.
- Tuerme zaehlen Kills und ausgeteilten Schaden getrennt nach aktueller Runde
  und gesamtem Run; `enemy.take_damage()` liefert dafuer den real zugefuegten
  Schaden zurueck und nimmt optional den Verursacher-Turm entgegen. TowerInfo
  zeigt beide Werte an.
- Tuerme lassen sich per Drag & Drop auf einen belegten Platz ziehen und
  tauschen dann die Position (`TowerManager.swap_towers`).
- Items koennen kombiniert werden: zwei Items gleicher Raritaet ergeben ein neu
  gerolltes Item der naechsthoeheren Raritaet. Angeboten wird das kostenlos in
  der "Schmiede" (`ui/item_combine_ui.gd`) nach jeder 5. Welle.

## Game-Feel-Pass 2026-07-21

`GAME_FEEL_ANALYSIS.md` haelt die Analyse fest, warum sich das Spiel noch nicht
wie ein fertiges Spiel anfuehlt, und markiert erledigte gegen offene Punkte.
`ASSETS_TODO.md` listet alle Assets, die der Code bereits erwartet.

- Die Karte wird nur noch **einmal pro Run** erzeugt. Die Pfad-Regenerierung
  alle 3 Wellen ist ersatzlos entfernt (`should_regenerate_path`,
  `_regenerate_map`, `hud.update_wave_preview_after_regen`).
- Alle Wellen-Kadenzen (Perk, Ability-Upgrade, Element-Kern, Schmiede, Boss)
  liegen in `autoload/run_schedule.gd`. `main.gd`, `game_state.gd`,
  `ability_system.gd` und `ui/hud.gd` delegieren dorthin.
- Neues Fahrplan-Panel `ui/run_schedule_ui.gd` (HUD-Button oder Taste `F`) zeigt
  die naechsten 12 Wellen mit ihren Ereignissen.
- Bugfix: `ItemSystem.reset()` wurde nie aufgerufen, dadurch ueberlebte das
  Inventar Run-Grenzen. Laeuft jetzt in `GameState.reset()`.
- Neues Autoload `Music` (`autoload/music_manager.gd`): Crossfade zwischen
  Menue, Bauphase, Welle, Boss und Game Over, plus Musikregler in den Optionen.
  Ohne Dateien in `assets/music/` ist alles ein No-Op.
- Boss-Auftritt: Banner, Screenshake, Blitz, Sound und eine eigene Boss-Leiste
  am oberen Bildrand (`HUD.show_boss_bar`).
- Fehlende Icons fallen weich zurueck: Item-Icons auf das Kategorie-Sammelicon
  in Raritaetsfarbe, UI-Icons ueber `IconSystem.FALLBACKS`. Die vier Tuerme ohne
  Sprite (Zauberer, Kanone, Falle, Aura) teilen sich einen einheitlichen
  Platzhalter statt vier verschiedener Polygone.
- Debug-Ausgaben von 155 auf unter 80 `print()` reduziert; der Frame-Spam aus
  `tower.gd` und `trap.gd` ist weg.

## In Arbeit im lokalen Arbeitsbaum

Branch `playtest-backlog` (von `origin/master`) enthaelt die uncommitteten
Aenderungen aus der Abarbeitung von `playtest-backlog.md` — alle neun Parts A
bis I sind umgesetzt, siehe die Haken in dieser Datei — sowie den Game-Feel-Pass
oben. Neu hinzugekommen sind `ui/item_combine_ui.gd`, `ui/run_schedule_ui.gd`,
`autoload/run_schedule.gd`, `autoload/music_manager.gd`,
`tests/feature_smoke.gd`, `GAME_FEEL_ANALYSIS.md` und `ASSETS_TODO.md`.

Achtung Branch-Lage: `origin/master` ist deutlich weiter als `origin/main`
(Synergie-System, erweitertes Item-System). `main` ist der aeltere Stand; die
beiden Branches sollten zusammengefuehrt und einer davon stillgelegt werden.

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
- Aether-Zufluss wurde rechnerisch gedrosselt (Konstantenblock am Kopf von
  `autoload/progression_system.gd`), aber noch nicht in echten Runs
  gegengeprueft. Kumuliert gegenueber vorher: Welle 10 x0.82, Welle 20 x0.68,
  Welle 30 x0.58, Welle 40 x0.50.
- Kills/Schaden werden nicht attribuiert fuer Abilities, Item-Procs und
  Burn/Bleed-Ticks — diese haben keinen Verursacher-Turm. Der Execute-Proc aus
  `item_system.gd` kann einem Turm den Kill wegnehmen.
- Item-Kombinieren hat keinen Schutz gegen "Raritaets-Waesche": genuegend
  Commons lassen sich ueber mehrere Schmiede-Besuche bis Episch hochziehen.
- Musik ist implementiert, aber es existiert **keine einzige Musikdatei**. Erst
  mit Tracks in `assets/music/` (siehe README dort) wird der groesste
  Feel-Hebel wirksam.
- Alle sieben Gegnertypen benutzen weiterhin dasselbe Sprite, nur eingefaerbt
  und skaliert. Zauberer, Kanone, Falle und Aura haben nur einen Platzhalter.
  Details in `ASSETS_TODO.md`.
- Ein Run kennt weiterhin nur Verlieren als Ende — kein Sieg, kein Kapitel, kein
  Endboss. `get_save_data()`/`load_save_data()` existieren in vier Systemen,
  werden aber nirgends aufgerufen: ein Run laesst sich nicht fortsetzen.
- Es gibt kein Onboarding.
- Die Eiswand-Ability enthaelt weiterhin einen expliziten Platzhalter fuer die
  zu spawnende Wand-Entitaet.
- Die lokalen Dokumentationsaenderungen wurden in dieser Umgebung nicht mit
  einem Markdown-Linter geprueft.
- Godot liegt weiterhin nicht auf `PATH`. Windows: Ordner
  `Downloads/Godot_v4.6.3-stable_win64.exe/` (der Ordner traegt die
  `.exe`-Endung, die eigentliche Datei liegt darin). Linux:
  `~/godot-toolchain/Godot_v4.6.3-stable_linux.x86_64`.

## Naechste empfohlene Arbeitsschritte

0. Die Prioritaetenliste am Ende von `GAME_FEEL_ANALYSIS.md` abarbeiten —
   angefangen bei Musik-Tracks und Gegner-Sprites.
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
godot --headless --path . --script res://tests/feature_smoke.gd
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

Letzte Verifikation (2026-07-21, Linux, Godot 4.6.3): Progressions-Smoke-Test
(inkl. neuer Kadenz-Asserts fuer `RunSchedule`) und der neue
`tests/feature_smoke.gd` liefen gruen durch; Projektimport und ein Start von
`main.tscn` headless ohne Skriptfehler. **Nicht geprueft:** die Capture-Tests
und alles Visuelle — auf dieser Maschine war kein Display verfuegbar. Boss-Leiste,
Turm-Platzhalter, Fahrplan-Panel und Icon-Fallbacks sind funktional getestet,
aber noch nie mit Augen gesehen.

Verifikation davor (2026-07-16): Progressions-Smoke-Test (inkl. Rekrutierungs-,
Migrations- und Passiv-Asserts), der vollstaendige UI-Capture-Test, die
Hauptmenue-Capture und die Roster-Capture liefen erfolgreich durch; der
Roster-Screenshot wurde visuell geprueft.

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
