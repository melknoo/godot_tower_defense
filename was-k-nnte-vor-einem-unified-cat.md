# Was fehlt noch vor einem ersten Demo-Release?

## Kontext

Der Nutzer möchte wissen, was vor einem ersten Demo-Release des Godot-Tower-Defense-Spiels noch zu tun ist. Es handelt sich um einen Statusbericht/Checkliste, keinen konkreten Implementierungsauftrag. Drei Explore-Agents haben Gameplay-Systeme, UI/UX und Release-Meta (Docs, Export, Assets/Lizenzen) untersucht.

**Gesamtbild:** Der Gameplay-Kern ist bemerkenswert vollständig und poliert für eine Vor-Demo-Version (16 Towers, 7 Enemy-Typen, prozedurale Waves, Economy, Meta-Progression). Die offenen Punkte liegen fast ausschließlich bei Politur, Branding, Assets und Packaging – nicht bei fehlender Kernmechanik.

## 🔴 Blocker (vor Demo unbedingt klären/fixen)

1. **Fehlende SFX-Dateien** — `autoload/sound_manager.gd` referenziert `hit.wav`, `enemy_death.wav`, `impact.wav`, `error.wav`, die es unter diesen Namen nicht gibt (nur `impact_sound.wav`, `game_over.wav` vorhanden). Fällt still aus (`ResourceLoader.exists`-Guard) — Kämpfe haben aktuell keinen Hit-/Death-Sound. `game_over.wav` existiert, wird aber nirgends abgespielt.
2. **Keine Musik im Spiel** — kein Music-Bus, keine `.ogg`/`.mp3`-Streams, nur kurze SFX-Wavs. Für eine Demo wirkt das Fehlen von Musik besonders auffällig.
3. **Ice Wall Fähigkeit ist Platzhalter** — `trap.gd:65` „Platzhalter: Kleines Polygon" — die Wand-Entity ist laut PROGRESS.md explizit unfertig.
4. **Generischer Projektname & Standard-Icon** — `project.godot`: `config/name = "tower defense"`, `config/icon` ist das Godot-Standard-Robotericon. Braucht echten Titel + eigenes Icon vor jedem öffentlichen Build.
5. **Fehlende Charakter-Portraits** — Roster fällt still auf Element-Icons zurück, da `char_*`-Assets fehlen.
6. **Keine Lizenz-/Credits-Dokumentation für Assets** — 801 PNGs/16 WAVs ohne erkennbares LICENSE/README unter `assets/`. Falls Asset-Packs (itch.io/Asset-Store) verwendet wurden, ist das ein rechtliches Risiko für einen öffentlichen Release und sollte vor Veröffentlichung geprüft werden.
7. **Zwei Godot-Temp-Dateien sind eingecheckt** — `main.tscn5833495830.tmp`, `main.tscn6702343067.tmp` liegen im Git-Tracking; `.gitignore` schließt `*.tmp` nicht aus.
8. **Diskrepanz PROGRESS.md vs. Git-Status** — PROGRESS.md (heutiges Datum) behauptet, es gäbe uncommittete lokale Änderungen (Range-Grid, Supply, Tower-Level, Item-Toasts, Cursor, VFX, Balancing), die noch gepusht werden müssten — `git status` zeigt aber einen sauberen Baum. Sollte verifiziert werden, damit ein frischer Klon wirklich den aktuellen Stand hat.

## 🟡 Wichtig (sollte vor Demo erledigt sein)

9. **Export-Presets nicht release-tauglich** — Windows/Linux-Presets zeigen auf private `Downloads`/`Documents`-Pfade des Entwicklers; Windows-Metadaten (Produktname, Firma, Copyright, Version, Exe-Icon) sind leer. Muss vor einem echten Build gefüllt werden.
10. **Kein Web/HTML5-Export-Preset** — falls eine Browser-Demo (z.B. itch.io) gewünscht ist, fehlt das komplett.
11. **Economy/Aether-Werte explizit ungetuned** — laut PROGRESS.md sind Aether-Kosten, Unlock-Ziele und Affinitäts-Gewichte nur grobe "Arbeitswerte", noch nicht balanciert.
12. **Kein Sieg-/Victory-Zustand** — nur endloser Wellenmodus mit Game-Over bei 0 Leben, kein "Win"-Screen. Vermutlich Design-Absicht (Roguelite/Endless), sollte aber bewusst als Rahmen für die Demo kommuniziert werden (z.B. "Überlebe so lange wie möglich" statt ein erwartetes Spielziel zu suggerieren).

## 🟢 Politur (nice-to-have, kein Blocker)

13. Kein Gamepad-Support, keine InputMap — alle Tasten sind hart codiert (`main.gd`, `pause_menu.gd`), keine Neubelegung möglich.
14. Nur Vollbild-Toggle, kein Auflösungs-Dropdown in den Optionen.
15. Tower-Targeting ist fest auf „am weitesten auf dem Pfad" — keine wählbaren Modi (nächstes/stärkstes Ziel etc.).
16. Kleiner kosmetischer Platzhalter: `main_menu.gd:59` Vignette-Farbe als Platzhalter für Shader/Textur.

## Empfehlung für nächste Schritte

Vorschlag für die Reihenfolge, falls gewünscht:
1. SFX-Dateien reparieren (schnell, hoher Wirkungsgrad) + Diskrepanz PROGRESS.md/Git klären.
2. Branding (Name, Icon) + Export-Preset-Metadaten für einen sauberen ersten Build.
3. Asset-Lizenzsituation prüfen, bevor irgendetwas öffentlich geteilt wird.
4. Ice-Wall-Platzhalter fertigstellen oder Trap-Fähigkeit für die Demo deaktivieren.
5. Musik ergänzen (kann auch minimal/Platzhalter-Loop für die Demo sein).

Punkte 13–16 sind für eine erste Demo verzichtbar.

## Verifikation

- Nach SFX-Fix: Spiel über die `run`-Skill starten, mehrere Kämpfe auslösen, Hit-/Death-Sounds hörbar prüfen.
- Nach Branding-Änderungen: Export-Build (Windows) erzeugen und Icon/Produktname im Explorer/Taskleiste prüfen.
- Git-Status/PROGRESS.md-Diskrepanz: `git status`, `git log -5`, und PROGRESS.md-Datum/Inhalt gegenüberstellen, ggf. PROGRESS.md aktualisieren oder fehlende Commits nachholen.
