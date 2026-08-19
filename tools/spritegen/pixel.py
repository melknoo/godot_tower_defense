"""Kleine Pixel-Art-Hilfsschicht ueber numpy + Pillow.

Kein Framework - nur das Minimum, um 16x16-Frames im Stil der vorhandenen
Turm-Sprites (assets/elemental_tower/tower_archer.png, tower_fire.png) zu
bauen: harte Kanten, Alpha nur 0/255, kleine Palette aus einer Basisfarbe.
"""

from __future__ import annotations

import argparse
import colorsys
from pathlib import Path

import numpy as np
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]


def hex_to_rgb(color: str) -> tuple[int, int, int]:
    color = color.lstrip("#")
    return tuple(int(color[i:i + 2], 16) for i in (0, 2, 4))


def shade(color: str, amount: float) -> tuple[int, int, int, int]:
    """Basisfarbe in HSV auf-/abdunkeln. amount>0 heller, amount<0 dunkler."""
    r, g, b = (c / 255.0 for c in hex_to_rgb(color))
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if amount >= 0:
        v = v + (1.0 - v) * amount
    else:
        v = v * (1.0 + amount)
        s = min(1.0, s * (1.0 - amount * 0.3))
    r, g, b = colorsys.hsv_to_rgb(h, min(s, 1.0), max(0.0, min(v, 1.0)))
    return (round(r * 255), round(g * 255), round(b * 255), 255)


class Canvas:
    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.data = np.zeros((h, w, 4), dtype=np.uint8)

    def px(self, x: int, y: int, color: tuple[int, int, int, int]) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.data[y, x] = color

    def rect(self, x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int, int]) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, color)

    def hline(self, x0: int, x1: int, y: int, color: tuple[int, int, int, int]) -> None:
        self.rect(x0, y, x1, y, color)

    def vline(self, x: int, y0: int, y1: int, color: tuple[int, int, int, int]) -> None:
        self.rect(x, y0, x, y1, color)

    def mirror_x(self) -> None:
        """Rechte Haelfte aus der linken spiegeln (mittlere Spalte bleibt bei ungerader Breite)."""
        half = self.w // 2
        for y in range(self.h):
            for x in range(half):
                self.data[y, self.w - 1 - x] = self.data[y, x]


def stack_frames(frames: list[Canvas]) -> Canvas:
    assert frames, "mindestens ein Frame noetig"
    w = frames[0].w
    h = frames[0].h
    assert all(f.w == w and f.h == h for f in frames), "alle Frames muessen gleich gross sein"
    out = Canvas(w, h * len(frames))
    for i, f in enumerate(frames):
        out.data[i * h:(i + 1) * h, :, :] = f.data
    return out


def _validate_hard_edges(canvas: Canvas, max_colors: int) -> None:
    alphas = set(np.unique(canvas.data[:, :, 3]).tolist())
    assert alphas <= {0, 255}, f"Alpha muss 0 oder 255 sein, gefunden: {alphas}"
    opaque = canvas.data[canvas.data[:, :, 3] == 255]
    colors = {tuple(c) for c in opaque[:, :3].tolist()}
    assert len(colors) <= max_colors, (
        f"zu viele Farben ({len(colors)} > {max_colors}): {sorted(colors)}"
    )


def save_indexed_rgba(canvas: Canvas, path: Path, max_colors: int = 8) -> None:
    _validate_hard_edges(canvas, max_colors)
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(canvas.data, mode="RGBA").save(path, optimize=True)


def save_preview(canvas: Canvas, path: Path, scale: int = 8) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.fromarray(canvas.data, mode="RGBA")
    img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(path)


def preview_arg() -> Path | None:
    """--preview DIR aus argv lesen; None wenn nicht angegeben (kein Preview)."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", type=Path, default=None)
    args, _ = parser.parse_known_args()
    return args.preview


def emit_tower(
    tower_type: str,
    frames_by_level: dict[int, list[Canvas]],
    max_colors: int = 10,
    preview_dir: Path | None = None,
) -> None:
    """Schreibt Basis- und Stufen-Spritesheets fuer einen Turmtyp.

    frames_by_level: {0: [frame0..frame3], 2: [...], ...}. Level 0 wird zu
    tower_<typ>.png, alle anderen Keys zu tower_<typ>_level_<n>.png
    (Konvention aus tower.gd:_get_tower_texture_path: level N -> level_(N+1)-Datei,
    d.h. der Key hier ist bereits die Dateisuffix-Zahl, nicht der 0-basierte Level).
    """
    out_dir = REPO_ROOT / "assets" / "elemental_tower"
    for level, frames in sorted(frames_by_level.items()):
        sheet = stack_frames(frames)
        if level == 0:
            out_path = out_dir / f"tower_{tower_type}.png"
        else:
            out_path = out_dir / f"tower_{tower_type}_level_{level}.png"
        save_indexed_rgba(sheet, out_path, max_colors=max_colors)
        print(f"geschrieben: {out_path}")

        if preview_dir is not None:
            preview_path = preview_dir / f"{out_path.stem}_preview.png"
            save_preview(sheet, preview_path, scale=8)
            print(f"preview:     {preview_path}")
