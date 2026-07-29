# Phase 3b — Shop-Row (Bottombar) Layout-Konzept

Antwort auf die offene Frage: **Nicht** per Anchor-Tweak flicken. Die Kollision ist kein
Anchor-Problem, sondern ein fehlendes Container-Modell. Der Fix unten ist klein, ist
kein Phase-4-Rebuild, und macht Phase 4 danach einfacher statt schwerer.

## 1. Was auf dem Screenshot wirklich falsch ist

1. **Karten haben keine eigene Box.** Icon, Kostenbadge und Label sind frei platziert,
   deshalb sitzt das Kostenbadge (`45`, `75`, `65`) mitten im Turm-Sprite.
2. **Label sprengt die Karte.** `ZAUBERERFALLE` ist mit der neuen Schrift breiter als die
   Kartenbreite → überschreibt den Nachbarn (`ZAUBEREGFALLE` ist die Überlappung von
   „ZAUBERER" und „FALLE").
3. **Zwei Karten ohne Sprite** (`80`, `60`) — Icon-Node ist da, Textur nicht, oder das
   Icon wird von der Kostenzeile aus dem sichtbaren Bereich geschoben.
4. **Row wird breiter als der verfügbare Platz** → schiebt sich über das Wave-Control-Panel.

Ursache in einem Satz: die Kartenbreite ist aus Textbreite abgeleitet (oder gar nicht
definiert), statt aus einem festen Grid.

## 2. Zielmodell: Karte = feste Box, Text passt sich an

Die Shop-Karte ist ein **fixes Quadrat-Slot**, nie textabhängig.

```
ShopCard (PanelContainer)   custom_minimum_size = (88, 104)   size_flags = SHRINK_CENTER
└── MarginContainer         margin all = SPACE_2 (8)
    └── VBoxContainer       separation = SPACE_1 (4), alignment = center
        ├── CostRow (HBoxContainer)  separation = 2, alignment = center
        │   ├── CostLabel   (CAPTION, tabular, color = TEXT_SECONDARY)
        │   └── CoinIcon    (TextureRect, 12x12, expand_mode = IGNORE_SIZE)
        ├── IconSlot (Control)  custom_minimum_size = (48, 48)
        │   └── TowerIcon   (TextureRect, anchors full rect,
        │                    stretch_mode = KEEP_ASPECT_CENTERED,
        │                    texture_filter = NEAREST)
        └── NameLabel       (LABEL_SMALL)
                            autowrap_mode = OFF
                            clip_text = true
                            text_overrun_behavior = TRIM_ELLIPSIS
                            horizontal_alignment = CENTER
                            custom_minimum_size.x = 0   ← wichtig, sonst wächst die Karte
```

Regeln, die den Bug strukturell unmöglich machen:

- **R1** Die Karte bekommt ihre Breite ausschließlich aus `custom_minimum_size`.
  Kein Kind darf `size_flags_horizontal = EXPAND` haben.
- **R2** `NameLabel` hat immer `clip_text = true` + `TRIM_ELLIPSIS`. Text kann nie
  Layout beeinflussen. Voller Name kommt in den `tooltip_text`.
- **R3** Kostenbadge liegt **über** dem Icon in derselben VBox — nie als Overlay im
  Icon-Rect. Wenn ein Overlay-Badge gewünscht ist (Phase 4), dann als eigener
  `Control` mit `anchor = top_right`, Offset `(-2, 2)`, und das Icon behält seinen Slot.
- **R4** Icons: `texture_filter = NEAREST` (Pixelart), `KEEP_ASPECT_CENTERED`.
  Fehlt eine Textur → Placeholder-Rect in `SURFACE_2`, damit ein leerer Slot sofort
  auffällt statt still zu verschwinden.

## 3. Row und Kollision mit dem Wave-Panel

Die Bottombar wird eine echte 3-Spalten-Struktur, dann ist die Kollision per
Konstruktion weg:

```
BottomBar (HBoxContainer, separation = SPACE_3 (12))
├── ArrowLeft   (fixe 32x64, SHRINK_CENTER)
├── ShopScroll  (ScrollContainer, size_flags_horizontal = EXPAND_FILL,
│                horizontal_scroll_mode = SHOW_NEVER, vertical = DISABLED)
│   └── ShopRow (HBoxContainer, separation = SPACE_2 (8), alignment = center)
│       └── ShopCard × n
├── ArrowRight  (fixe 32x64, SHRINK_CENTER)
└── WavePanel   (custom_minimum_size = (240, 0), SHRINK_END)
```

- Der `ScrollContainer` ist der Puffer: mehr Karten als Platz → die Row wird
  gescrollt/geclippt, statt das Nachbarpanel zu überlagern.
- Die Pfeile bleiben funktional (sie scrollen die Row um eine Kartenbreite + Separation).
- `WavePanel` hat eine feste Mindestbreite und liegt **im selben** HBox — kein Anchor-
  Overlay mehr. Damit gibt es keinen Zustand, in dem sich zwei Panels überlappen können.

## 4. Tokens (aus `ui_theme.gd`, nichts Neues erfinden)

| Zweck | Token |
|---|---|
| Karten-Panel | `card_style(SURFACE_2)`, radius `RADIUS_M`, border 1px `BORDER_SUBTLE` |
| Karte hover | border `BORDER_STRONG`, bg `SURFACE_3` |
| Karte selected | border 2px `ACCENT_PLATINUM` + `glow_soft` |
| Karte disabled (zu wenig Gold) | `modulate.a = 0.45`, Kostenlabel `STATE_DANGER` |
| Kartenabstand | `SPACE_2` |
| Bar-Innenabstand | `SPACE_3` |
| Kostenzahl | `CAPTION`, tabular figures |
| Turmname | `LABEL_SMALL`, `TEXT_PRIMARY`, letter_spacing wie im System |

## 5. Umsetzungsreihenfolge (bitte in dieser Reihenfolge, ein Commit pro Schritt)

1. **ShopCard als eigene Scene** (`ui/shop/shop_card.tscn` + `.gd`) nach dem Baum in §2,
   mit API `setup(tower_data)` und Signal `pressed(tower_id)`.
   Alle Größen aus `ui_theme.gd`, keine Inline-Overrides.
2. **ShopRow instanziert ShopCard** statt der bisherigen freien Nodes. Alte
   Icon/Label/Badge-Nodes und deren Positionscode löschen.
3. **BottomBar auf die 3-Spalten-Struktur** aus §3 umbauen (ScrollContainer einziehen,
   WavePanel aus dem Anchor-Overlay in den HBox holen).
4. **Karten-States** (hover / selected / disabled) über die Tokens aus §4.
5. Erst danach Phase 4.

## 6. Abnahmekriterien

- Längster Turmname im Spiel (`ZAUBERERFALLE`) → Karte bleibt exakt 88px breit,
  Text wird mit `…` getrimmt, Tooltip zeigt den vollen Namen.
- Fenster auf minimale unterstützte Breite ziehen → ShopRow clippt/scrollt,
  WavePanel wird nie überlappt, Pfeile bleiben sichtbar.
- Alle Karten zeigen einen Sprite oder einen sichtbaren Placeholder — nie leer.
- Kostenbadge liegt nie auf dem Sprite.
- Schriftwechsel in `ui_theme.gd` verändert **keine** Layoutbreite mehr (Gegentest:
  Font-Size temporär +4px, Layout muss identisch bleiben).

## 7. Fragen, die du mir vorher stellen solltest

- Ist die Kartenbreite 88px mit dem 48px-Sprite-Raster verträglich, oder sind die
  Turm-Sprites 32px/64px? Dann Slot und Karte entsprechend anpassen (Slot = Sprite-Größe,
  Karte = Slot + 2×`SPACE_2` + Textzeilen).
- Wie viele Türme sind maximal gleichzeitig im Shop? Wenn ≤ 6 und Platz reicht, kann der
  ScrollContainer statisch bleiben; wenn mehr, brauchen die Pfeile Enable/Disable-States.
