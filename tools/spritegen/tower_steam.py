"""Generiert assets/elemental_tower/tower_steam.png (16x64, 4 Frames) plus
Stufen-Varianten _level_2/_level_3.

Fusionsturm (water+fire) hat nur 3 Ausbaustufen (upgrade_costs mit 2 Eintraegen,
data/tower_data.gd:250), daher keine 2/5/8-Meilensteine wie bei den Basistuermen -
hier stattdessen level_2 und level_3 direkt.

Kessel mit Rohr; Animation = aufsteigende Dampfwolke.
Palette leitet sich aus der Turmfarbe Color(0.8, 0.8, 0.9) = #cccce6
(data/tower_data.gd:249) ab. Ausfuehren: python3 tools/spritegen/tower_steam.py
[--preview DIR]
"""

from __future__ import annotations

from pixel import Canvas, emit_tower, preview_arg, shade

BASE = "#cccce6"

KETTLE_LIGHT = shade(BASE, -0.10)
KETTLE_DARK = shade(BASE, -0.45)
PIPE_LIGHT = (0x8a, 0x86, 0x7a, 255)
PIPE_DARK = (0x4a, 0x46, 0x40, 255)
OUTLINE = (0x1a, 0x1a, 0x20, 255)
TRIM_STRIPE = shade(BASE, -0.60)

STEAM_COLORS = [
    (0xb8, 0xb8, 0xc8, 255),
    (0xd8, 0xd8, 0xe8, 255),
    (0xff, 0xff, 0xff, 255),
    (0xd8, 0xd8, 0xe8, 255),
]

W, H = 16, 16

KETTLE_HALF = {9: 1, 10: 2, 11: 3, 12: 3, 13: 3}
BASE_HALF = {14: 4, 15: 4}
PIPE_ROWS = range(5, 9)

# Dampfpunkte je Frame - steigen ueber die Phasen nach oben und driften seitlich.
STEAM_PUFFS = [
    [(9, 5)],
    [(9, 4), (10, 5)],
    [(9, 3), (10, 4), (8, 5)],
    [(10, 3), (8, 4)],
]


def build_body(level: int) -> Canvas:
    c = Canvas(W, H)

    for y, half in KETTLE_HALF.items():
        x0, x1 = 7 - half, 8 + half
        for x in range(x0, x1 + 1):
            c.px(x, y, KETTLE_LIGHT if x < 8 else KETTLE_DARK)

    for y, half in BASE_HALF.items():
        x0, x1 = 7 - half, 8 + half
        for x in range(x0, x1 + 1):
            c.px(x, y, KETTLE_LIGHT if x < 8 else KETTLE_DARK)

    for y in PIPE_ROWS:
        c.px(8, y, PIPE_LIGHT)
        c.px(9, y, PIPE_DARK)
    c.px(8, PIPE_ROWS[0] - 1, OUTLINE)
    c.px(9, PIPE_ROWS[0] - 1, OUTLINE)

    if level >= 2:
        x0, x1 = 7 - BASE_HALF[14], 8 + BASE_HALF[14]
        c.hline(x0, x1, 13, TRIM_STRIPE)

    if level >= 3:
        c.px(3, 15, KETTLE_DARK)
        c.px(12, 15, KETTLE_DARK)

    return c


def build_frame(phase: int, level: int) -> Canvas:
    c = build_body(level)
    for x, y in STEAM_PUFFS[phase]:
        c.px(x, y, STEAM_COLORS[phase])
    return c


def main() -> None:
    frames_by_level = {
        level: [build_frame(p, level) for p in range(4)]
        for level in (0, 2, 3)
    }
    emit_tower("steam", frames_by_level, max_colors=12, preview_dir=preview_arg())


if __name__ == "__main__":
    main()
