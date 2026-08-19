"""Generiert assets/elemental_tower/tower_cannon.png (16x64, 4 Frames) plus
Stufen-Varianten _level_2/_level_5/_level_8.

Gedrungener Sockel mit drehbarer Kuppel und dickem Rohr nach rechts.
Animation = Muendungsblitz + leichter Rueckstoss ueber 4 Frames.
Palette leitet sich aus der Turmfarbe Color(0.3, 0.3, 0.3) = #4d4d4d
(data/tower_data.gd:124) ab. Ausfuehren: python3 tools/spritegen/tower_cannon.py
[--preview DIR]
"""

from __future__ import annotations

from pixel import Canvas, emit_tower, preview_arg, shade

BASE = "#4d4d4d"

METAL_LIGHT = shade(BASE, 0.25)
METAL_DARK = shade(BASE, -0.30)
BASE_LIGHT = (0x5c, 0x54, 0x4a, 255)
BASE_DARK = (0x36, 0x30, 0x2a, 255)
OUTLINE = (0x14, 0x12, 0x10, 255)
TRIM_STRIPE = shade(BASE, -0.10)
GOLD = (0xe8, 0xc4, 0x4a, 255)
GOLD_DARK = (0xa8, 0x86, 0x24, 255)

FLASH_COLORS = [
    (0x99, 0x55, 0x22, 255),  # frame 0: gedimmte Gluehmuendung
    (0xff, 0xaa, 0x33, 255),  # frame 1: hell
    (0xff, 0xf0, 0xc0, 255),  # frame 2: Blitz-Maximum
    (0xff, 0xaa, 0x33, 255),  # frame 3: wie frame 1 (abklingend)
]

W, H = 16, 16

MOUNT_HALF = {12: 3, 13: 4, 14: 4, 15: 4}
DOME_ROWS = range(6, 11)
DOME_HALF = 2
BARREL_Y = (7, 8)


def _span(half: int) -> tuple[int, int]:
    return 7 - half, 8 + half


def build_body(level: int, recoil: int) -> Canvas:
    c = Canvas(W, H)

    for y, half in MOUNT_HALF.items():
        x0, x1 = _span(half)
        for x in range(x0, x1 + 1):
            c.px(x, y, BASE_LIGHT if x < 8 else BASE_DARK)

    for y in DOME_ROWS:
        x0, x1 = _span(DOME_HALF)
        for x in range(x0, x1 + 1):
            c.px(x, y, METAL_LIGHT if x < 8 else METAL_DARK)

    if level >= 2:
        x0, x1 = _span(MOUNT_HALF[14])
        c.hline(x0, x1, 11, TRIM_STRIPE)

    if level >= 5:
        c.px(3, 15, BASE_DARK)
        c.px(12, 15, BASE_DARK)

    # Rohr, per Rueckstoss um bis zu 1px verkuerzt.
    barrel_x1 = 14 - recoil
    for y in BARREL_Y:
        for x in range(9, barrel_x1 + 1):
            c.px(x, y, METAL_LIGHT if y == BARREL_Y[0] else METAL_DARK)
    c.px(9, 6, OUTLINE)
    c.px(9, 9, OUTLINE)

    if level >= 8:
        c.px(9, 6, GOLD)
        c.px(9, 9, GOLD_DARK)

    return c


def build_frame(phase: int, level: int) -> Canvas:
    recoil = 1 if phase in (1, 2) else 0
    c = build_body(level, recoil)
    if phase == 2:
        muzzle_x = 14 - 1
        c.px(muzzle_x + 1, 7, FLASH_COLORS[phase])
        c.px(muzzle_x + 1, 8, FLASH_COLORS[phase])
    else:
        c.px(14, 7, FLASH_COLORS[phase])
    return c


def main() -> None:
    frames_by_level = {
        level: [build_frame(p, level) for p in range(4)]
        for level in (0, 2, 5, 8)
    }
    emit_tower("cannon", frames_by_level, max_colors=12, preview_dir=preview_arg())


if __name__ == "__main__":
    main()
