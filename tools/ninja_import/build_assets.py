#!/usr/bin/env python3
"""Baut die Spielgrafiken aus dem Ninja-Adventure-Pack (Pixel-boy & AAA, CC0).

Regel (siehe PROGRESS.md, "Art-Vereinheitlichung"): alles in der Welt ist 16-px-Art
und laeuft im Spiel ganzzahlig x4 - ein 16-px-Tile fuellt genau eine 64-px-Zelle.
Tuerme sind Figuren aus Actor/Character, Gegner Monster aus Actor/Monster, Bosse aus
Actor/Boss. So bleibt Freund/Feind schon an der Figurenart lesbar.

Aufruf (Pack liegt bewusst ausserhalb des Repos):
    python -I tools/ninja_import/build_assets.py --pack "D:/assets_src/ninja_adventure/Ninja Adventure - Asset Pack" --write
    python -I tools/ninja_import/build_assets.py --pack ... --preview contact_sheet.png

Ohne --write wird nichts unter assets/ angefasst.
"""
from __future__ import annotations

import argparse
import random
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
T = 16  # Kachelgroesse im Pack

# --- Zuordnungen ----------------------------------------------------------------

# Turm-ID -> Ordner unter Actor/Character. Ausgabe: tower_<id>.png, 16x32 = [Stand, Angriff].
TOWERS = {
    "sword": "Knight",
    "archer": "Hunter",
    "wizard": "Master",
    "cannon": "RobotGrey",
    "trapper": "CamouflageGreen",
    "aura": "Shaman",
    "water": "NinjaWater",
    "fire": "Flam",
    "earth": "Statue",
    "air": "NinjaThunder",
    "ice": "NinjaEskimo",
    "steam": "NinjaGray",
    "lava": "DemonRed",
    "nature": "NinjaLeaf",
}

# Gebaeude aus TilesetTowers.png (32x32, Spalte/Zeile in 16-px-Kacheln). Laufen im
# Spiel x2 - die einzigen 32-px-Motive, als Ausnahme wie die Bosse dokumentiert.
BUILDINGS = {
    "farm": (0, 0),    # Holzspeicher auf Stelzen (die gruene Huette las sich als Baum)
    "city": (12, 0),   # Burgturm
}

# Gegnertyp -> Ordner unter Actor/Monster. Ausgabe: enemy_<typ>.png, 64x16 (4 Lauf-Frames).
ENEMIES = {
    "normal": "Slime",
    "swift": "BlueBat",
    "tank": "KappaGreen",
    "ethereal": "Spirit",
    "brute": "Cyclope",
    "burrower": "Mole",
}

# Boss je Wellen-Element -> (Ordner unter Actor/Boss, Datei, Frameanzahl)
BOSSES = {
    "neutral": ("GiantSlime2", "Idle.png", 5),
    "fire": ("GiantFlam", "Idle.png", 5),
    "water": ("GiantSlime", "Idle.png", 5),
    "earth": ("GiantRacoon", "Idle.png", 6),
    "air": ("GiantSpirit", "Idle.png", 5),
}

# Pfad-Quellkacheln in TilesetFloor.png (helles Gras + Erdweg), (Spalte, Zeile).
# Der Pfad wird im Spiel aus 8x8-Vierteln dieser Kacheln zusammengesetzt (ground_layer.gd).
PATH_SOURCES = [
    ("iso", (3, 10)),     # Einzelfeld: liefert die vier Aussenecken
    ("hmid", (1, 10)),    # waagrechtes Mittelstueck: Ober-/Unterkante
    ("vmid", (3, 8)),     # senkrechtes Mittelstueck: linke/rechte Kante
    ("center", (1, 8)),   # reine Erde
    ("inner_br", (5, 8)),  # Innenecke unten rechts
    ("inner_bl", (6, 8)),
    ("inner_tr", (5, 9)),
    ("inner_tl", (6, 9)),
]
GRASS_SOURCES = [(0, 12), (1, 12), (2, 12), (3, 12), (4, 12), (2, 11), (3, 11)]

# Wegmaterialien: Erd-Farben werden umgefaerbt, Gras bleibt. Reihenfolge = Atlaszeile.
DIRT_BASE = (211, 134, 95)
DIRT_DARK = (189, 121, 89)
MATERIALS = {
    "dirt":     {DIRT_BASE: DIRT_BASE, DIRT_DARK: DIRT_DARK},
    "mud":      {DIRT_BASE: (124, 92, 66), DIRT_DARK: (96, 70, 52)},
    "ford":     {DIRT_BASE: (88, 162, 214), DIRT_DARK: (150, 208, 238)},
    "ash":      {DIRT_BASE: (104, 98, 104), DIRT_DARK: (78, 72, 80)},
    "windpass": {DIRT_BASE: (214, 208, 186), DIRT_DARK: (236, 236, 228)},
}
MATERIAL_SPRINKLE = {  # (Farbe, Anteil) - Glut in der Asche, Pfuetzen im Schlamm
    "ash": ((236, 116, 52), 0.035),
    "mud": ((78, 58, 44), 0.05),
}

# Deko aus TilesetNature.png (Spalte, Zeile) - Buesche, Blumen, kleine Steine
DECOS = [
    (0, 10), (1, 10), (2, 10), (3, 10), (4, 10), (5, 10), (6, 10), (8, 10), (9, 10), (10, 10),
    (0, 11), (1, 11), (2, 11), (3, 11), (5, 11), (6, 11),
    (7, 12),  # nur ein Stein - die weissen Schnee-Varianten passen nicht auf Gras
]


# --- Helfer ---------------------------------------------------------------------

def tile(img: Image.Image, col: int, row: int, size: int = T) -> Image.Image:
    return img.crop((col * size, row * size, col * size + size, row * size + size))


def recolor(img: Image.Image, mapping: dict, sprinkle=None, seed: int = 0) -> Image.Image:
    out = img.copy()
    px = out.load()
    rng = random.Random(seed)
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if (r, g, b) in mapping:
                nr, ng, nb = mapping[(r, g, b)]
                if sprinkle and (r, g, b) == DIRT_BASE and rng.random() < sprinkle[1]:
                    nr, ng, nb = sprinkle[0]
                px[x, y] = (nr, ng, nb, a)
    return out


def character_poses(pack: Path, folder: str) -> Image.Image:
    sheet = Image.open(pack / "Actor/Character" / folder / "SpriteSheet.png").convert("RGBA")
    out = Image.new("RGBA", (T, T * 2))
    out.paste(tile(sheet, 0, 0), (0, 0))   # Stand (Blick nach unten)
    out.paste(tile(sheet, 0, 4), (0, T))   # Angriff
    return out


def monster_walk(pack: Path, folder: str) -> Image.Image:
    d = pack / "Actor/Monster" / folder
    src = next(p for p in sorted(d.glob("*.png")) if p.name != "Faceset.png")
    sheet = Image.open(src).convert("RGBA")
    out = Image.new("RGBA", (T * 4, T))
    for i in range(4):
        out.paste(tile(sheet, 0, i), (i * T, 0))
    return out


def boss_strip(pack: Path, folder: str, file: str, frames: int) -> Image.Image:
    return Image.open(pack / "Actor/Boss" / folder / file).convert("RGBA")


def build_path_atlas(pack: Path) -> Image.Image:
    floor = Image.open(pack / "Backgrounds/Tilesets/TilesetFloor.png").convert("RGBA")
    atlas = Image.new("RGBA", (T * len(PATH_SOURCES), T * len(MATERIALS)))
    for mi, (mat, mapping) in enumerate(MATERIALS.items()):
        for si, (_, (c, r)) in enumerate(PATH_SOURCES):
            src = recolor(tile(floor, c, r), mapping, MATERIAL_SPRINKLE.get(mat), seed=mi * 31 + si)
            atlas.paste(src, (si * T, mi * T))
    return atlas


def build_grass_atlas(pack: Path) -> Image.Image:
    floor = Image.open(pack / "Backgrounds/Tilesets/TilesetFloor.png").convert("RGBA")
    atlas = Image.new("RGBA", (T * len(GRASS_SOURCES), T))
    for i, (c, r) in enumerate(GRASS_SOURCES):
        atlas.paste(tile(floor, c, r), (i * T, 0))
    return atlas


def build_deco_atlas(pack: Path) -> Image.Image:
    nature = Image.open(pack / "Backgrounds/Tilesets/TilesetNature.png").convert("RGBA")
    atlas = Image.new("RGBA", (T * len(DECOS), T))
    for i, (c, r) in enumerate(DECOS):
        atlas.paste(tile(nature, c, r), (i * T, 0))
    return atlas


def build_pedestal() -> tuple[Image.Image, Image.Image]:
    """Runensockel 16x16: Steinplatte unten im Feld + separate Glut-Rune (weiss,
    im Spiel per modulate in Elementfarbe)."""
    stone = Image.new("RGBA", (T, T))
    glow = Image.new("RGBA", (T, T))
    sp, gp = stone.load(), glow.load()
    cx, cy, rx, ry = 7.5, 12.5, 7.0, 2.6

    def inside(x, y, sx=1.0, sy=1.0):
        return ((x - cx) / (rx * sx)) ** 2 + ((y - cy) / (ry * sy)) ** 2 <= 1.0

    for y in range(T):
        for x in range(T):
            if not inside(x, y):
                continue
            edge = not all(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge:
                sp[x, y] = (46, 42, 58, 255)
            elif y <= cy - 0.5:
                sp[x, y] = (164, 160, 176, 255)
            else:
                sp[x, y] = (118, 114, 132, 255)
            # Rune: schmaler Ring innerhalb der Oberseite
            if inside(x, y, 0.72, 0.62) and not inside(x, y, 0.45, 0.2) and not edge:
                gp[x, y] = (255, 255, 255, 255)
    # Sockelkante (Dicke nach unten)
    for x in range(1, 15):
        for y in range(14, 16):
            if inside(x, y - 1) and not inside(x, y):
                sp[x, y] = (46, 42, 58, 255)
    return stone, glow


# --- Ausgabe --------------------------------------------------------------------

def write_assets(pack: Path) -> None:
    tower_dir = REPO / "assets/elemental_tower"
    enemy_dir = REPO / "assets/enemies"
    tile_dir = REPO / "assets/tiles"
    deco_dir = REPO / "assets/decorations"
    for tower_id, folder in TOWERS.items():
        character_poses(pack, folder).save(tower_dir / f"tower_{tower_id}.png")
    towers_ts = Image.open(pack / "Backgrounds/Tilesets/TilesetTowers.png").convert("RGBA")
    for bid, (c, r) in BUILDINGS.items():
        towers_ts.crop((c * T, r * T, c * T + 32, r * T + 32)).save(tower_dir / f"{bid}.png")
    for etype, folder in ENEMIES.items():
        monster_walk(pack, folder).save(enemy_dir / f"enemy_{etype}.png")
    for elem, (folder, file, frames) in BOSSES.items():
        boss_strip(pack, folder, file, frames).save(enemy_dir / f"boss_{elem}.png")
    build_path_atlas(pack).save(tile_dir / "path_atlas.png")
    build_grass_atlas(pack).save(tile_dir / "grass_atlas.png")
    build_deco_atlas(pack).save(deco_dir / "nature_atlas.png")
    stone, glow = build_pedestal()
    stone.save(tower_dir / "pedestal.png")
    glow.save(tower_dir / "pedestal_glow.png")
    print("Assets geschrieben.")


def compose_path_cell(atlas: Image.Image, mat_row: int, conn: set) -> Image.Image:
    """Python-Spiegel von ground_layer.gd::_compose_path_cell (nur fuer die Vorschau)."""
    idx = {name: i for i, (name, _) in enumerate(PATH_SOURCES)}

    def q(name, qx, qy):
        x0 = idx[name] * T + qx * 8
        return atlas.crop((x0, mat_row * T + qy * 8, x0 + 8, mat_row * T + qy * 8 + 8))

    cell = Image.new("RGBA", (T, T))
    for qx, qy, h, v in ((0, 0, "L", "U"), (1, 0, "R", "U"), (0, 1, "L", "D"), (1, 1, "R", "D")):
        has_h, has_v = h in conn, v in conn
        if not has_h and not has_v:
            src = q("iso", qx, qy)
        elif has_h and not has_v:
            src = q("hmid", qx, qy)
        elif has_v and not has_h:
            src = q("vmid", qx, qy)
        else:
            corner = {(0, 0): "inner_tl", (1, 0): "inner_tr", (0, 1): "inner_bl", (1, 1): "inner_br"}[(qx, qy)]
            src = q(corner, qx, qy)
        cell.paste(src, (qx * 8, qy * 8))
    return cell


def preview(pack: Path, out: Path) -> None:
    S = 4
    path_atlas = build_path_atlas(pack)
    grass = build_grass_atlas(pack)
    deco = build_deco_atlas(pack)
    stone, glow = build_pedestal()

    # Mini-Karte 14x7 mit Kurven und allen vier Zonen
    W, H = 14, 7
    route = [(0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (4, 2), (4, 3), (4, 4), (5, 4), (6, 4), (7, 4),
             (8, 4), (8, 3), (8, 2), (8, 1), (9, 1), (10, 1), (11, 1), (11, 2), (11, 3), (11, 4),
             (11, 5), (12, 5), (13, 5)]
    zone = {}
    for c in route[1:4]: zone[c] = 1        # Schlamm
    for c in route[5:9]: zone[c] = 2        # Furt
    for c in route[12:16]: zone[c] = 3      # Asche
    for c in route[18:22]: zone[c] = 4      # Windpass
    m = Image.new("RGBA", (W * T, H * T))
    rng = random.Random(3)
    for y in range(H):
        for x in range(W):
            gi = 0 if rng.random() < 0.8 else rng.randrange(1, len(GRASS_SOURCES))
            m.paste(grass.crop((gi * T, 0, gi * T + T, T)), (x * T, y * T))
    for i, c in enumerate(route):
        conn = set()
        for nb in ([route[i - 1]] if i > 0 else [(c[0] - 1, c[1])]) + ([route[i + 1]] if i + 1 < len(route) else [(c[0] + 1, c[1])]):
            d = (nb[0] - c[0], nb[1] - c[1])
            conn.add({(-1, 0): "L", (1, 0): "R", (0, -1): "U", (0, 1): "D"}[d])
        m.paste(compose_path_cell(path_atlas, zone.get(c, 0), conn), (c[0] * T, c[1] * T))
    for (x, y) in [(1, 3), (6, 1), (10, 5), (13, 2), (2, 5), (6, 6)]:
        di = rng.randrange(deco.width // T)
        d_img = deco.crop((di * T, 0, di * T + T, T))
        m.alpha_composite(d_img, (x * T, y * T))

    # Tuerme auf Sockel neben dem Weg
    tower_spots = list(zip(TOWERS.keys(), [(1, 2), (3, 0), (3, 2), (5, 3), (6, 3), (7, 3), (5, 5),
                                           (7, 5), (9, 2), (9, 0), (10, 2), (12, 4), (10, 4), (13, 6)]))
    elem_colors = {"water": (90, 170, 255), "fire": (255, 120, 60), "earth": (190, 140, 80),
                   "air": (200, 230, 255), "ice": (160, 230, 255), "steam": (220, 220, 230),
                   "lava": (255, 90, 30), "nature": (120, 220, 110)}
    for tid, (x, y) in tower_spots:
        m.alpha_composite(stone, (x * T, y * T))
        col = elem_colors.get(tid, (255, 220, 120))
        g = Image.new("RGBA", glow.size, col + (0,))
        g.putalpha(glow.getchannel("A"))
        m.alpha_composite(g, (x * T, y * T))
        pose = character_poses(pack, TOWERS[tid]).crop((0, 0, T, T))
        m.alpha_composite(pose, (x * T, y * T - 3))
    # Gegner auf dem Weg
    for etype, idx in zip(ENEMIES.keys(), [2, 6, 10, 14, 17, 20]):
        cx, cy = route[idx]
        m.alpha_composite(monster_walk(pack, ENEMIES[etype]).crop((0, 0, T, T)), (cx * T, cy * T))

    map_big = m.resize((m.width * S, m.height * S), Image.NEAREST)

    # Legenden-Zeilen: Tuerme, Gegner, Bosse (x3)
    def row_of(images, labels, scale, bg=(34, 38, 48, 255), cell=80):
        w = len(images) * cell
        h = max(i.height for i in images) * scale + 26
        r = Image.new("RGBA", (w, h), bg)
        d = ImageDraw.Draw(r)
        for i, (img, lab) in enumerate(zip(images, labels)):
            big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
            r.alpha_composite(big, (i * cell + (cell - big.width) // 2, 2))
            d.text((i * cell + 4, h - 20), lab, fill=(230, 230, 230, 255))
        return r

    towers_row = row_of([character_poses(pack, f) for f in TOWERS.values()],
                        [f"{k}" for k in TOWERS.keys()], S, cell=80)
    enemies_row = row_of([monster_walk(pack, f).crop((0, 0, T, T)) for f in ENEMIES.values()],
                         list(ENEMIES.keys()), S, cell=90)
    boss_imgs = []
    for folder, file, frames in BOSSES.values():
        strip = boss_strip(pack, folder, file, frames)
        fw = strip.width // frames
        boss_imgs.append(strip.crop((0, 0, fw, strip.height)))
    bosses_row = row_of(boss_imgs, [f"boss {k}" for k in BOSSES.keys()], 3, cell=200)

    sections = [("Karte (x4): Erdweg, Schlamm, Furt, Asche, Windpass - Tuerme auf Runensockel", map_big),
                ("Tuerme (x4) - je [Stand | Angriff]", towers_row),
                ("Gegner (x4)", enemies_row),
                ("Bosse (x3, Ausnahme wegen Groesse)", bosses_row)]
    total_w = max(img.width for _, img in sections)
    total_h = sum(img.height + 30 for _, img in sections)
    sheet = Image.new("RGBA", (total_w, total_h), (24, 26, 34, 255))
    d = ImageDraw.Draw(sheet)
    y = 0
    for title, img in sections:
        d.text((8, y + 8), title, fill=(255, 220, 120, 255))
        sheet.alpha_composite(img, (0, y + 30))
        y += img.height + 30
    sheet.save(out)
    print(f"Vorschau: {out} ({sheet.width}x{sheet.height})")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pack", required=True, type=Path)
    ap.add_argument("--write", action="store_true", help="Assets nach assets/ schreiben")
    ap.add_argument("--preview", type=Path, help="Kontaktbogen-PNG erzeugen")
    args = ap.parse_args()
    if args.preview:
        preview(args.pack, args.preview)
    if args.write:
        write_assets(args.pack)


if __name__ == "__main__":
    main()
