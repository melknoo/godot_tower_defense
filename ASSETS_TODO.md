# Fehlende Assets

Alle hier gelisteten Assets werden vom Code bereits erwartet. Solange sie fehlen,
greifen Platzhalter — das Spiel laeuft, sieht an diesen Stellen aber unfertig aus.
Sobald eine Datei existiert, wird sie automatisch verwendet; es ist kein Codeaenderung
noetig.

Stand: 2026-11-03

`tools/spritegen/` enthaelt einen Python-Generator (numpy + Pillow) fuer
16x16-/16x64-Pixel-Art im Stil der vorhandenen Turm-Sprites (harte Kanten, Alpha
nur 0/255, kleine Palette aus einer Basisfarbe). `pixel.py` ist die geteilte Basis
(`Canvas`, `shade`, `stack_frames`, `emit_tower`, `save_indexed_rgba`), ein
`tower_<typ>.py`-Modul pro Turm, `run_all.py` erzeugt alle auf einmal
(`python3 tools/spritegen/run_all.py [--preview DIR]`, aus `tools/spritegen/` heraus
laufen lassen). Damit erzeugt waren: `wizard`, `cannon`, `trapper`, `aura`, `steam`,
je inklusive Stufen-Varianten — inzwischen durch Ninja-Adventure-Sprites ersetzt
(§1); der Generator schreibt nur noch mit `--force` nach `assets/`.

## 1./2. Welt-Grafik: Tuerme, Gegner, Boden, Deko

**Erledigt (2026-11-03): Art-Vereinheitlichung.** Alle Welt-Grafik kommt aus dem
[Ninja Adventure Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack)
(Pixel-boy & AAA, **CC0**) und wird reproduzierbar von
`tools/ninja_import/build_assets.py` erzeugt (Zuordnungstabellen oben im Skript):

```
python -I tools/ninja_import/build_assets.py --pack "<Pack>/Ninja Adventure - Asset Pack" --write
python -I tools/ninja_import/build_assets.py --pack ... --preview kontaktbogen.png
```

Das Pack liegt bewusst ausserhalb des Repos (lokal: `D:\assets_src\ninja_adventure\`).

**Regel:** 16-px-Art, im Spiel ganzzahlig **x4** - ein 16-px-Tile fuellt genau eine
64-px-Zelle. Keine Rotation, keine Typ-Skalierung; Groesse kommt ueber die Silhouette.
Zwei dokumentierte Ausnahmen: **Bosse x3** (Quell-Sprites ~40 px) und **Farm/Stadt x2**
(32-px-Gebaeude aus `TilesetTowers.png`).

| Was | Datei(en) | Quelle im Pack |
| --- | --- | --- |
| Tuerme | `elemental_tower/tower_<id>.png`, 16x32 = [Stand, Angriff] | `Actor/Character/*` (Zuordnung `TOWERS`) |
| Runensockel | `elemental_tower/pedestal.png` + `pedestal_glow.png` | im Skript gezeichnet, Rune per `modulate` in Elementfarbe |
| Farm / Stadt | `elemental_tower/farm.png`, `city.png`, 32x32 | `Backgrounds/Tilesets/TilesetTowers.png` |
| Gegner pro Typ | `enemies/enemy_<typ>.png`, 64x16 (4 Lauf-Frames) | `Actor/Monster/*` (Zuordnung `ENEMIES`) |
| Boss pro Element | `enemies/boss_<element>.png`, Idle-Streifen | `Actor/Boss/*` (Zuordnung `BOSSES`) |
| Gras | `tiles/grass_atlas.png` | `TilesetFloor.png` |
| Weg + Zonen | `tiles/path_atlas.png`, Zeile = Material (Erde, Schlamm, Furt, Asche, Windpass) | `TilesetFloor.png`, umgefaerbt |
| Deko | `decorations/nature_atlas.png` | `TilesetNature.png` |

Tuerme = Figuren, Gegner = Monster: so bleibt Freund/Feind schon an der Figurenart
lesbar, der Sockel verstaerkt das. Der Weg wird zur Laufzeit aus 8x8-Vierteln der
Pfad-Kacheln komponiert (`ground_layer.gd::_compose_path_cell`), die ganze Karte als
ein Bild.

Entfernt: Tiny-Swords-Deko (`decorations/01-15.png`), `grass_tileable.png`,
`ground.png`, `tilemap.png` + 521 ungenutzte Slices (`tilemap_slicer.gd`), die
192-px-Bogen/Schwert-Sheets, alte Slime-Gegner, Stufen-Varianten.

**Offen - Lizenz:** `assets/ui/` (Buttons, Panels, Banner, Ribbons, Auswahlecken)
stammt vermutlich noch aus Tiny Swords (Pixel Frog, Commit `829d494`). Das Repo ist
oeffentlich; die Tiny-Swords-Lizenz erlaubt nach meinem Stand keine Weitergabe der
Dateien selbst. Pruefen und entweder ersetzen oder Credits/Rechte klaeren.

## 3. Item-Icons

Fehlende Rarity-Varianten. Fallback ist derzeit das Kategorie-Sammelicon
(`weapons.png` / `accessories.png` / `gems.png` / `special.png`), eingefaerbt in der
Raritaetsfarbe (`ItemSystem._create_category_fallback_texture`).

| Icon-Basis | Kategorie | Fehlende Raritaeten |
| --- | --- | --- |
| `longrange_bow` | accessory | rare |
| `frost_breaker` | special | uncommon, rare, epic |
| `ember_lance` | special | uncommon, rare, epic |
| `undertow_blade` | special | uncommon, rare, epic |
| `first_strike` | special | uncommon, rare, epic |
| `blast_bolt` | special | rare, epic |
| `ember_core` | special | uncommon, rare, epic |
| `frost_splinter` | special | rare, epic |
| `executioner` | special | epic |

**Format:** `assets/items/<basis>_<raritaet>.png`, gleiche Groesse wie die vorhandenen
Item-Icons. Alternativ reicht ein raritaetsloses `<basis>.png` als Basis-Icon fuer alle
Stufen.

### 3b. Legendary (neue Rarität, ab Welle `RunSchedule.LEGENDARY_DROP_WAVE`)

`assets/items/loot_legendary.png` fehlt komplett - `item_drop.gd` laedt den Rarity-Marker
seit dieser Aenderung ueber `ResourceLoader.exists()` (nicht mehr per hartem `preload`,
das haette bei fehlender Datei jede Szene mit `ItemDrop` beim Parsen zerrissen) und faellt
ohne die Datei auf `loot_epic.png` zurueck, per `rarity_marker.modulate` amber eingefaerbt.
Sieht bereits im Spiel korrekt aus, ein eigenes Bild waere aber sauberer.

Ebenfalls komplett neu und ohne eigenes Icon (fallen auf das Kategorie-Sammelicon
`special.png` bzw. `accessories.png` zurueck, s.o.):

| Icon-Basis | Kategorie |
| --- | --- |
| `sunforged_core` | special |
| `stormcrown` | special |
| `midas_sigil` | accessory |

**Format:** wie oben, `assets/items/<basis>.png` bzw. `<basis>_legendary.png`.

## 4. UI-Icons

**UI-Theme (2026-11-11):** Panels, Buttons, Slots, Tooltips und Font kommen aus dem
Ninja-Adventure-Pack (`Ui/Theme/Theme Wood`, `Ui/Font/NormalFont.ttf`, `Ui/Skill Icon/` für
Archiv/Synergie/Schmiede), gebaut mit `tools/ninja_import/build_assets.py --ui`.
Offen: weitere Glyphen/Emoji im Text (💰 in der Wellenvorschau, ⚠) durch Pixel-Icons ersetzen.

In `autoload/icon_system.gd` registriert, Datei fehlt. Ersatz laut `FALLBACKS`-Tabelle
dort.

| Datei | aktueller Ersatz |
| --- | --- |
| `assets/icons/warning.png` | `damage.png` |
| `assets/icons/core_fire.png` | `core.png` |
| `assets/icons/core_ice.png` | `core.png` |
| `assets/icons/core_lightning.png` | `core.png` |
| `assets/icons/core_earth.png` | `core.png` |
| `assets/icons/core_nature.png` | `core.png` |

## 5. Audio

**Erledigt (2026-11-03):** Musik (5 Tracks) und die drei Kern-SFX `hit.wav`,
`enemy_death.wav`, `error.wav` aus Ninja Adventure (CC0), siehe `assets/music/README.md`.

## 6. Ungenutzte Assets

Vorhanden, aber von keinem Code mehr referenziert:

| Datei | Grund |
| --- | --- |
| `assets/elemental_bullets/bullet_sniper.png` | ungenutzt (kein Sniper-Turm im Spiel) |

Bleiben liegen, koennen aber fuer einen zukuenftigen Turmtyp wiederverwendet werden.
