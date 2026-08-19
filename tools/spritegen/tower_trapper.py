"""Generiert assets/elemental_tower/tower_trapper.png (16x64, 4 Frames) plus
Stufen-Varianten _level_2/_level_5/_level_8.

Flache Plattform mit zwei Fangzaehnen, die ueber die 4 Frames zuschnappen.
Palette leitet sich aus der Turmfarbe Color(0.4, 0.6, 0.3) = #66994d
(data/tower_data.gd:146) ab. Ausfuehren: python3 tools/spritegen/tower_trapper.py
[--preview DIR]
"""

from __future__ import annotations

from pixel import Canvas, emit_tower, preview_arg, shade

BASE = "#66994d"

PLATE_LIGHT = shade(BASE, -0.05)
PLATE_DARK = shade(BASE, -0.45)
TOOTH_LIGHT = (0x9c, 0x9c, 0x94, 255)
TOOTH_DARK = (0x54, 0x54, 0x4c, 255)
OUTLINE = (0x12, 0x18, 0x0e, 255)
TRIM_STRIPE = shade(BASE, 0.25)
GOLD = (0xe8, 0xc4, 0x4a, 255)
GOLD_DARK = (0xa8, 0x86, 0x24, 255)

W, H = 16, 16

PLATFORM_HALF = {11: 3, 12: 4, 13: 4, 14: 4, 15: 4}

# Zahnstellung je Frame: (aussen_x, hoehe_offset). Frame 2 = geschlossen (Biss).
TOOTH_OUTER_X = [5, 4, 3, 4]
TOOTH_TOP_Y = [7, 6, 5, 6]


def _span(half: int) -> tuple[int, int]:
    return 7 - half, 8 + half


def build_platform(level: int) -> Canvas:
    c = Canvas(W, H)

    for y, half in PLATFORM_HALF.items():
        x0, x1 = _span(half)
        for x in range(x0, x1 + 1):
            c.px(x, y, PLATE_LIGHT if x < 8 else PLATE_DARK)

    if level >= 2:
        x0, x1 = _span(PLATFORM_HALF[13])
        c.hline(x0, x1, 11, TRIM_STRIPE)

    if level >= 5:
        c.px(2, 15, PLATE_DARK)
        c.px(13, 15, PLATE_DARK)

    if level >= 8:
        c.px(3, 11, GOLD)
        c.px(12, 11, GOLD_DARK)

    return c


def build_frame(phase: int, level: int) -> Canvas:
    c = build_platform(level)

    outer_x = TOOTH_OUTER_X[phase]
    top_y = TOOTH_TOP_Y[phase]
    left_x = outer_x
    right_x = 15 - outer_x

    for y in range(top_y, 11):
        c.px(left_x, y, TOOTH_LIGHT)
        c.px(right_x, y, TOOTH_DARK)
    c.px(left_x, top_y - 1, OUTLINE)
    c.px(right_x, top_y - 1, OUTLINE)

    return c


def main() -> None:
    frames_by_level = {
        level: [build_frame(p, level) for p in range(4)]
        for level in (0, 2, 5, 8)
    }
    emit_tower("trapper", frames_by_level, max_colors=12, preview_dir=preview_arg())


if __name__ == "__main__":
    main()
