"""Erzeugt alle Turm-Sprites in einem Rutsch.

Ausfuehren: python3 tools/spritegen/run_all.py [--preview DIR]
(muss aus tools/spritegen/ heraus laufen, siehe die einzelnen tower_*.py-Module).
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
