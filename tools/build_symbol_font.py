#!/usr/bin/env python3
"""Baut die beiden Fallback-Fonts fuer UI-Symbole:

  assets/fonts/ui_emoji.ttf    farbige Emoji (COLRv1-Vektoren aus NotoColorEmoji)
  assets/fonts/ui_symbols.ttf  monochrome Geometrie/Pfeile (Noto Sans Symbols)

Hintergrund: Fuer Zeichen wie 🔥 ⚡ ★ → hat weder Clarity.ttf noch PixelOperator8
Glyphen. Auf Desktop/Android faellt Godot dafuer auf System-Fonts zurueck (Windows:
Segoe UI Emoji) - im Browser gibt es die nicht, dort erscheinen Tofu-Kaestchen.
Diese beiden Subsets werden zur Laufzeit als Fallback hinter die Projektfonts
gehaengt, siehe `ui/symbol_font.gd`.

Zwei Dateien statt einer, weil sich ein COLR-Farbfont nicht mit reinen
Outline-Fonts mergen laesst. Godot nimmt beliebig viele Fallbacks in Reihenfolge.

Aufruf:  python tools/build_symbol_font.py <verzeichnis-mit-quell-ttfs>
Quellen (OFL, siehe assets/fonts/OFL.txt):
  NotoColorEmoji.ttf  NotoSansSymbols-Regular-Subsetted.ttf
  NotoSansSymbols-Regular-Subsetted2.ttf  NotoSerif-Regular.ttf
"""
import glob
import io
import os
import re
import sys
import tempfile

from fontTools import merge, subset
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools.varLib import instancer

FONT_DIR = os.path.join("assets", "fonts")
OUT_EMOJI = os.path.join(FONT_DIR, "ui_emoji.ttf")
OUT_SYMBOLS = os.path.join(FONT_DIR, "ui_symbols.ttf")

UPEM = 1000  # alle Outline-Quellen darauf normalisieren, sonst bricht der Merge
EMOJI_SOURCE = "NotoColorEmoji.ttf"
# Reihenfolge = Prioritaet (erster Treffer gewinnt)
SYMBOL_SOURCES = [
    "NotoSansSymbols-Regular-Subsetted.ttf",
    "NotoSansSymbols-Regular-Subsetted2.ttf",
    "NotoSerif-Regular.ttf",
]

SKIP_DIRS = ("tests", "tools", "design_handoff")
# Typografie, die jeder normale Font hat - gehoert nicht in den Subset.
# U+FE0F (Variation Selector-16) ebenfalls nicht: HarfBuzz behandelt ihn als
# "default ignorable" und rendert ihn nie als Tofu.
IGNORE = set("–—‘’“”…„· ") | {"️"}
LITERAL = re.compile(r'"[^"]*"|\'[^\']*\'')


def collect_codepoints():
    """Alle Zeichen > U+2000 aus String-Literalen in .gd/.tscn (ohne Kommentarzeilen)."""
    cps = set()
    for pattern in ("**/*.gd", "**/*.tscn"):
        for path in glob.glob(pattern, recursive=True):
            if path.startswith(SKIP_DIRS):
                continue
            for line in io.open(path, encoding="utf-8", errors="replace"):
                if line.lstrip().startswith("#"):
                    continue
                for match in LITERAL.finditer(line):
                    for ch in match.group(0)[1:-1]:
                        if ord(ch) > 0x2000 and ch not in IGNORE:
                            cps.add(ord(ch))
    return cps


def subset_font(src_path, codepoints, out_path, drop_layout=True):
    """Schneidet genau `codepoints` aus `src_path` heraus. Gibt die Treffer zurueck."""
    font = TTFont(src_path, fontNumber=0)
    have = set(font.getBestCmap())
    take = codepoints & have
    if not take:
        return set()
    args = [src_path, "--output-file=" + out_path,
            "--unicodes=" + ",".join("U+%04X" % c for c in sorted(take)),
            "--no-hinting", "--drop-tables+=DSIG", "--name-IDs=*"]
    if drop_layout:
        args.append("--layout-features=")
    subset.main(args)
    return take


def build_emoji(src_dir, cps):
    """COLRv1-Farbemoji. Wird NICHT gemergt - Farbtabellen vertragen das nicht."""
    src = os.path.join(src_dir, EMOJI_SOURCE)
    if not os.path.exists(src):
        print("  FEHLT: %s" % src)
        return set()
    took = subset_font(src, cps, OUT_EMOJI)
    if not took:
        return set()
    print("  %-40s %3d Glyphen -> %s (%.1f KB)"
          % (EMOJI_SOURCE, len(took), OUT_EMOJI, os.path.getsize(OUT_EMOJI) / 1024))
    return took


def build_symbols(src_dir, cps):
    """Monochrome Outlines aus mehreren Quellen, zu einer Datei gemergt."""
    tmp = tempfile.mkdtemp()
    parts, covered = [], set()
    for name in SYMBOL_SOURCES:
        src = os.path.join(src_dir, name)
        if not os.path.exists(src):
            print("  FEHLT: %s" % src)
            continue
        font = TTFont(src, fontNumber=0)
        # Variable Fonts auf wght=400 festnageln, sonst scheitert der Merge.
        if "fvar" in font:
            font = instancer.instantiateVariableFont(font, {"wght": 400})
        # Quellen haben unterschiedliche unitsPerEm (1000 vs 2048) -> angleichen,
        # sonst scheitert der Merge an der head-Tabelle.
        if font["head"].unitsPerEm != UPEM:
            scale_upem(font, UPEM)
        staged = os.path.join(tmp, name)
        font.save(staged)
        take = subset_font(staged, cps - covered, staged)  # keine Dubletten
        if not take:
            continue
        covered |= take
        parts.append(staged)
        print("  %-40s %3d Glyphen" % (name, len(take)))

    if not parts:
        return set()
    if len(parts) == 1:
        TTFont(parts[0]).save(OUT_SYMBOLS)
    else:
        merge.Merger().merge(parts).save(OUT_SYMBOLS)
    print("  %-40s %3d Glyphen -> %s (%.1f KB)"
          % ("(gemergt)", len(covered), OUT_SYMBOLS, os.path.getsize(OUT_SYMBOLS) / 1024))
    return covered


def main():
    src_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    cps = collect_codepoints()
    print("Benoetigte Codepoints: %d" % len(cps))
    os.makedirs(FONT_DIR, exist_ok=True)

    # Emoji zuerst: was NotoColorEmoji farbig kann, soll auch farbig kommen -
    # das entspricht dem Desktop-Bild (Segoe UI Emoji).
    covered = build_emoji(src_dir, cps)
    covered |= build_symbols(src_dir, cps - covered)

    missing = cps - covered
    if missing:
        print("  WARNUNG ungedeckt: %s" % " ".join("U+%04X" % c for c in sorted(missing)))
    print("-> %d/%d Zeichen abgedeckt" % (len(covered), len(cps)))
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
