# CLAUDE.md — Godot Tower Defense

Godot 4.6, reines GDScript, kein Build-Step. Einstieg: `main.tscn` / `main.gd`.
Projekt-Doku: `PROGRESS.md` (Stand & Toolchain), `MEMORY.md` (Architektur-Notizen), `playtest-backlog.md` (offene Aufgaben).

## Token-Spar-Konzept

Ziel: Der Hauptkontext (teures Modell, z. B. Opus im Plan Mode) bleibt schlank und trifft nur Entscheidungen. Alles, was "Dateien wälzen" bedeutet, geht an Subagents mit günstigeren Modellen.

### Regeln (in dieser Reihenfolge anwenden)

1. **Erst die Codebase-Map unten nutzen** — kein Glob/Grep für Fragen, die die Map schon beantwortet.
2. **Große Dateien nie komplett lesen.** Dateien >800 Zeilen (Liste unten): erst `Grep` nach Symbol/Funktion, dann `Read` mit `offset`/`limit` nur auf den relevanten Bereich.
3. **Breite Suchen delegieren.** "Wo wird X benutzt?", "Wie hängt A mit B zusammen?", Ist-Zustand über mehrere Dateien → `Explore`-Subagent, nicht selbst durchklicken.
4. **Plan Mode:** Recherche-Phase an `Explore` (haiku/sonnet) auslagern; der Planner liest nur die kompakten Ergebnisse (file:line + 1-Satz-Befunde) und entwirft den Plan. Mechanische Umsetzung danach an sonnet delegierbar.
5. **Subagent-Prompts selbstversorgend schreiben:** konkrete Pfade/Symbole mitgeben (aus der Map), als Ergebnis eine kompakte Zusammenfassung mit `file:line`-Referenzen anfordern — explizit "keine Code-Dumps zurückgeben".
6. **Kleine, lokale Edits (1–2 Dateien, bekannte Stelle): direkt machen**, kein Subagent — ein Subagent-Kaltstart kostet mehr als er spart.

### Subagent-/Modell-Matrix

| Aufgabe | Agent | Modell |
|---|---|---|
| Symbol/Verwendung finden, "wo ist X?" | Explore | haiku |
| Ist-Zustand mehrerer Systeme erheben (für Planung) | Explore | sonnet |
| Implementierungsplan für größeres Feature | Plan | opus/Hauptmodell |
| Mechanische Edits nach klarem Plan (Renames, Wiederholmuster) | general-purpose | sonnet |
| Architektur-Entscheidung, Balance-Design, Review | Hauptkontext | — |

### Große Dateien (>800 Zeilen — nur gezielt lesen)

`ui/hud.gd` (~2200) · `tower.gd` (~2050) · `autoload/vfx_manager.gd` (~1450) · `main.gd` (~1400) · `ui/tower_info.gd` (~1250) · `autoload/ability_system.gd` (~1200) · `autoload/item_system.gd` (~1125)

## Codebase-Map

### Autoloads (`autoload/`, registriert in `project.godot` — Namen sind implizite API)
- `ability_system.gd` — aktive Fähigkeiten, Cooldowns, Upgrades
- `elemental_system.gd` — Elemente/Status-Effekte
- `synergy_system.gd` — Synergien/Mastery zwischen Türmen
- `item_system.gd` — Items, Drops, Kombination
- `upgrade_system.gd` / `progression_system.gd` — Run- bzw. Meta-Progression
- `run_schedule.gd` — Wellen-/Run-Fahrplan (auch `LEGENDARY_DROP_WAVE`)
- `vfx_manager.gd`, `sound_manager.gd`, `music_manager.gd`, `icon_system.gd`, `cursor_manager.gd`, `range_grid.gd` — Präsentation/Utility
  - `icon_system.gd` erzeugt fehlende `char_*`-Portraits prozedural
  - `cursor_manager.gd` bietet `set_context()` mit eigener Grafik pro Kontext

### Gameplay (Root)
- `main.gd`/`main.tscn` — Spielszene, verdrahtet alles
- `tower.gd`, `tower_manager.gd`, `data/tower_data.gd` — Türme (Logik, Platzierung, Daten)
- `enemy.gd`, `wave_manager.gd` — Gegner & Wellen
- `bullet.gd`, `trap.gd`, `item_drop.gd` — Projektile, Fallen, Drops
- `game_state.gd` — Run-Zustand
- `path_generator.gd`, `ground_layer.gd`, `decoration_manager.gd`, `tilemap_slicer.gd` — Map-Generierung
- `main_menu.gd`, `ui_theme.gd` — Menü & Theme. `ui_theme.gd` hält die zentralen
  UI-Helper: `animate_panel_open/close()`, `center_button_icon()`, `style_*button()`
  (setzt auch den Hover-Cursor) — neue Panels/Buttons nutzen die, statt zu kopieren
- `deploy_itch.ps1` + `tools/find_godot.ps1` — Build & Upload nach itch.io (eigener
  Abschnitt unten); Artefakte landen in `export/` (gitignored)
- `tools/spritegen/` — Python-Generator (numpy + Pillow, kein Godot-Bezug) für
  fehlende 16x16/16x64-Turm-Sprites im Pixel-Art-Stil; `pixel.py` = geteilte
  Basis, `tower_<typ>.py` = je ein Turm (inkl. Stufen-Varianten), `run_all.py`
  erzeugt alle auf einmal. Siehe `ASSETS_TODO.md`.

### UI (`ui/`)
- `hud.gd` — In-Game-HUD (größte Datei!)
- `tower_shop.gd`, `tower_info.gd`, `tower_stats_ui.gd` — Turm-Kauf/-Info
- `ability_bar.gd`, `ability_upgrade_ui.gd` — Fähigkeiten
- `item_inventory_ui.gd`, `item_combine_ui.gd` — Items
- `wave_upgrade_ui.gd`, `upgrade_overview.gd`, `meta_progression_ui.gd`, `element_unlock_ui.gd`, `synergy_panel.gd` — Progression/Overlays
- `pause_menu.gd`, `run_schedule_ui.gd`, `character_roster_ui.gd`

## Tests & Verifikation

Godot liegt **nicht** auf PATH (Windows: `Downloads/Godot_v4.6.3-stable_win64.exe/`-Ordner, siehe `PROGRESS.md`). Headless-Smoke-Tests:

```
godot --headless --path . --script res://tests/progression_smoke.gd
godot --headless --path . --script res://tests/feature_smoke.gd
```

UI-Screenshots: `godot --path . res://tests/ui_capture.tscn`. Nach Szenen-/Skriptänderungen ggf. Import-Cache aktualisieren: `--headless --editor --quit-after 3` (siehe `MEMORY.md`).

## Deploy & Export (itch.io)

`deploy_itch.ps1` (Windows, PS 5.1) baut und pusht in einem Rutsch:
Godot finden → Smoke-Tests → Import-Warmup → Export `Windows Desktop` + `Web`
→ Artefakte auf Existenz/Mindestgröße prüfen → butler holen → `butler push` in die
Channels `windows` und `web`. Portiert aus `D:\surv_like\deploy_itch.ps1`.

```
.\deploy_itch.cmd -NoPush        # nur bauen
.\deploy_itch.cmd                # bauen + hochladen
.\deploy_itch.cmd -SkipWindows   # nur Web
```

`deploy_itch.cmd` ist nur ein Wrapper, der `deploy_itch.ps1` mit
`-NoProfile -ExecutionPolicy Bypass` startet und die Argumente durchreicht. Ohne ihn
scheitert der direkte Aufruf an Windows' Default-Policy `Restricted` (hier ist weder
für `CurrentUser` noch `LocalMachine` etwas gesetzt).

Setup einmalig: `deploy.env` aus `deploy.env.example` anlegen (`BUTLER_API_KEY` von
itch.io → Settings → API keys). Godot-Binary findet `tools/find_godot.ps1` selbst;
`GODOT_PATH` in `deploy.env` überschreibt. Version = `config/version` aus
`project.godot` + `.deploy_build_number`; der Zähler steigt erst nach erfolgreichem Push.

### Web-Fallstricke (alle bereits gelöst — nicht versehentlich zurückdrehen)

- **Kein Thread-Support** (`variant/thread_support=false`). Das Projekt nutzt nirgends
  `Thread`/`WorkerThreadPool`/`Mutex`/`Semaphore`. Dadurch braucht die itch-Seite die
  Option „SharedArrayBuffer support" **nicht**. Wer Threads einführt, bricht das.
- **Renderer:** im Browser läuft zwingend `gl_compatibility` — der Web-Export-Template
  enthält gar keinen anderen. `project.godot` setzt deshalb bewusst **keinen**
  `rendering/renderer/rendering_method`-Key (Per-Plattform-Default). Lokal gegenprüfen:
  `--rendering-driver opengl3`.
- **`export/*` muss im `exclude_filter` bleiben**, sonst zieht das Import-Warmup die
  Build-PNGs (`index.png` & Co.) als Projekt-Ressourcen ein und sie landen im nächsten `.pck`.
- **Cursor-SVG:** `autoload/cursor_manager.gd` liest `assets/ui/arcane_cursor.svg` als
  *Rohtext*. Quelldateien importierter Ressourcen landen nie im `.pck`, und `include_filter`
  ändert daran nichts — deshalb steht in `arcane_cursor.svg.import` `importer="keep"`.
  Wird der Importer zurückgesetzt, ist der Cursor im Web-Build weg.
- **Kein Vollbild, kein Beenden:** `DisplayServer.window_set_mode()` scheitert im Iframe
  ohne User-Geste, `get_tree().quit()` hinterlässt ein totes Canvas. Beides ist über
  `OS.has_feature("web")` gegated (`ui/pause_menu.gd`, `main_menu.gd`, `main.gd`);
  im Web führt „Run beenden" ins Hauptmenü.
- **Butler pusht ganze Ordner** — das Export-Verzeichnis wird vor jedem Build geleert.
  Kanalname = Verzeichnisname unter `export/`.
- **Godot meldet Export-Fehler nicht zuverlässig per Exit-Code** — deshalb prüft
  `Assert-Artifact` zusätzlich Existenz und Mindestgröße. Logs: `export/_logs/`.

### Audio

Die Quell-WAVs sind 48 kHz Stereo, auf ~2,5 s Länge gepolstert (~1,85 MB pro Klick).
Alle `assets/sounds/*.wav.import` stehen deshalb auf `force/mono=true` + `edit/trim=true`
(+ `compress/mode=2`, QOA): 30 MB Rohdaten → ~0,2 MB im `.pck`. `force/max_rate` bleibt
**aus** — die Größe kommt praktisch komplett aus dem Trim, Downsampling würde nur Höhen kosten.

## Wartung dieser Datei

Wenn neue Systeme/Dateien >300 Zeilen entstehen oder Dateien die 800-Zeilen-Schwelle überschreiten: Map und Große-Dateien-Liste hier in 1–2 Zeilen nachziehen. Die Map ist der Haupt-Token-Sparer — veraltet ist sie schädlicher als keine.
