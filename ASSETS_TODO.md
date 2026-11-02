# Fehlende Assets

Alle hier gelisteten Assets werden vom Code bereits erwartet. Solange sie fehlen,
greifen Platzhalter — das Spiel laeuft, sieht an diesen Stellen aber unfertig aus.
Sobald eine Datei existiert, wird sie automatisch verwendet; es ist kein Codeaenderung
noetig.

Stand: 2026-11-02

`tools/spritegen/` enthaelt einen Python-Generator (numpy + Pillow) fuer
16x16-/16x64-Pixel-Art im Stil der vorhandenen Turm-Sprites (harte Kanten, Alpha
nur 0/255, kleine Palette aus einer Basisfarbe). `pixel.py` ist die geteilte Basis
(`Canvas`, `shade`, `stack_frames`, `emit_tower`, `save_indexed_rgba`), ein
`tower_<typ>.py`-Modul pro Turm, `run_all.py` erzeugt alle auf einmal
(`python3 tools/spritegen/run_all.py [--preview DIR]`, aus `tools/spritegen/` heraus
laufen lassen). Damit erzeugt waren: `wizard`, `cannon`, `trapper`, `aura`, `steam`,
je inklusive Stufen-Varianten — inzwischen durch Ninja-Adventure-Sprites ersetzt
(§1); der Generator schreibt nur noch mit `--force` nach `assets/`.

## 1. Turm-Sprites (hoechste Prioritaet)

**Erledigt (2026-11-02).** Alle Tuerme inkl. Stadt haben ein Sprite. Die vorher
generierten Sprites (`wizard`, `cannon`, `trapper`, `aura`, `steam`) passten nicht
zum Stil der Element-Tuerme und sind ersetzt durch Figuren aus dem
[Ninja Adventure Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack)
von Pixel-boy & AAA (**CC0**, kommerziell frei, Nennung erwuenscht):

| Datei | Quelle im Pack |
| --- | --- |
| `tower_wizard.png` | `Actor/Character/NinjaMageBlack/SpriteSheet.png` |
| `tower_cannon.png` | `Actor/Character/NinjaBomb/SpriteSheet.png` |
| `tower_trapper.png` | `Actor/Monster/SpiderRed/SpriteSheet.png` |
| `tower_aura.png` | `Actor/Monster/LanternGreen/SpriteSheet.png` |
| `tower_steam.png` | `Actor/Monster/Spirit/SpriteSheet.png` (Schattenzeile y=15 entfernt) |
| `city.png` | `Backgrounds/Tilesets/TilesetTowers.png`, Kachel Spalte 6/Zeile 0 (32x32), unten buendig in 32x48 |

Uebernahme: jeweils Spalte 0 (Blick nach unten, 4 Lauf-Frames) = 16x64, exakt das
Format der Element-Tuerme. Die Stufen-Varianten (`_level_2/5/8`, `steam` `_2/_3`)
sind entfernt — alle Stufen nutzen das Basis-Sprite. Ideen fuer spaetere
Stufen-Optik: Farbvarianten aus dem Pack (z. B. `SpiderYellow`, `LanternRed`,
`NinjaMageOrange`). `tools/spritegen/` schreibt nur noch mit `--force` nach `assets/`.

**Format der Turm-Sprites:** 16x64 px = 4 Frames a 16x16 untereinander (vertikale
Animation), wie `tower_fire.png`. Im Spiel mit Faktor 3 skaliert. Nicht animierte
Tuerme koennen auch 16x16 liefern — dann in `data/tower_data.gd` `"animated": false`
setzen. **Stadt/Farm:** 32x48, Faktor 2, `offset.y = -8`.

Weiterhin offen: `archer`/`sword` nutzen ein einziges, level-unabhaengiges
Richtungs-Spritesheet (`archer_spritesheet.png` / `sword_spritesheet.png`,
`_setup_archer_sprite()` / `_setup_sword_sprite()` in `tower.gd`) ohne
Stufen-Varianten — dort waere ein eigener Ansatz noetig (Richtung x Stufe), kein
Fall fuer den 16x16-Generator.

## 2. Gegner-Sprites pro Typ

Aktuell existieren nur Element-Varianten; **alle sieben Gegnertypen benutzen dasselbe
Sprite**, unterschieden nur durch Faerbung und Groesse (`enemy.gd` →
`_apply_type_visuals`). Das ist der groesste optische Schwachpunkt des Spiels.

Vorhanden: `normal_`, `fire_`, `water_`, `earth_`, `air_enemy_level_1.png`
(je 4 Frames nebeneinander).

Gewuenscht — eigene Silhouetten fuer:

| Typ | Rolle |
| --- | --- |
| `swift` | schnell, klein |
| `tank` | langsam, viel HP |
| `ethereal` | halbtransparent, schwebend |
| `brute` | gross, breit |
| `burrower` | graebt sich ein |
| `boss` | Bosswellen (alle 5 Wellen) |

**Format:** wie die vorhandenen Gegner — 4 Frames horizontal, `hframes = 4`.
Dateiname `assets/enemies/<typ>_enemy_level_1.png` (der Loader muss dann in
`enemy.gd:_setup_sprite` um den Typ erweitert werden).

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

Siehe `assets/music/README.md` fuer Musik und die fehlenden Kern-SFX
(`hit.wav`, `enemy_death.wav`, `error.wav` — aktuell Platzhalter aus vorhandenen
Dateien, siehe TODO in `autoload/sound_manager.gd`).

## 6. Ungenutzte Assets

Vorhanden, aber von keinem Code mehr referenziert:

| Datei | Grund |
| --- | --- |
| `assets/elemental_bullets/bullet_sniper.png` | ungenutzt (kein Sniper-Turm im Spiel) |
| `assets/elemental_tower/tower_sniper.png` | ungenutzt (kein Sniper-Turm im Spiel) |

Bleiben liegen, koennen aber fuer einen zukuenftigen Turmtyp wiederverwendet werden.
