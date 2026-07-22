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
