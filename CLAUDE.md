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

`ui/hud.gd` (~2200) · `tower.gd` (~2000) · `autoload/vfx_manager.gd` (~1400) · `main.gd` (~1300) · `autoload/ability_system.gd` (~1200) · `ui/tower_info.gd` (~1100) · `autoload/item_system.gd` (~1050)

## Codebase-Map

### Autoloads (`autoload/`, registriert in `project.godot` — Namen sind implizite API)
- `ability_system.gd` — aktive Fähigkeiten, Cooldowns, Upgrades
- `elemental_system.gd` — Elemente/Status-Effekte
- `synergy_system.gd` — Synergien/Mastery zwischen Türmen
- `item_system.gd` — Items, Drops, Kombination
- `upgrade_system.gd` / `progression_system.gd` — Run- bzw. Meta-Progression
- `run_schedule.gd` — Wellen-/Run-Fahrplan
- `vfx_manager.gd`, `sound_manager.gd`, `music_manager.gd`, `icon_system.gd`, `cursor_manager.gd`, `range_grid.gd` — Präsentation/Utility

### Gameplay (Root)
- `main.gd`/`main.tscn` — Spielszene, verdrahtet alles
- `tower.gd`, `tower_manager.gd`, `data/tower_data.gd` — Türme (Logik, Platzierung, Daten)
- `enemy.gd`, `wave_manager.gd` — Gegner & Wellen
- `bullet.gd`, `trap.gd`, `item_drop.gd` — Projektile, Fallen, Drops
- `game_state.gd` — Run-Zustand
- `path_generator.gd`, `ground_layer.gd`, `decoration_manager.gd`, `tilemap_slicer.gd` — Map-Generierung
- `main_menu.gd`, `ui_theme.gd` — Menü & Theme

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

## Wartung dieser Datei

Wenn neue Systeme/Dateien >300 Zeilen entstehen oder Dateien die 800-Zeilen-Schwelle überschreiten: Map und Große-Dateien-Liste hier in 1–2 Zeilen nachziehen. Die Map ist der Haupt-Token-Sparer — veraltet ist sie schädlicher als keine.
