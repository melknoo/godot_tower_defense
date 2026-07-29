# Handoff: Arcane Bastion — UI-Designsystem (Godot 4)

## Overview
Ein zusammenhängendes visuelles Designsystem für ein 2D-Top-Down-Tower-Defense-Spiel
in Godot 4 mit elementbasierten Türmen (Feuer, Wasser, Erde, Luft, Eis, Lava, Natur,
Dampf). Das Spiel ist funktional weit, aber die UI ist über Monate organisch gewachsen:
jedes Panel hat eigene Farben, Abstände, Schriftgrößen und Rahmenstile. Dieses Paket
liefert Tokens, Komponenten-Spezifikationen, HUD-Layout und eine Umsetzungsreihenfolge,
damit die UI in eine gemeinsame Sprache überführt werden kann.

**Ziel-Stack:** reines GDScript + Godot \`Theme\`/\`StyleBoxFlat\`. Keine externen
Assets außer zwei freien Pixel-Fonts. Bestehende Sprites und Tiles bleiben unverändert —
das System rahmt sie ein, es ersetzt sie nicht.

## About the Design Files
Die Datei \`Arcane Bastion - UI Designsystem.dc.html\` in diesem Bundle ist eine
**Design-Referenz, erstellt in HTML** — ein Prototyp, der Aussehen und Absicht zeigt,
kein Produktionscode zum Kopieren. HTML war nur das Medium, um Farben, Abstände und
Komponenten maßstäblich darstellen zu können.

Die Aufgabe ist, dieses Design in der **bestehenden Godot-4-Codebasis** umzusetzen:
GDScript, Godot-\`Control\`-Nodes, \`Theme\`-Resources und \`StyleBoxFlat\`. Kein
HTML/CSS wird ausgeliefert. Die mitgelieferte \`ui_theme.gd\` ist der einzige Teil des
Bundles, der **direkt** in das Projekt gehört.

Achtung bei der Übertragung: Im HTML stehen Farben als CSS-Hex mit \`#\` (\`#141A24\`),
Godot erwartet \`Color("141A24")\` ohne \`#\`. \`ui_theme.gd\` ist bereits korrekt —
im Zweifel gilt immer \`ui_theme.gd\`, nicht das HTML.

## Fidelity
**High-fidelity.** Alle Farben, Schriftgrößen, Abstände, Rahmenbreiten und
Komponentenmaße sind final und in \`ui_theme.gd\` als Konstanten hinterlegt. Die
Kontraste sind gegen \`BG_1 #141A24\` geprüft (Primärtext 13.4:1, Sekundärtext 6.8:1,
Akzent 8.9:1, jede Elementfarbe ≥ 5.5:1) — Werte bitte nicht ohne Grund verändern.

Die beiden Screen-Mockups (HUD, Turm-Info) sind **hifi in Bezug auf Stil, Tokens und
Hierarchie**, aber schematisch in Bezug auf Inhalt: Turmnamen, Preise und Stats darin
sind Beispieldaten und kommen zur Laufzeit aus dem Spielcode.

---

## Art Direction

> **Kalter Obsidianstein mit Messingbeschlag als neutrale Fassung — alle Farbe gehört
> den acht Elementen.**

Referenz-Vibes: arkanes Observatorium (dunkler Stein, Messinginstrumente, Kristalle in
Halterungen — die UI ist ein Apparat, kein Buch) · emailliertes Metallschild (harte
2-px-Kanten, flache Farbflächen, kein Gradient, kein Blur) · Elementglas auf Schiefer
(im Geiste von *Into the Breach* für Klarheit, *Slay the Spire* für Farbcodierung,
*Hades*-Menüs für Gold als Prestige statt Chrom).

**Bewusster Bruch mit dem Ist-Zustand:** Das bisherige Fantasy-Pergament/Sepia
(#1F1A14 Panels, ausgefranste Ränder, Bandtitel-Sprites) wird vollständig ersetzt.
Grund: es kollidierte mit den reinen \`#000000\`-Panels und den türkisen Buttons, und
warme beige Flächen machen die acht Elementfarben unlesbar. Der stärkste bestehende
Moment — goldener Titel auf Fast-Schwarz im Hauptmenü — wird zur Basis des ganzen
Systems.

### Die drei Regeln
1. **Ein Material.** Jedes Panel im Spiel ist derselbe dunkle Stein mit 2 px
   Messingrahmen. Kein Pergament, kein Türkis, keine ausgefransten Kanten, keine
   Bandtitel-Sprites.
2. **Gold ist knapp.** Messing markiert nur: Fokus/Hover, Währung, Legendary, den einen
   Panel-Rahmen. Nie Flächenfüllung ohne Grund. Wird Gold Standard-Chrom, ist es keine
   Auszeichnung mehr.
3. **Farbe = Bedeutung.** Ein Farbton darf nur auftreten, wenn er Element, Rarity oder
   Status (Erfolg/Warnung/Gefahr) bedeutet. Dekorfarbe existiert nicht.

---

## Design Tokens

Vollständig und kommentiert in \`ui_theme.gd\`. Übersicht:

### Hintergrund-Ebenen
| Token | Hex | Einsatz |
|---|---|---|
| \`BG_0\` | \`0A0D13\` | Screen-Backdrop, Menühintergrund |
| \`BG_1\` | \`141A24\` | Panel-/Overlay-Grundfläche — der Standard |
| \`BG_2\` | \`1E2632\` | Sektion, Listenzeile, Panel-Header, Button-Fläche |
| \`BG_3\` | \`2A3442\` | Vertiefung: Item-Slot, Balken-Track, Eingabefeld |
| \`SCRIM\` | \`060810\` @ 72 % | unter jedem **modalen** Overlay (nicht bei Turm-Info) |

### Rahmen
| Token | Hex | Einsatz |
|---|---|---|
| \`BORDER_BRASS\` | \`C79A3C\` | Panel-Außenrahmen |
| \`BORDER_SOFT\` | \`3A4658\` | Karten, Slots, Trennlinien |
| \`BORDER_SHADE\` | \`0A0D13\` | 1 px innen = Tiefe ohne Blur |
| \`BORDER_FOCUS\` | \`E0B44E\` | Hover / Fokus / Selektion |
| \`BRASS_INNER\` | \`6B5522\` | 1 px Innenlinie im Messingprofil |

Panel-Kantenprofil (der „Messingbeschlag“, ein StyleBox für alles):
2 px \`C79A3C\` außen, 1 px \`6B5522\` innen, Fläche \`141A24\`.

### Text & Status
| Token | Hex |
|---|---|
| \`TEXT_PRIMARY\` | \`EDE6D6\` |
| \`TEXT_SECOND\` | \`9EAAB9\` |
| \`TEXT_DISABLED\` | \`5A6675\` |
| \`TEXT_ON_ACCENT\` | \`10141B\` |
| \`ACCENT\` / hover / pressed | \`E0B44E\` / \`F2CB6E\` / \`B98E33\` |
| \`SUCCESS\` | \`5FBF7A\` |
| \`WARNING\` | \`E8963C\` |
| \`DANGER\` | \`E0524B\` |

### Elementfarben (8)
Als Set konstruiert bei gleicher Helligkeit/Sättigung (oklch L≈0.74, C≈0.15), nur der
Hue variiert — dadurch harmonisch und alle gleich stark auf dunklem Grund.

| Element | Hex | Anmerkung |
|---|---|---|
| Feuer | \`FF7A45\` | |
| Wasser | \`3E9BE8\` | |
| Erde | \`B5854F\` | absichtlich entsättigt, damit kein Konflikt mit Messing |
| Luft | \`B9B6EE\` | |
| Eis | \`79E1E6\` | |
| Lava | \`E24545\` | |
| Natur | \`67CC63\` | |
| Dampf | \`9BB6C2\` | absichtlich entsättigt, damit kein Konflikt mit Eis |
| (neutral) | \`9EAAB9\` | Fallback für Türme ohne Element |

**Anwendungsregel:** Elementfarbe erscheint als **Textfarbe, 3-px-Kantenstreifen links
und 18 %-Flächenfüllung** — nie als volle Panelfläche.

**Kollisionsschutz:** Lava (\`E24545\`) und Danger (\`E0524B\`) liegen nah beieinander,
treffen sich aber nie: Danger erscheint nie als Elementchip, Lava nie als Buttonfläche.
Erde (\`B5854F\`) ist 0.12 L dunkler und 30° röter als Messing und trägt zusätzlich
immer ihr Sprite-Icon.

### Rarity
Aus dem Elementset abgeleitet, damit nichts fremd wirkt. Violett ist der einzige Hue,
den kein Element belegt; Legendary ist das Messing selbst.

| Stufe | Hex |
|---|---|
| Common | \`9EAAB9\` |
| Uncommon | \`67CC63\` |
| Rare | \`3E9BE8\` |
| Epic | \`B36BE8\` |
| Legendary | \`E0B44E\` |

Rarity zeigt sich als **Slot-Rahmenfarbe (2 px) + Namensfarbe im Tooltip**. Legendary
zusätzlich: 1-px-Innenlinie \`6B5522\`. Kein Partikel, kein Pulsieren.

### Typo-Skala (px @ 1920×1080)
Fonts (beide frei, keine Lizenzfragen):
- **Pixel Operator** + **Pixel Operator Bold** — CC0, native 16 px, für allen Text.
  https://www.dafont.com/pixel-operator.font
- **Silkscreen** — OFL, native 8 px, für Displaytitel (Alternative: **m6x11**, ebenfalls frei).
  https://fonts.google.com/specimen/Silkscreen

Nur ganzzahlige Vielfache der Nativgröße verwenden, sonst matscht das Raster.

| Stufe | Größe / Line-Height | Einsatz |
|---|---|---|
| DISPLAY | 48 / 1.1 | Spieltitel, Sieg/Niederlage |
| TITLE | 32 / 1.2 | Panel-Header (genau 1× pro Panel) |
| SECTION | 24 / 1.3 | Sektionstitel, Buttonlabel, hervorgehobene Werte |
| BODY | 20 / 1.45 | Stats, Beschreibungen, Listen |
| MICRO | 16 / 1.4 | Labels, Hotkeys, Fußnoten |

Regeln: nur MICRO und SECTION dürfen ALL CAPS + \`letter_spacing 2\`. BODY nie
gesperrt und nie zentriert — immer linksbündig, Werte rechtsbündig. Untergrenze 16 px.

### Spacing · 4er-Raster
\`SP_1 4\` · \`SP_2 8\` · \`SP_3 12\` · \`SP_4 16\` · \`SP_5 24\` ·
\`SP_6 32\` · \`SP_7 48\`

Kein Wert außerhalb der Skala. **Panel-Padding ist immer \`SP_5\` = 24** — das allein
räumt Inventar, Turm-Info und Fahrplan auf eine Linie.

### Kanten, Tiefe, Glow
- **Border-Radius: 0 px. Überall, ohne Ausnahme.** Pixel-Art und abgerundete Ecken
  schließen sich aus; Rundungen sind der Hauptgrund für den „billig“-Eindruck.
- **Border-Breiten:** 2 px Panel/Button/Karte · 1 px Trennlinie und Innenschattenlinie ·
  3 px Elementkante links · 4 px Fokusrahmen bei Selektion.
- **Schatten:** nur hart, nie weich. \`shadow_size = 0\`,
  \`shadow_color = Color("06081080")\`, \`shadow_offset = Vector2(4, 4)\`.
- **Glow:** kein Blur-Glow in der UI. „Leuchten“ = 2-px-Rahmen in Element-/Akzentfarbe
  + 18 %-Flächenfüllung. Echter Bloom bleibt dem \`WorldEnvironment\` für Projektile.

### Skalierung
\`content_scale_mode = canvas_items\`, \`content_scale_aspect = keep\`,
Basisauflösung 1920×1080. Bei 1280×720 greift Faktor 0.667 — deshalb Untergrenze
16 px Schrift und 44 px Trefferfläche. Font-Mipmaps aus, Antialiasing aus,
Subpixel-Positionierung aus.

---

## Components

Alle Maße gelten @1920×1080. Die zugehörigen StyleBox-Factories stehen in
\`ui_theme.gd\`.

### Panel / Overlay
- **Aufbau:** Header-Leiste → Content → optionale Footer-Leiste.
- **Header:** BG_2, Höhe 56, Padding 24 horizontal / 16 vertikal, 1 px \`6B5522\`
  unten. TITLE (32) links, MICRO-Kontext rechts.
- **Content:** Padding 24, Gaps 16.
- **Footer:** Buttons rechtsbündig.
- **Tokens:** BG_1 Fläche, 2 px BORDER_BRASS, harter Schatten 4/4, Radius 0.
- **Breiten (fix, nicht ad hoc):** S 480 · M 720 · L 1040 · XL 1440. Höhe max 78 % der
  Viewporthöhe, dann scrollen.
- **Modal** zusätzlich SCRIM darunter; nicht-modale Panels (Turm-Info) ohne Scrim.
- **Zebra-Fix:** Zeilenhinterlegung ist BG_2 — **heller** als das Panel, niemals dunkler
  als der eigene Text. Ausgewählte Zeile: BG_2 + 3 px Elementkante links.
- **Scrollbar:** 8 px breit, Track BG_1, Griff BORDER_SOFT, Hover ACCENT, Radius 0.
- **Einblendung:** 80 ms Opazität, keine Skalierung.

### Buttons
Geometrie: Höhe 56 (Icon-Button 56×56), Padding 24 horizontal / 12 vertikal, Label
SECTION 24 ALL CAPS, \`letter_spacing 1\`. Mindest-Trefferfläche 44 px auch bei 1280.

**Hierarchie-Regel:** *Ein* Primär-Button pro Panel — der mit Messingrahmen. Alles
andere ist Sekundär (nur Umriss). Destruktives (Beenden, Verkaufen) ist Danger-Umriss,
nie gefüllt im Ruhezustand.

| | Normal | Hover | Pressed | Disabled |
|---|---|---|---|---|
| **Primär** | Fläche BG_2, 2 px \`C79A3C\`, Text \`EDE6D6\` | Rahmen+Text \`F2CB6E\` | Fläche \`B98E33\`, Text \`10141B\` | Fläche BG_1, Rahmen \`3A4658\`, Text \`5A6675\` |
| **Sekundär** | transparent, 2 px \`3A4658\`, Text \`9EAAB9\` | Rahmen \`E0B44E\`, Text \`EDE6D6\` | Fläche BG_2, Rahmen \`E0B44E\` | 2 px \`2A3442\` gestrichelt, Text \`5A6675\` |
| **Danger** | Fläche BG_2, 2 px \`E0524B\`, Text \`E0524B\` | Fläche \`3A1F1F\`, Text \`EDE6D6\` | Fläche \`E0524B\`, Text \`10141B\` | Fläche BG_1, Rahmen \`3A4658\`, Text \`5A6675\` |
| **Icon** 56² | Fläche BG_2, 2 px \`3A4658\` | Rahmen+Glyph \`E0B44E\` | Fläche \`E0B44E\`, Glyph \`10141B\` | Fläche BG_1, Rahmen \`2A3442\` |

- **Pressed** verschiebt den Text 2 px nach unten statt einen Schatten zu animieren —
  billiger und pixelgenau.
- **Icon & Label liegen nie übereinander:** HBox mit \`h_separation = 8\`, Icon 24×24
  links, Label im Rest. (Behebt den bestehenden „FORT⬤SETZEN“-Bug im Pause-Menü.)

### Karte: Turmkarte (Shop)
- 160×200, Padding 16, Fläche BG_2, 2 px BORDER_SOFT, **3 px Elementkante links**.
- Aufbau: Kopfzeile (Name SECTION links / Preis ACCENT rechts, Gap 6,
  \`white-space: nowrap\`) → Sprite-Feld 64×64 auf BG_3 mit 1 px BORDER_SHADE →
  Chip-Reihe (Element-Chip in Elementfarbe mit 18 % Füllung, weitere Tags in
  BORDER_SOFT-Umriss).
- **Zustände:** Hover = Rahmen ACCENT + Karte 2 px nach oben. Ausgewählt = 4 px ACCENT
  + Elementfüllung 18 %. **Nicht bezahlbar = Preis in DANGER, Karte 55 % Deckkraft,
  kein Hover.**

### Karte: Charakterkarte
- 320×300, Padding 24, Fläche BG_2, 2 px BORDER_SOFT.
- Aufbau: Avatar 40×40 mit 2 px Elementrahmen + Elementfüllung 18 %, daneben Name
  (SECTION) und Elementlabel (MICRO, Elementfarbe) → 1 px Trenner → Label/Wert-Paare
  („FÄHIGKEIT“, „PASSIV“) mit MICRO-Label in TEXT_SECOND und BODY-Wert linksbündig.
- **Ausgewählt:** 2 px ACCENT-Rahmen.
- **Gesperrt:** dasselbe Panel-Material, Inhalt in TEXT_DISABLED, Rahmen BORDER_SOFT
  gestrichelt — **nie** eine graue Fläche in fremdem Stil.
- Beschreibungstext linksbündig, nie zentriert.

### Karte: Item-Slot
- 64×64, Gap 8 im Grid, Fläche BG_3, **Rahmen 2 px = Rarity-Farbe**.
- Leer = BORDER_SOFT. Ausgewählt = 4 px ACCENT. Nicht ausrüstbar = 40 % Deckkraft,
  kein Rahmen.
- Menge unten rechts in MICRO. Cooldown-Overlay als vertikal aufsteigende
  BG_0-Maske @ 60 %.
- Legendary zusätzlich 1 px Innenlinie \`6B5522\`.

### Fortschrittsbalken (HP / Wave / Cooldown / XP)
- **Aufbau:** Label-Zeile (MICRO, links Name / rechts Wert) über dem Balken.
- **Track:** BG_3 mit 1 px BORDER_SHADE. **Füllung:** flach, ohne Gradient, Radius 0,
  kein eigener Rahmen.
- **Höhen:** HP 12 · Wave 12 · Cooldown 8 · XP/Aether 8.
- **Farben:** HP SUCCESS → unter 50 % WARNING → unter 25 % DANGER (harter Wechsel, kein
  Verlauf; \`UI.hp_color(ratio)\`). Wave ACCENT. Cooldown = Elementfarbe der Ability.
- Schaden-Vorschau als DANGER @ 40 % hinter der HP-Füllung.

### Tooltip
- Max. 420 breit, Padding 16, Panel-Material mit Messingrahmen und hartem Schatten.
- **Header:** Name in **Rarity-Farbe**, Rarity-Label rechts in MICRO/TEXT_SECOND, 1 px
  Trenner darunter.
- **Body:** Label/Wert-Paare, Werte **immer rechtsbündig**, Vorzeichen farbig
  (SUCCESS für Plus, DANGER für Minus).
- **Fuß:** Synergiehinweis in Elementfarbe.
- **Verhalten:** 120 ms Verzögerung, keine Animation, 12 px Cursorabstand, klemmt an den
  Bildschirmrand.

### Ressourcen-Anzeige (Pod)
- Eine einzige Zeile in einem Panel: Icons alle 16×16 auf gemeinsamer Baseline, Zahlen
  BODY tabellarisch, 1-px-Trenner zwischen den Posten, Padding 8/12.
- Sekundärteil eines Werts (z. B. \`/20\`) in TEXT_DISABLED.
- **Änderung:** 200 ms Aufblitzen der Zahl in ACCENT (Gewinn) bzw. DANGER (Verlust).
- **Niemals** Ressourcentext ohne Panel direkt auf dem Spielfeld — der schwerste
  Lesbarkeitsfehler im Ist-Zustand (hellgelber Text auf hellgrünen Gras-Tiles).

---

## Screens / Views

### 1. In-Game-HUD (Priorität 1 — größter Effekt)
**Purpose:** Türme kaufen und platzieren, Wellen starten, Abilities zünden, dabei das
Spielfeld im Blick behalten.

**Layout — Prinzip „zwei Anker, keine Ecken“:** Alles Dauerhafte sitzt in einer
64-px-Topbar und einer 168-px-Bottombar; die Mitte gehört dem Spielfeld. Nichts
schwebt frei im Feld, nichts liegt in der linken oder rechten Ecke.

\`\`\`
1920 × 1080 · Safe-Margin 48 · Topbar 64 · Bottombar 168

┌──────────────────────────────────────────────────────────────────────────────┐
│ ♥ 14/20 ▰▰▰▰▰▱▱  │ WELLE 3/12 ▰▰▱▱▱▱ 8 GEGNER │ ⛃ 210        [U] [≡] [⏸] │ 64
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                        S P I E L F E L D   ·   f r e i                       │
│                                                                              │
│              (Turm-Info-Panel erscheint kontextuell rechts,                  │
│               440 breit, rechts angedockt, kein Scrim)                       │
│                                                                              │
├───────────────────────┬──────────────────────────────┬───────────────────────┤
│ FÄHIGKEITEN           │ TÜRME                        │ WELLENSTEUERUNG       │
│ ┌───┐┌───┐┌───┐┌───┐  │ ┌────┐┌────┐┌────┐┌────┐┌──┐ │ ELEMENT   NEUTRAL     │ 168
│ │ 1 ││ 2 ││ 3 ││ 4 │  │ │ 45 ││ 75 ││ 65 ││ 80 ││…│ │ TIPP      —           │
│ └───┘└───┘└───┘└───┘  │ └────┘└────┘└────┘└────┘└──┘ │ ┌───────────────────┐ │
│ Cooldown je Slot      │ ◂ scroll ▸  Elementkante     │ │ NÄCHSTE WELLE ⏎   │ │
└───────────────────────┴──────────────────────────────┴───────────────────────┘
  320 fix                 flexibel (zentriert)            440 fix
\`\`\`

**Informationshierarchie:**
- **Sofort lesbar:** Bastion-HP, aktuelle Welle + Fortschritt, Gold. Nie kleiner als
  BODY 20, nie hinter einem Overlay.
- **Auf Abruf:** Shop, Abilities, Nächste-Welle-Steuerung, Turm-Tipp. Immer sichtbar,
  aber in BG_2 mit Sekundärtext — sie warten, statt zu rufen.
- **Zurücktreten:** Aether/Meta-Level, Kerne, Archiv, aktive Upgrades. Als Icon-Reihe
  mit Hotkey, Details nur im Overlay. Kein Dauerplatz für Meta-Progression im Kampf-HUD.

**Components:**
- **Topbar** (Höhe 64, Panel-Material): drei Gruppen mit 1-px-Trennern —
  links HP (12×12 SUCCESS-Punkt + \`14/20\` mit \`/20\` in TEXT_DISABLED + 64×8-Balken),
  Mitte Welle (MICRO-Label „WELLE“ + \`3/12\` + 96×8-ACCENT-Balken + „8 GEGNER“),
  danach Gold (16×16-Icon + Zahl). Rechts außen drei 56×56-Icon-Buttons:
  [U] Upgrades/Meta, [A] Archiv, [II] Pause.
- **Bottombar** (Höhe 168, **ein** Panel mit drei Spalten statt drei separaten Leisten):
  - *Fähigkeiten* (320 fix): MICRO-Sektionslabel, darunter 4 Slots à 56×56 mit 2 px
    Rahmen in Ability-Elementfarbe, darunter je ein 4-px-Cooldown-Balken in derselben
    Farbe. Leerer Slot = BG_1 + 2 px \`2A3442\`.
  - *Türme* (flexibel, zentriert): horizontal scrollende Reihe Turmkarten mit
    Pfeil-Buttons links/rechts (16 breit, BG_2, 1 px BORDER_SOFT).
  - *Wellensteuerung* (440 fix): zwei Label/Wert-Zeilen (ELEMENT, TIPP) plus der
    **einzige Messing-Button im HUD**: „NÄCHSTE WELLE“.

**Was sich gegenüber dem Ist-Zustand ändert:** freistehender Text auf Gras → ein Panel;
drei Bottom-Leisten → eine mit drei Spalten; Shop-Karten bekommen Rahmen, Elementkante
und ein sichtbares „zu teuer“; Cooldowns existieren überhaupt erst; nur die Hauptaktion
ist Messing; Meta-Anzeigen wandern hinter [U]/[A]; der leere Aether-Streifen oben
verschwindet.

**Responsive (1280×720):** Topbar 64 und Bottombar 168 bleiben in Designpixeln
(\`canvas_items\` skaliert 0.667 → real 43/112 px). Turm-Info-Panel schrumpft auf 360,
die Turmreihe scrollt statt umzubrechen.

### 2. Turm-Info + Ausrüstung (Priorität 1 — dichtester Screen, härtester Stilbruch)
**Purpose:** Angeklickten Turm bewerten, aufwerten, ausrüsten oder verkaufen.

**Layout:** Panel 400 breit (bei 1280 → 360), **rechts an den Spielfeldrand angedockt**,
kein Scrim (das Spielfeld bleibt sichtbar und bespielbar). Höhe max
\`1080 − 64 − 168 − 96\` — überlappt die Bottombar nie.

**Components (von oben):**
1. **Header** (BG_2, Padding 16, 1 px \`6B5522\` unten, **3 px Elementkante links**):
   Name TITLE links, darunter MICRO-Zeile „FEUER · NAHKAMPF“ in Elementfarbe. Rechts
   Level als MICRO \`LV 2/6\` plus **Pip-Reihe** (6 Segmente à 10×5, gefüllt ACCENT,
   leer BG_3) statt einer Textzeile.
2. **Stat-Block:** Label/Wert-Paare mit 1-px-Trennern (\`232C38\`) zwischen den Zeilen.
   Label MICRO in TEXT_SECOND links, Wert BODY in TEXT_PRIMARY **rechtsbündig** —
   das erzeugt die Lesekante, die im Ist-Zustand fehlt. Deltas in SUCCESS (\`+2\`),
   Nebenwerte in TEXT_DISABLED (\`×1.5\`). Dichte bleibt erhalten, die Unruhe verschwindet.
3. **Ausrüstung:** MICRO-Sektionslabel, darunter Item-Slots 44×44 mit Rarity-Rahmen;
   leerer Slot mit \`+\` in TEXT_DISABLED.
4. **Synergie-Hinweis:** BG_2-Streifen mit 3 px Elementkante links, Text MICRO in
   Elementfarbe („SYNERGIE AKTIV · FEUER + LAVA“).
5. **Aktionen:** *ein* Primär-Button „UPGRADE“ mit Preis rechts in ACCENT, darunter eine
   Reihe mit Sekundär „AUFNEHMEN“ und Danger-Umriss „VERKAUFEN 100“.
   **„Schließen“ entfällt** — ESC oder Klick ins Leere schließt.

**Was sich ändert:** reines Schwarz → Panel-Material mit Rahmen; Elementidentität wird
sichtbar; 7 gleich große Statzeilen → gewichtete Label/Wert-Paare mit rechter Lesekante;
4 gleich schwere gestapelte Buttons → klarer Rang; das benachbarte Pergament-Inventar
verschwindet, weil es dasselbe Material bekommt.

### Weitere Screens (gleiche Regeln, keine Sonderfälle)
- **Hauptmenü:** bereits der stärkste Screen. Türkise Bandtitel-Sprites und Mint-Buttons
  entfernen, Titel in DISPLAY/ACCENT behalten, Atmosphäre über Elementpartikel im
  Hintergrund statt leerer Fläche.
- **Charakterauswahl:** Hierarchie umdrehen — „STARTEN“ ist der Primär-Button,
  „ZURÜCK“ Sekundär (im Ist-Zustand ist „ZURÜCK“ rot umrandet und „STARTEN“ wirkt
  deaktiviert). Sechs beliebige Titelfarben → Elementfarbe des Charakters.
  Karten nach „Charakterkarte“-Spec. Beschreibung linksbündig.
- **Tower-Shop:** siehe Turmkarte; Preis nie über dem Sprite.
- **Item-Inventar:** Slot-Grid, Rarity-Rahmen, Panel-Padding 24, Tooltip nach Spec.
- **Wave-Upgrade-Overlay:** modal, SCRIM, Panel L 1040, Auswahlkarten als
  \`element_card\` mit 4-px-ACCENT bei Selektion.
- **Synergien & Fahrplan:** härtester Lesbarkeitsfehler im Ist-Zustand (T1/T2/T3-Zeilen
  in Mittelbraun auf Mittelbeige, ~1.8:1). Zeilen als \`row(striped)\` mit BG_2,
  Elementtitel in Elementfarbe, **Werte rechtsbündig in eigener Spalte**
  (im Ist-Zustand klebt „T0 · 0 PKT → 4“ zusammen).
- **Pause-Menü:** modal mit SCRIM, Icons per HBox **neben** dem Label, Beenden als
  Danger-Umriss.
- **Meta-Progression:** Panel XL, Sektionen als \`section()\`, Rarity/Elementfarben
  konsistent.

---

## Interactions & Behavior
- **Hover:** Rahmenfarbe → ACCENT, sofort (kein Tween). Turmkarten zusätzlich 2 px
  Versatz nach oben.
- **Pressed:** Inhalt 2 px nach unten, Fläche wird ACCENT_PRESS bzw. DANGER.
- **Disabled:** kein Hover-Feedback, Text TEXT_DISABLED, Rahmen BORDER_SOFT.
- **Selektion:** 4 px ACCENT-Rahmen (Panel-Rahmenbreite verdoppelt), zusätzlich
  Elementfüllung 18 % bei elementgebundenen Karten.
- **Tooltip:** 120 ms Delay, keine Ein-/Ausblendanimation, 12 px Cursorabstand,
  Randklemmung.
- **Overlay öffnen:** SCRIM + Panel per 80-ms-Opazitäts-Tween, **keine** Skalierung
  (Skalierung zerstört das Pixelraster).
- **Ressourcenänderung:** 200 ms Farb-Flash der Zahl (ACCENT bei Gewinn, DANGER bei
  Verlust), danach zurück zu TEXT_PRIMARY.
- **HP-Schwellen:** Farbwechsel hart bei 50 % und 25 %, kein Verlauf.
- **Nicht bezahlbar:** Turmkarte 55 % Deckkraft, Preis DANGER, Klick ohne Wirkung,
  kein Hover.
- **Cooldown:** Ability-Slot zeigt aufsteigende Maskenfüllung (BG_0 @ 60 %) plus
  Restzeit in MICRO/Elementfarbe.
- **Schließen:** ESC schließt jedes Overlay; Klick auf den Scrim schließt nicht-kritische
  Overlays. Kein dedizierter „Schließen“-Button im Turm-Info-Panel.

## State Management
Alles UI-seitig Nötige, unabhängig von der bestehenden Spiellogik:
- \`selected_tower\` → steuert Sichtbarkeit und Inhalt des Turm-Info-Panels.
- \`hovered_shop_card\` / \`selected_shop_card\` → Platzierungsmodus.
- \`gold\` → treibt „nicht bezahlbar“-Zustand aller Turmkarten (reaktiv, nicht bei
  Klick prüfen).
- \`bastion_hp\`, \`wave_index\`, \`wave_total\`, \`enemies_remaining\` → Topbar.
- \`ability_cooldowns[4]\` → Cooldown-Balken und Restzeit.
- \`active_overlay\` (enum: NONE, PAUSE, UPGRADES, ARCHIVE, SYNERGIES, ROADMAP,
  WAVE_UPGRADE) → genau ein modales Overlay zur Zeit, steuert SCRIM.
- \`tooltip_target\` + Timer 120 ms.

## Assets
- **Keine neuen Grafik-Assets.** Bestehende Sprites und Tiles bleiben unverändert; das
  System rahmt sie ein. Alle Rahmen, Flächen, Balken und Schatten entstehen aus
  \`StyleBoxFlat\` in GDScript.
- **Zu entfernen:** Pergament-Texturen, ausgefranste Rahmen-Sprites, Bandtitel-Sprites,
  türkise/Mint-StyleBoxen.
- **Fonts (frei, nach \`res://ui/fonts/\`):** Pixel Operator + Pixel Operator Bold
  (CC0) und Silkscreen (OFL) oder m6x11.
- Die Icon-Glyphen in den Mockups (♥, ⛃, ▰) sind **Platzhalter** für die vorhandenen
  Sprite-Icons — nicht als Textzeichen ausliefern. Icons einheitlich 16×16 (HUD) bzw.
  24×24 (Buttons).

## Implementation Order
Jede Phase ist ein abgeschlossener Commit; nach jeder Phase ist das Spiel spielbar und
sichtbar besser. Keine Phase braucht neue Assets.

**Phase 1 — Tokens zentralisieren (~1 Tag, größter Sprung)**
\`ui_theme.gd\` als Autoload \`UI\` anlegen, \`get_tree().root.theme =
UI.build_theme()\` setzen. Pixel Operator einbinden, **alle** Font-, Farb- und
StyleBox-Overrides in einzelnen Szenen löschen, alle \`corner_radius\` auf 0,
Pergament-Texturen und Mint-StyleBoxen entfernen. Layout noch nicht anfassen.
→ *Alles ist dunkel, konsistent und lesbar — mit den alten Positionen.*

**Phase 2 — Kontrast & Hierarchie (~1–2 Tage)**
Typo-Skala durchsetzen (nur 5 Größen). Jedes Panel-Padding auf 24. Button-Rollen
vergeben: genau ein Primär pro Panel, Danger nur als Umriss. Zebra-Zeilen auf BG_2
drehen. Sekundärtext auf \`9EAAB9\`. Button-Icons per HBox neben das Label.
→ *Synergien und Fahrplan sind erstmals vollständig lesbar.*

**Phase 3 — Element- & Rarity-Codierung (~2 Tage)**
\`UI.el()\` überall anschließen: Turmkarten, Turm-Info-Header, Ability-Cooldowns,
Synergiezeilen, Wellen-Element. Item-Slots erhalten Rarity-Rahmen, Tooltip-Header
Rarity-Farbe.
→ *Das Spiel erklärt sich selbst — Farbe trägt Mechanik.*

**Phase 4 — HUD-Umbau (~2–3 Tage)**
Topbar und Bottombar nach Wireframe bauen, freistehende Labels auflösen,
Ressourcen-Pod einsetzen, Turm-Info rechts andocken, Meta-Anzeigen ins [U]-Overlay
verschieben. Danach 1280×720 prüfen.
→ *Freies Spielfeld, ruhige Ränder.*

**Phase 5 — Polish (laufend)**
Scrim + 4-px-Hartschatten für Overlays, 120-ms-Tooltip-Delay, Zahlen-Flash,
Pressed-2-px-Offset, 80-ms-Panel-Einblendung, Hauptmenü-Atmosphäre.
→ *Fühlt sich fertig an.*

**Wenn nur ein Tag Zeit ist:** Phase 1 plus zwei Dinge aus Phase 2 — Panel-Padding auf
24 und genau ein Primär-Button pro Panel.

## Files
| Datei | Rolle |
|---|---|
| \`ui_theme.gd\` | **Direkt ins Projekt** nach \`res://ui/ui_theme.gd\`, als Autoload \`UI\` registrieren. Einzige Quelle der Wahrheit für alle Werte. |
| \`README.md\` | Diese Spezifikation. Self-sufficient — Umsetzung ist ohne das HTML möglich. |
| \`Arcane Bastion - UI Designsystem.dc.html\` | Visuelle Referenz: Farbfelder, Komponenten-Beispiele maßstäblich, Screen-Mockups. Im Browser öffnen. **Nicht** Produktionscode. |

Screenshots der Mockups sind nicht enthalten — auf Wunsch nachlieferbar.
