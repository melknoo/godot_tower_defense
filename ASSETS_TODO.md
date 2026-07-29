# Fehlende Assets

Alle hier gelisteten Assets werden vom Code bereits erwartet. Solange sie fehlen,
greifen Platzhalter — das Spiel laeuft, sieht an diesen Stellen aber unfertig aus.
Sobald eine Datei existiert, wird sie automatisch verwendet; es ist kein Codeaenderung
noetig.

Stand: 2026-07-21

## 1. Turm-Sprites (hoechste Prioritaet)

Vier von sieben Basistuermen haben kein Sprite und werden als einheitlicher
Platzhalter-Sockel mit Typ-Glyphe gezeichnet
(`tower.gd` → `_setup_placeholder_sprite`).

| Datei | Turm |
| --- | --- |
| `assets/elemental_tower/tower_wizard.png` | Zauberer |
| `assets/elemental_tower/tower_cannon.png` | Kanone |
| `assets/elemental_tower/tower_trapper.png` | Falle |
| `assets/elemental_tower/tower_aura.png` | Aura-Turm |

Zusaetzlich fehlt das Sprite fuer das Sammelgebaeude Stadt:

| Datei | Gebaeude |
| --- | --- |
| `assets/elemental_tower/city.png` | Stadt (nimmt Farmen auf) |

**Format Stadt:** wie `farm.png` (32x48, im Spiel Faktor 2, `offset.y = -8`).
Ersatz ist derzeit ein Polygon-Platzhalter in `tower.gd` → `_setup_city_sprite`.

**Format:** 16x64 px = 4 Frames a 16x16 untereinander (vertikale Animation), wie
`tower_fire.png`. Im Spiel mit Faktor 3 skaliert. Nicht animierte Tuerme koennen auch
16x16 liefern — dann in `data/tower_data.gd` `"animated": false` setzen (ist fuer diese
vier bereits der Fall).

Optional analog dazu die Stufen-Varianten `tower_<typ>_level_2.png` bis `_level_4.png`
(Muster: `tower_fire_level_2.png`).

**Update (MAX_LEVEL 5 → 7, 8 Ausbaustufen):** Für die sechs regulären Ausbau-Türme
(`archer`, `sword`, `wizard`, `cannon`, `trapper`, `aura`) gibt es aktuell **keinerlei**
level-spezifisches Sprite — auch nicht fuer die bisherigen Stufen. `wizard`/`cannon`/
`trapper`/`aura` zeigen ohnehin unconditional den Polygon-Platzhalter (siehe oben,
unabhaengig vom Level). `archer`/`sword` nutzen ein einziges, level-unabhaengiges
Richtungs-Spritesheet (`archer_spritesheet.png` / `sword_spritesheet.png`,
`_setup_archer_sprite()` / `_setup_sword_sprite()` in `tower.gd`) - `_get_tower_texture_path()`
mit dem `tower_<typ>_level_<N>.png`-Muster kommt fuer diese sechs Tuerme nur als Fallback
zum Zug, wenn das Spritesheet fehlt, und faellt dann (ueber die `ResourceLoader.exists`-Pruefung
in `_setup_standard_sprite()`) auf das Basis-Sprite `tower_<typ>.png` zurueck. Die neuen Stufen 7
und 8 sehen also optisch identisch zu den bisherigen Stufen aus - kein neuer Regressionsfall,
aber weiterhin offen: eigene Sprite-Varianten fuer alle 8 Stufen (mindestens fuer die neuen
Stufen 7/8) waeren wuenschenswert, sobald ueberhaupt level-spezifische Turm-Grafiken entstehen.

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
