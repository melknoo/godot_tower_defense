"""Generiert assets/elemental_tower/tower_aura.png (16x64, 4 Frames) plus
Stufen-Varianten _level_2/_level_5/_level_8.

Schlanker Sockel mit schwebendem Ring darueber; Animation = pulsierender Ring
(naechstverwandt zum Wizard-Orb, siehe tools/spritegen/tower_wizard.py).
Palette leitet sich aus der Turmfarbe Color(1.0, 0.9, 0.4) = #ffe666
(data/tower_data.gd:161) ab. Ausfuehren: python3 tools/spritegen/tower_aura.py
[--preview DIR]
"""

from __future__ import annotations

from pixel import Canvas, emit_tower, preview_arg, shade

BASE = "#ffe666"

STONE_LIGHT = (0x6a, 0x62, 0x4a, 255)
STONE_DARK = (0x40, 0x3a, 0x2a, 255)
TRIM_STRIPE = shade(BASE, -0.55)
GOLD = (0xe8, 0xc4, 0x4a, 255)
GOLD_DARK = (0xa8, 0x86, 0x24, 255)

RING_COLORS = [
    shade(BASE, -0.20),   # frame 0: gedimmt
    shade(BASE, 0.20),    # frame 1: hell
    (0xff, 0xff, 0xf0, 255),  # frame 2: Maximum
    shade(BASE, 0.20),    # frame 3: wie frame 1
]
RING_GLOW = shade(BASE, 0.55)

W, H = 16, 16

SHAFT_ROWS = range(9, 13)
SHAFT_HALF = 1
BASE_HALF = {13: 2, 14: 3, 15: 3}

# Ringpunkte relativ zum Zentrum (7/8, 4) - Quadratring, Ecken abgeschnitten.
RING_PIXELS = [
    (6, 2), (7, 2), (8, 2), (9, 2),
    (5, 3), (10, 3),
    (5, 4), (10, 4),
    (5, 5), (10, 5),
    (6, 6), (7, 6), (8, 6), (9, 6),
]


def build_body(level: int) -> Canvas:
    c = Canvas(W, H)

    for y in SHAFT_ROWS:
        x0, x1 = 7 - SHAFT_HALF, 8 + SHAFT_HALF
        for x in range(x0, x1 + 1):
            c.px(x, y, STONE_LIGHT if x < 8 else STONE_DARK)

    for y, half in BASE_HALF.items():
        x0, x1 = 7 - half, 8 + half
        for x in range(x0, x1 + 1):
            c.px(x, y, STONE_LIGHT if x < 8 else STONE_DARK)

    if level >= 2:
        x0, x1 = 7 - BASE_HALF[14], 8 + BASE_HALF[14]
        c.hline(x0, x1, 12, TRIM_STRIPE)

    if level >= 5:
        c.px(4, 15, STONE_DARK)
        c.px(11, 15, STONE_DARK)

    if level >= 8:
        c.px(6, 8, GOLD)
        c.px(9, 8, GOLD_DARK)

    return c


def build_frame(phase: int, level: int) -> Canvas:
    c = build_body(level)
    color = RING_COLORS[phase]
    for x, y in RING_PIXELS:
        c.px(x, y, color)

    if phase == 2:
        for x, y in [(4, 3), (11, 3), (4, 5), (11, 5)]:
            c.px(x, y, RING_GLOW)

    return c


def main() -> None:
    frames_by_level = {
        level: [build_frame(p, level) for p in range(4)]
        for level in (0, 2, 5, 8)
    }
    emit_tower("aura", frames_by_level, max_colors=12, preview_dir=preview_arg())


if __name__ == "__main__":
    main()
