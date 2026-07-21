# Musik

`autoload/music_manager.gd` sucht die Tracks in diesem Ordner. **Fehlt eine Datei,
passiert nichts** — der Zustandswechsel wird uebersprungen, das Spiel laeuft ohne
Musik weiter. Es ist also keine Codeaenderung noetig, um Musik nachzureichen:
Datei mit dem richtigen Namen hier ablegen, fertig.

## Erwartete Dateien

| Datei | Wann sie laeuft |
| --- | --- |
| `menu.ogg` | Hauptmenue |
| `build.ogg` | Bauphase zwischen den Wellen |
| `wave.ogg` | Waehrend einer laufenden Welle |
| `boss.ogg` | Bosswellen (jede 5. Welle) |
| `game_over.ogg` | Run-Zusammenfassung nach der Niederlage |

`.ogg` ist der Normalfall; `.wav` und `.mp3` werden ebenfalls erkannt (Reihenfolge:
ogg → wav → mp3).

## Anforderungen

- **Nahtlos loopbar.** Der Manager setzt `loop = true` bzw. `LOOP_FORWARD`; ein
  hoerbarer Sprung am Ende faellt bei einem 60-90-Sekunden-Loop schnell auf.
- **Laenge:** ca. 60-90 Sekunden pro Track reicht.
- **Lautstaerke:** eher leise mastern. Der Standardwert des Musik-Reglers liegt bei
  -6 dB, die SFX sind laut.
- **Uebergaenge:** zwischen zwei Zustaenden wird 1,2 s ueberblendet
  (`CROSSFADE_TIME`). Tracks sollten in derselben Tonart/Stimmung liegen, damit der
  Wechsel Bauphase → Welle nicht wie ein Bruch klingt.

## Fehlende Sound-Effekte

Unabhaengig von der Musik fehlen drei Kern-SFX. Sie sind in
`autoload/sound_manager.gd` aktuell mit vorhandenen Dateien ueberbrueckt
(siehe TODO dort) und gehoeren nach `assets/sounds/`:

| Datei | aktuell verwendet |
| --- | --- |
| `hit.wav` | `impact_sound.wav` |
| `enemy_death.wav` | `impact_sound.wav` |
| `error.wav` | `click.wav` |
