"""Erzeugt alle Turm-Sprites in einem Rutsch.

Ausfuehren: python3 tools/spritegen/run_all.py [--preview DIR] [--force]
(muss aus tools/spritegen/ heraus laufen, siehe die einzelnen tower_*.py-Module).

Die Spiel-Sprites dieser Tuerme kommen inzwischen aus dem Ninja-Adventure-Pack
(ASSETS_TODO.md §1). Ohne --force entstehen nur Previews; mit --force werden die
Pack-Sprites in assets/elemental_tower/ ueberschrieben.
"""

from __future__ import annotations

import tower_aura
import tower_cannon
import tower_steam
import tower_trapper
import tower_wizard

MODULES = [tower_wizard, tower_cannon, tower_trapper, tower_aura, tower_steam]


def main() -> None:
    for module in MODULES:
        module.main()


if __name__ == "__main__":
    main()
