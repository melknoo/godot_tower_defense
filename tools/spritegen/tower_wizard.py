"""Generiert assets/elemental_tower/tower_wizard.png (16x64, 4 Frames) plus
Stufen-Varianten _level_2/_level_5/_level_8.

Kleiner Steinturm mit Zauberhut-Dach und pulsierendem Orb im Fenster.
Palette leitet sich aus der Turmfarbe Color(0.6, 0.3, 0.9) = #9a4de5
(data/tower_data.gd:106) ab. Ausfuehren: python3 tools/spritegen/tower_wizard.py
[--preview DIR]
"""

from __future__ import annotations

from pixel import Canvas, emit_tower, preview_arg, shade

BASE = "#9a4de5"

ROOF_LIGHT = shade(BASE, 0.10)
ROOF_DARK = shade(BASE, -0.40)
STONE_LIGHT = (0x5c, 0x54, 0x68, 255)
STONE_DARK = (0x36, 0x2e, 0x40, 255)
OUTLINE = (0x18, 0x12, 0x1e, 255)
TRIM_STRIPE = shade(BASE, -0.10)
GOLD = (0xe8, 0xc4, 0x4a, 255)
GOLD_DARK = (0xa8, 0x86, 0x24, 255)

ORB_COLORS = [
    shade(BASE, -0.15),   # frame 0: gedimmt
    shade(BASE, 0.35),    # frame 1: hell
    (0xff, 0xf3, 0xff, 255),  # frame 2: weiss-violettes Maximum
    shade(BASE, 0.35),    # frame 3: wie frame 1 (symmetrischer Puls)
]
ORB_GLOW = shade(BASE, 0.55)

W, H = 16, 16

# Halbe Breite (jenseits des Mittelpaars x=7,8) pro Zeile.
ROOF_HALF = {1: 0, 2: 0, 3: 1, 4: 2, 5: 3, 6: 4}
SHAFT_ROWS = range(7, 13)
SHAFT_HALF = 2
BASE_HALF = {13: 3, 14: 4, 15: 4}

WINDOW_ROWS = (9, 10)


def _span(y_center_half: int) -> tuple[int, int]:
    return 7 - y_center_half, 8 + y_center_half


def build_body(level: int) -> Canvas:
    c = Canvas(W, H)

    for y, half in ROOF_HALF.items():
        x0, x1 = _span(half)
        for x in range(x0, x1 + 1):
            c.px(x, y, ROOF_LIGHT if x < 8 else ROOF_DARK)

    for y in SHAFT_ROWS:
        x0, x1 = _span(SHAFT_HALF)
        for x in range(x0, x1 + 1):
            c.px(x, y, STONE_LIGHT if x < 8 else STONE_DARK)

    for y, half in BASE_HALF.items():
        x0, x1 = _span(half)
        for x in range(x0, x1 + 1):
            c.px(x, y, STONE_LIGHT if x < 8 else STONE_DARK)

    # Stufe 2: zusaetzliche Zierreihe am Sockelrand.
    if level >= 2:
        x0, x1 = _span(BASE_HALF[14])
        c.hline(x0, x1, 12, TRIM_STRIPE)

    # Stufe 5: verbreiterter Sockel (Strebepfeiler-Andeutung).
    if level >= 5:
        c.px(3, 15, STONE_DARK)
        c.px(12, 15, STONE_DARK)

    # Fensterrahmen (Aussenrand dunkel), Innenflaeche bleibt frei fuer den Orb.
    for y in WINDOW_ROWS:
        c.px(6, y, OUTLINE)
        c.px(9, y, OUTLINE)
    c.hline(6, 9, WINDOW_ROWS[0] - 1, OUTLINE)
    c.hline(6, 9, WINDOW_ROWS[-1] + 1, OUTLINE)

    # Stufe 8: goldener Dachrand.
    if level >= 8:
        c.px(3, 6, GOLD)
        c.px(12, 6, GOLD)
        c.px(4, 6, GOLD_DARK)
        c.px(11, 6, GOLD_DARK)

    return c


def build_frame(phase: int, level: int) -> Canvas:
    c = build_body(level)
    orb = ORB_COLORS[phase]
    c.rect(7, 9, 8, 10, orb)

    if phase == 2:
        for x, y in [(5, 9), (10, 9), (5, 10), (10, 10)]:
            c.px(x, y, ORB_GLOW)

    return c


def main() -> None:
    frames_by_level = {
        level: [build_frame(p, level) for p in range(4)]
        for level in (0, 2, 5, 8)
    }
    emit_tower("wizard", frames_by_level, max_colors=12, preview_dir=preview_arg())


if __name__ == "__main__":
    main()
