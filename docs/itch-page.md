# itch.io-Seite

Seite: https://melleeee.itch.io/arcane-defense (Edit: https://itch.io/game/edit/4935400).
Build-Upload per `deploy_itch.cmd` (siehe CLAUDE.md), Seiteninhalte pflegt Claude über die
Chrome-Erweiterung. Vorgehen wie bei Legion Pixel (`D:\another_claude_test\docs\shorts.md`):
Bilder aus dem laufenden Spiel rendern, Texte hier ablegen, dann ins Formular übernehmen.

## Stand (02.11.2026)

- [x] Titel „Arcane Bastion“ (wie im Hauptmenü). Slug/URL bleibt `arcane-defense`; `config/name`
  in `project.godot` bleibt „Arcane Defense“, sonst wechselt der `user://`-Ordner und
  Spielstände/Meta-Fortschritt wären weg.
- [x] Kurztext, Beschreibung (EN + DE-Block), Genre Strategy, Tags, AI-Disclosure (Code).
- [x] Cover + 6 Screenshots aus `docs/itch/`, Embed mit Vollbild-Button. Gespeichert 02.11.
- [x] Build 0.1.0.3 (Web + Windows): Ninja-Adventure-Türme + Fix Charakterauswahl
  (Starten-Button lag unter dem Bildrand, `main_menu.gd`). Im itch-Embed getestet:
  Menü, Optionen, Charakterauswahl.
- [ ] Theme wie Legion Pixel: `header.png` (730x280, transparent) und `background.png`
  (abgedunkeltes Spielfeld, Verlauf in `#0b1020`) liegen bereit. Farben: BG `#0b1020`,
  Innenspalte `#101628` (~92 %), Text `#e8e4d8`, Links `#f0b848`, Rahmen `#3a4566`,
  Buttons `#f0b848` / Schrift `#1a1408`.
- [ ] Sichtbarkeit: bleibt **restricted**, Public schaltet der Owner selbst.
- [ ] Optional: Musik (Ninja Adventure enthält 37 CC0-Tracks, `assets/music/` ist leer).

## Bilder (`docs/itch/`, mit `.gdignore` – landen nicht im `.pck`)

| Datei | Inhalt | Quelle |
|---|---|---|
| `cover.png` | 630x500, Spielfeld 2:1 verkleinert (pixelgenau) + Titel in Silkscreen | Mid-Game-Capture Welle 7 |
| `shot1_gameplay.png` | komplette Spielansicht mit HUD | Mid-Game-Capture |
| `shot2_closeup.png` | Nahaufnahme Pfad + Gegner, 2x Nearest | Mid-Game-Capture |
| `shot3_wave_upgrades.png` | Upgrade-Wahl nach der Welle | `tests/ui_capture.tscn` (05) |
| `shot4_abilities.png` | Ability-Upgrade | `tests/ui_capture.tscn` (08) |
| `shot5_tower_info.png` | Turm-Info (Zauberer) | Mid-Game-Capture |
| `shot6_archive.png` | Arkanes Archiv (Meta-Forschung) | `tests/ui_capture.tscn` (03) |

Mid-Game-Capture: temporäre Szene, die `main.tscn` lädt, Elemente/Türme freischaltet,
18 Türme per `tower_manager.place_tower()` entlang `main.path_cells` setzt, Welle 7 startet
(`Engine.time_scale = 2`) und alle 4 s `get_viewport().get_texture().get_image()` speichert.
Fenster ist 2560x1440 (Viewport 1920x1080) → Türme sind dort 4 px pro Kunstpixel, also
Ausschnitte mit Faktor 1/2 bzw. 2 bleiben pixelgenau.

## Felder

- **Titel:** Arcane Bastion
- **Kurztext:** Elemental pixel-art tower defense: fuse elements, forge items and research
  between runs. Plays in your browser.
- **Genre:** Strategy
- **Tags:** tower-defense, pixel-art, roguelite, fantasy, elemental, singleplayer,
  incremental, 2d, magic, cute (itch rät, Genre/Plattform nicht als Tag zu doppeln)
- **AI-Disclosure:** ja, Code (Grafik: Ninja Adventure CC0 + prozedural; Sound/Musik nicht KI)
- **Embed:** 1280x720, Vollbild-Button an

## Beschreibung

```html
<p><strong>Arcane Bastion</strong> is a pixel-art tower defense about elements. Every run builds a new path, and every wave asks a different question: which element is it weak to, and which one does it shrug off?</p>
<p>Build swordsmen, archers, wizards, cannons, traps and aura towers, then engrave them with Fire, Water, Earth or Air. Unlock the elemental spirits and fuse them into Steam, Ice, Lava and Nature towers.</p>
<ul>
<li>Pick one of three upgrades after every wave (or reroll)</li>
<li>Boss wave every 5 waves</li>
<li>37 items up to legendary, combine them at the forge</li>
<li>Active abilities like Meteor and Frost Nova, with their own upgrades</li>
<li>Farms and cities raise your supply for more towers</li>
<li>Arcane Archive: research that carries over between runs, plus 8 characters with their own starting ability</li>
</ul>
<p><strong>Controls:</strong> mouse to build, click a tower to upgrade, engrave or sell. 1–4 abilities · E elements · I inventory · U upgrades · Y synergies · T tower stats · F run schedule · M archive · Esc pause.</p>
<p><strong>In-game language: German.</strong> Early version, feedback in the comments is very welcome.</p>
<hr>
<p><strong>Deutsch:</strong> Pixel-Art-Tower-Defense mit Elementen. Türme bauen, mit Feuer, Wasser, Erde oder Luft gravieren, Elemente zu Dampf, Eis, Lava und Natur verschmelzen, Items schmieden und zwischen den Runs im Arkanen Archiv forschen. Läuft direkt im Browser.</p>
<p>Art: tower and city sprites from the <a href="https://pixel-boy.itch.io/ninja-adventure-asset-pack">Ninja Adventure Asset Pack</a> by Pixel-boy &amp; AAA (CC0). Fonts: Silkscreen &amp; Noto (OFL), Pixel Operator (CC0).</p>
```
