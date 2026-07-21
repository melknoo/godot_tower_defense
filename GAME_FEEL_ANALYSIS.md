# Warum es sich noch nicht wie ein fertiges Spiel anfuehlt

Analyse vom 2026-07-21, ausgeloest durch die Beobachtung nach einer Spielsession:
„Das Spiel fuehlt sich immer noch nicht wie ein richtiges Spiel an."

Die Ursachen sind **nicht** fehlende Features — davon gibt es reichlich (Elemente,
Kerne, Gravur, Items, Abilities, Synergien, Aether, Forschung, Charaktere). Sie liegen
in Grundlagen, die ein Spiel als Spiel lesbar machen: ein Ort, eine Stimme, ein Ziel,
ein Rhythmus.

Statuszeichen: ✅ in dieser Sitzung erledigt · ⏳ offen (Backlog unten).

---

## 1. Die Welt hatte keine Identitaet ✅ (Karte) / ⏳ (Rest)

`main.gd` erzeugte alle 3 Wellen einen komplett neuen Pfad (`should_regenerate_path`,
Wellen 2, 5, 8, 11 …) und baute Ground plus Dekoration neu auf. Tuerme landeten dadurch
auf dem neuen Pfad, wurden „blockiert" und sperrten den Wellenstart, bis man umbaute.

Tower Defense lebt vom Gefuehl **„mein Bollwerk waechst an *diesem* Ort"**. Genau das
wurde dreimal pro zehn Wellen entwertet. Alles, was der Spieler ueber die Karte gelernt
hatte — gute Kurven, Engstellen, Reichweiten-Ueberlappungen — war regelmaessig wertlos.

**Erledigt:** Der Pfad wird nur noch einmal pro Run erzeugt.

**Offen:** Es gibt weiterhin nur eine Grastextur, keine Karten- oder Levelauswahl, keine
Biome. Ein Run sieht aus wie jeder andere.

## 2. Alle Gegnertypen sind dasselbe Sprite ⏳

`enemy.gd:_setup_sprite()` laedt nur nach *Element* (5 Dateien). Die sieben Typen
— normal, swift, tank, ethereal, brute, burrower, boss — unterscheiden sich in
`_apply_type_visuals()` ausschliesslich durch `modulate` und `scale`.

Der Boss ist also ein grosser gelber Slime. Ein Spieler, der „Tank" und „Brute"
auseinanderhalten soll, sieht zwei unterschiedlich grosse Farbvarianten desselben
Tropfens. Das ist der groesste rein optische Schwachpunkt.

**Teilweise entschaerft:** Der Boss bekommt jetzt einen eigenen Auftritt — Banner,
Screenshake, Blitz, Sound und eine eigene Lebensleiste am oberen Bildrand. Der Moment
ist damit lesbar, das Sprite bleibt aber dasselbe. Assets: siehe `ASSETS_TODO.md`.

## 3. Vier Tuerme hatten gar kein Sprite ✅ (entschaerft)

Zauberer, Kanone, Falle und Aura fielen auf vier handgeschriebene `Polygon2D`-Formen
zurueck — flache Vektorklecks neben 16x16-Pixelart. Vier *verschiedene* improvisierte
Formen lesen sich wie ein Bug.

**Erledigt:** Ein einheitlicher Platzhalter (Sockel mit Schatten, Umriss, Turmfarbe und
Typ-Glyphe) im selben Raster wie die echten Sprites. Das liest sich als Absicht, nicht
als Fehler — ersetzt aber keine echten Sprites (`ASSETS_TODO.md`).

## 4. Kein Audio-Fundament ✅ (System) / ⏳ (Tracks)

Es gab **keine Musik, kein Ambient, keinen einzigen Musik-Player**. 16 WAV-Dateien
insgesamt, davon drei laut TODO in `sound_manager.gd` nur Platzhalter (`hit`,
`enemy_death` und `error` benutzen dieselben zwei Dateien).

Nichts trennt „Prototyp" von „Spiel" so stark und so billig wie ein Musik-Loop plus
Ambient. Stille bei gleichzeitig lauten UI-Klicks wirkt wie ein Testbuild.

**Erledigt:** `autoload/music_manager.gd` mit Crossfade zwischen Menue, Bauphase, Welle,
Boss und Game Over, plus Musikregler in den Optionen. **Offen:** die Tracks selbst —
siehe `assets/music/README.md`. Ohne Dateien ist das System ein sauberes No-Op.

## 5. Kein Bogen, kein Ziel, kein Speichern ⏳

- Ein Run endet **ausschliesslich** durch Verlieren. Es gibt keinen Sieg, kein
  Kapitelende, keinen Endboss, keinen Abspann. Endlose Wellen ohne Zieldefinition
  fuehlen sich wie ein Sandkasten an, nicht wie ein Spiel, das man „durchspielt".
- `get_save_data()` / `load_save_data()` existieren in `game_state.gd`,
  `item_system.gd`, `ability_system.gd` und `data/tower_data.gd` — und werden
  **nirgends aufgerufen**. Ein Run laesst sich nicht unterbrechen und fortsetzen. Wer
  bei Welle 25 aufhoeren muss, verliert alles.
- Es gibt **kein Onboarding** (kein Treffer fuer „tutorial" im ganzen Projekt), waehrend
  gleichzeitig Supply, Elemente, Kerne, Gravur, Items, Abilities, Synergien, Aether,
  Forschung und Charaktere auf den Spieler einprasseln.

**Teilweise adressiert:** Der neue Fahrplan (Taste `F` oder HUD-Button) zeigt die
naechsten zwoelf Wellen mit ihren Ereignissen. Das gibt dem Run zumindest eine sichtbare
Struktur — „in Welle 10 kommt der Boss, davor noch ein Perk" — statt einer Kette von
Ueberraschungen. Ein echtes Ziel und ein Run-Save fehlen weiterhin.

## 6. Der Rhythmus ist zerhackt ⏳

Die Kadenzen lagen so uebereinander, dass nach fast jeder Welle ein Modal aufging:

| Welle | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| frueher | Pfad | Perk | Ability | Kern+Schmiede+Boss | Perk+Pfad | Ability | Pfad | Perk | alles |
| jetzt | – | Perk | Ability | Kern+Schmiede+Boss | Perk | Ability | – | Perk | alles |

Die `return`-Kette in `_on_wave_completed` existiert ausschliesslich, damit sich die
Panels nicht gegenseitig verschlucken — ein Symptom, kein Design.

Dazu sind die Wellen selbst formelhaft: `total = 8 + wave * 3`, ein Dominanttyp mit
70 %, ein bis zwei Nebentypen, Element rotiert deterministisch. Keine designten
Spitzen, keine Verschnaufpausen, keine Ereigniswellen.

**Erledigt:** Die Pfad-Unterbrechung faellt weg, und alle Kadenzen liegen jetzt an
*einer* Stelle (`autoload/run_schedule.gd`) statt verteilt ueber `main.gd`,
`game_state.gd`, `ability_system.gd` und `ui/hud.gd`. Damit ist Umtakten kuenftig eine
Aenderung an einer Datei. **Offen:** die Belohnungen buendeln und Wellen mit Absicht
kurvenfoermig gestalten.

## 7. Polish-Signale ✅

- **155 `print()`-Aufrufe**, davon 42 allein in `tower.gd` inklusive
  `"!!! RESOURCELOADER EXISTS!!!"` und einem zwoelfzeiligen `VISIBILITY CHECKS`-Block.
  Jetzt unter 80 und ohne Frame-Spam (Fallen loggten pro Ausloesung).
- **21 fehlende Item-Icon-Varianten** in 8 Templates: Slots blieben leer. Jetzt faellt
  das Icon auf das Kategorie-Sammelicon in Raritaetsfarbe zurueck.
- **6 registrierte, nicht existierende UI-Icons** (`warning`, `core_fire/ice/lightning/
  earth/nature`): `bb()` lieferte woertlich `[?]` in den Text. Jetzt Fallback-Tabelle.

---

## Prioritaeten fuer die naechsten Sitzungen

Sortiert nach Wirkung pro Aufwand:

1. **Musik-Tracks besorgen** (`assets/music/README.md`). Das System steht; fuenf Loops
   veraendern die Wahrnehmung des Spiels mehr als jedes weitere Feature.
2. **Gegner-Sprites pro Typ** (`ASSETS_TODO.md`). Sieben Typen, die man auf einen Blick
   unterscheidet, machen aus einer Zahlenwelle einen Gegner.
3. **Turm-Sprites** fuer Zauberer, Kanone, Falle, Aura.
4. **Ein Run-Ziel.** Zum Beispiel Welle 20 als „Kapitel geschafft" mit eigenem
   Abschlussbild, danach optionaler Endlosmodus. Erst damit gibt es Gewinnen.
5. **Onboarding fuer die ersten drei Wellen.** Nicht mehr als eine gefuehrte
   Turmplatzierung, ein Upgrade und ein erklaerter Element-Kern.
6. **Run unterbrechen und fortsetzen.** Die `get_save_data()`-Funktionen existieren
   bereits, es fehlt nur der Aufrufer.
7. **Wellen mit Absicht designen** statt sie zu wuerfeln: Elitegegner, Ereigniswellen,
   ruhige Wellen als Verschnaufpause.
8. **Belohnungspanels buendeln**, damit nicht nach jeder zweiten Welle ein Modal
   aufgeht.
