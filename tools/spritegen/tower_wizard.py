"""Generiert assets/elemental_tower/tower_wizard.png (16x64, 4 Frames).

Kleiner Steinturm mit Zauberhut-Dach und pulsierendem Orb im Fenster.
Palette leitet sich aus der Turmfarbe Color(0.6, 0.3, 0.9) = #9a4de5
(data/tower_data.gd:106) ab. Ausfuehren: python3 tools/spritegen/tower_wizard.py
"""

from __future__ import annotations

from pathlib import Path

from pixel import REPO_ROOT, Canvas, save_indexed_rgba, save_preview, shade

PREVIEW_DIR = Path(
    "/tmp/claude-1000/-home-melvin-Repositories-godot-tower-defense/"
    "587361e5-4898-4b2b-aa4e-1dc60d74cad1/scratchpad"
)

BASE = "#9a4de5"

ROOF_LIGHT = shade(BASE, 0.10)
ROOF_DARK = shade(BASE, -0.40)
STONE_LIGHT = (0x5c, 0x54, 0x68, 255)
STONE_DARK = (0x36, 0x2e, 0x40, 255)
OUTLINE = (0x18, 0x12, 0x1e, 255)

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


def build_body() -> Canvas:
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

    # Fensterrahmen (Aussenrand dunkel), Innenflaeche bleibt frei fuer den Orb.
    for y in WINDOW_ROWS:
        c.px(6, y, OUTLINE)
        c.px(9, y, OUTLINE)
    c.hline(6, 9, WINDOW_ROWS[0] - 1, OUTLINE)
    c.hline(6, 9, WINDOW_ROWS[-1] + 1, OUTLINE)

    return c


def build_frame(phase: int) -> Canvas:
    c = build_body()
    orb = ORB_COLORS[phase]
    c.rect(7, 9, 8, 10, orb)

    if phase == 2:
        for x, y in [(5, 9), (10, 9), (5, 10), (10, 10)]:
            c.px(x, y, ORB_GLOW)

    return c


def main() -> None:
    from pixel import stack_frames

    frames = [build_frame(p) for p in range(4)]
    sheet = stack_frames(frames)

    out_path = REPO_ROOT / "assets" / "elemental_tower" / "tower_wizard.png"
    save_indexed_rgba(sheet, out_path, max_colors=10)

    preview_path = PREVIEW_DIR / "tower_wizard_preview.png"
    save_preview(sheet, preview_path, scale=8)

    print(f"geschrieben: {out_path}")
    print(f"preview:     {preview_path}")


if __name__ == "__main__":
    main()
