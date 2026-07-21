# Playtest-Backlog — Notizen aus einer Spielsession abarbeiten

## Kontext

Nach einer Spielsession sind neun Beobachtungen/Wünsche entstanden (Bugs, UX-Politur,
neue Features, Balancing). Dieser Plan zerlegt sie in **einzeln ausführbare Parts**,
jeweils mit konkreten Dateien/Funktionen aus der Codebase, damit jeder Part unabhängig
(auch in einer anderen Session / an einem anderen Rechner) abgearbeitet werden kann.

**Erster Ausführungsschritt:** Dieses Dokument als `playtest-backlog.md` ins Repo-Root
kopieren (neben `PROGRESS.md` / `INCREMENTAL_ROADMAP.md`). Danach Parts einzeln abhaken.

**Geklärt:**
- „Zu viel arcane" = **Aether** (persistente Essence in `ProgressionSystem`), bestätigt durch
  `PROGRESS.md` Z.11 „Economy/Aether-Werte explizit ungetuned". → Part I.
- Item-Combos (#8) = **Items kombinieren/craften** (kein reines Scrap). → Part H.

## Übersicht

| Part | Note | Typ | Aufwand | Abhängig |
|---|---|---|---|---|
| A | #4 Hover-Bug nach Equip | Bugfix | S | — |
| B | #1 Splash-Items auf Kanone | Quick-Win | XS | — |
| C | #5 Range nur bei Auswahl zeigen | UX | S | — |
| D | #2 Tower-Baumenü scrollbar | UX | S | — |
| E | #3 Equipbare Items markieren | UX | M | (A) |
| F | #7 Turm-Drag → Plätze tauschen | Feature | M | — |
| G | #6 Stats pro Turm (Kills/Schaden) | Feature | L | — |
| H | #8 Item-Kombinieren alle paar Runden | Feature | L | — |
| I | #9 Aether-Balancing | Balancing | M | — |

**Empfohlene Reihenfolge:** Phase 1 = A, B, C, D (schnelle Wins + Bug). Phase 2 = E, F.
Phase 3 = G. Phase 4 = H, I. Parts sind bewusst entkoppelt; Reihenfolge frei anpassbar.

---

## Part A — Bug: Hover im Inventar tot nach Equip (#4)

**Ziel:** Nach dem Equippen eines Items funktioniert das Hover-Detail im Inventar wieder,
ohne dass man es neu öffnen muss.

**Ursache (diagnostiziert):** Stale `selected_item` in [ui/item_inventory_ui.gd](ui/item_inventory_ui.gd).
`_on_slot_hover()` (Z. ~576-601) zeigt das Detail nur, wenn `selected_item.is_empty()` (Gates
Z. 591 & 599). Der primäre Equip-Pfad läuft über `tower_info._on_inventory_item_selected()`
([ui/tower_info.gd](ui/tower_info.gd) Z. ~335-361), der **nie** `deselect_item()` aufruft; in
[main.gd](main.gd) Z. 124-128 wird nach der Delegation an TowerInfo früh `return`t, sodass die
`deselect_item()`-Aufrufe der Fallback-Pfade (main.gd 154/171/195) nie erreicht werden. Das
equippte Item wird aus dem Inventar entfernt, `selected_item` bleibt aber gesetzt → beide
Hover-Zweige werden übersprungen.

**Vorgehen (robusteste Variante):** In `_refresh_inventory()` ([ui/item_inventory_ui.gd](ui/item_inventory_ui.gd) Z. ~478)
`selected_item` zurücksetzen, wenn dessen `uid` nicht mehr in `ItemSystem.get_inventory()` liegt.
Das fängt **alle** Equip-Pfade ab (`inventory_changed` wird bei jedem Equip ausgelöst).
Alternativ/zusätzlich: im TowerInfo-Equip-Pfad nach erfolgreichem `equip_item` ein
`item_inventory_ui.deselect_item()` aufrufen (spiegelt die Fallbacks).

**Nebenbefund (optional mitnehmen):** Das Signal `panel_closed`
([ui/item_inventory_ui.gd](ui/item_inventory_ui.gd) Z. 7/297) ist nirgends mit
`tower_info._on_inventory_panel_closed()` verbunden → `_pending_equip_slot` kann nach Wegklicken
hängen bleiben. Beim Fix mitverdrahten.

**Verifikation:** Turm wählen → Item-Slot klicken → Item equippen → über andere Inventar-Items
hovern → Detail-Panel erscheint wieder.

---

## Part B — Splash-Radius von Items auch auf Kanone (#1)

**Ziel:** Die Kanone kann Splash-Items equippen und profitiert vom Splash-Bonus.

**Befund:** Das einzige Splash-Item `blast_powder` ([autoload/item_system.gd](autoload/item_system.gd)
Z. ~151-157) hat `allowed_towers: ["fire", "earth"]` — Kanone fehlt. Die Kanone hat bereits
Basis-Splash > 0 ([data/tower_data.gd](data/tower_data.gd) Z. ~91-107, `splash: [76..156]`), damit
ist das `if splash_radius > 0`-Gate in `_apply_item_bonuses()` ([tower.gd](tower.gd) Z. ~368-370)
für die Kanone erfüllt.

**Vorgehen:** `"cannon"` zu `allowed_towers` von `blast_powder` hinzufügen. Prüfen, ob weitere
Splash-relevante Items existieren, die konsistent auch die Kanone erlauben sollten.

**Verifikation:** Kanone wählen → Sprengpulver equippen (kein Error-Sound) → Splash-Radius steigt
(sichtbar an Explosionsradius / Stats in TowerInfo).

---

## Part C — Range der Türme ausblenden, wenn nicht angeklickt (#5)

**Ziel:** Der Reichweiten-Grid wird nur beim **ausgewählten** Turm gezeigt.

**Befund:** `_update_visuals()` ([tower.gd](tower.gd) Z. ~775-805) setzt aktuell für jeden
angreifenden Turm `range_visual.visible = true` — Range ist also immer sichtbar. Auswahl
tint nur (`select()` Z. ~1712, `deselect()` Z. ~1736 via [tower_manager.gd](tower_manager.gd) Z. ~553-583).

**Vorgehen:** Default auf versteckt umstellen — in `_update_visuals()` `range_visual.visible`
(und `aura_visual.visible` für Aura-Türme) nicht mehr hart auf `true` setzen, sondern
Sichtbarkeit in `select()` (an) / `deselect()` (aus) steuern. Reichweiten-Grid weiterhin über
`RangeGridHelper.rebuild_visual` ([autoload/range_grid.gd](autoload/range_grid.gd)) aufbauen,
nur eben versteckt bis Auswahl.

**Achtung:** Die Platzierungs-**Hover**-Vorschau (`hover_range_visual` in [main.gd](main.gd)
Z. ~872-883) ist eine eigene Anzeige und bleibt unverändert.

**Verifikation:** Mehrere Türme platzieren → keine Ranges sichtbar. Einen Turm anklicken → nur
dessen Range erscheint. Woanders klicken → Range verschwindet wieder.

---

## Part D — Tower-Baumenü scrollbar (#2)

**Ziel:** Alle Türme im Baumenü erreichbar, auch per Mausrad.

**Befund:** [ui/tower_shop.gd](ui/tower_shop.gd) ist bereits **horizontal** scrollbar über
Pfeil-Buttons (`_on_scroll_left/right`, `_apply_scroll`, `clip_container`/`grid_container`,
`VISIBLE_TOWERS := 5`). Mausrad ist **nicht** verdrahtet, und Pfeile werden nur bei
`count > VISIBLE_TOWERS` gezeigt (`_update_scroll` Z. ~250).

**Vorgehen:** Mausrad-Handling ergänzen — `gui_input` auf `clip_container` (oder der Shop-Container)
abfangen: `MOUSE_BUTTON_WHEEL_UP` → `_on_scroll_left()`, `WHEEL_DOWN` → `_on_scroll_right()`.
Sicherstellen, dass bei > 5 verfügbaren Turmtypen die Pfeile sichtbar sind (ggf. `VISIBLE_TOWERS`
prüfen). Optional: Pfeile visuell deutlicher machen, falls „nicht scrollbar" nur ein
Auffindbarkeitsproblem war.

**Verifikation:** Mit mehr als 5 freigeschalteten Turmtypen über das Baumenü scrollen (Rad +
Pfeile) → alle Türme erreichbar.

---

## Part E — Im Inventar markieren, welche Items für den Turm equipbar sind (#3)

**Ziel:** Wenn ein Turm ausgewählt ist und man ein Item equippen will, sind im Inventar die
kompatiblen Items hervorgehoben (inkompatible gedimmt).

**Befund:** [ui/item_inventory_ui.gd](ui/item_inventory_ui.gd) kennt den ausgewählten Turm nicht;
Slots werden in `_fill_slot()` (Z. ~520) nur nach Rarität gefärbt. Kompatibilität liefert bereits
`ItemSystem.can_equip_on_tower(item, tower)` ([autoload/item_system.gd](autoload/item_system.gd)
Z. ~523-536).

**Vorgehen:**
1. `ItemInventoryUI` ein optionales `filter_tower`-Feld geben; beim Öffnen für Equip setzen
   (Kontext kommt aus `tower_info._try_equip_from_inventory()` [ui/tower_info.gd](ui/tower_info.gd)
   Z. ~391 bzw. `main._on_tower_selected` [main.gd](main.gd) Z. ~1141).
2. In `_fill_slot()` pro Item `can_equip_on_tower(item, filter_tower)` auswerten und Slot stylen
   (kompatibel = Rahmen/Highlight, inkompatibel = ausgegraut/reduzierte Deckkraft).
3. `filter_tower` zurücksetzen, wenn das Inventar außerhalb eines Equip-Kontexts geöffnet wird,
   sowie beim Schließen.

**Reuse:** `can_equip_on_tower` (siehe oben), `inventory_changed`/`_refresh_inventory` für Re-Render.

**Verifikation:** Turm wählen → Equip-Slot klicken → Inventar zeigt kompatible Items markiert,
andere gedimmt. Anderen Turm wählen → Markierung ändert sich entsprechend.

---

## Part F — Turm per Drag & Drop auf anderen Turm → Plätze tauschen (#7)

**Ziel:** Zieht man einen Turm auf einen belegten Platz eines anderen Turms, tauschen beide
ihre Positionen.

**Befund:** Drag existiert bereits, aber nur zum Verschieben auf **leere** Zellen. `can_relocate_to()`
([tower_manager.gd](tower_manager.gd) Z. ~150-151) liefert `false`, wenn die Zielzelle belegt ist.
Drag-Start/Drop laufen über [main.gd](main.gd) (`_check_drag_start` Z. ~564-575,
Drop in `_on_left_mouse_released` Z. ~530-541) und `pickup_tower`/`relocate_tower`
([tower_manager.gd](tower_manager.gd) Z. 159/218). Es gibt ungenutzten `combine_towers()`-Code
(Z. ~491) — **außerhalb des Scopes** (Wunsch war explizit Tauschen, nicht Kombinieren).

**Vorgehen:**
1. Neue Methode `swap_towers(from_grid, to_grid)` in [tower_manager.gd](tower_manager.gd),
   analog zu `relocate_tower()`: Einträge in `placed_towers`, `tower_levels`, `tower_placed_wave`
   für beide Zellen vertauschen, beide Turm-Nodes neu positionieren (`grid_to_world`), danach
   `_recalculate_all_tower_stats()` + `_update_blocked_towers()`.
2. Im Drop-Handler ([main.gd](main.gd) Z. ~530-541): wenn Ziel belegt (und andere Zelle als Start,
   keine aktive Welle) → `swap_towers()` statt Abbruch. `can_relocate_to()` für den Leer-Fall
   unangetastet lassen.

**Verifikation:** Ohne aktive Welle einen Turm auf einen anderen ziehen → Positionen getauscht,
Level/Items/Stats beider Türme bleiben korrekt; Blockier-/Pfadprüfung stimmt weiterhin.

---

## Part G — Stats pro Turm: Kills & Schaden (letzte Runde + gesamter Run) (#6)

**Ziel:** Pro Turm anzeigen, wie viele Gegner er gekillt und wie viel Schaden er gemacht hat —
getrennt nach **letzter Runde** und **gesamtem Run**.

**Befund:** Aktuell **keine** Zuordnung von Kills/Schaden zu einem Turm. `enemy.take_damage()`
([enemy.gd](enemy.gd) Z. ~487) bekommt nur den Turm-**Typ-String**, nicht die Instanz. Der Bullet
trägt aber bereits eine `source_tower`-Node-Referenz ([bullet.gd](bullet.gd) Z. 29, gesetzt in
[tower.gd](tower.gd) Z. ~1471). `GameState.enemy_died()` ([game_state.gd](game_state.gd) Z. ~178)
zählt nur global; `record_damage()` (Z. ~302) ist toter Code.

**Vorgehen (in 2 Teilschritten ausführbar):**

**G1 — Tracking-Backend:**
- Auf `Tower` Zähler ergänzen: `kills_run`, `kills_round`, `damage_run`, `damage_round`.
- Schaden gutschreiben: in `bullet.gd` (`_hit_single`/`_hit_splash`) und im Nahkampf
  (`_execute_melee_damage()` [tower.gd](tower.gd) Z. ~1292-1336, `self` als Verursacher) den real
  ausgeteilten Schaden auf den Verursacher-Turm addieren.
- Kills gutschreiben: `take_damage()` optional eine `source_tower`-Referenz mitgeben (oder Bullet/
  Melee erkennt „HP ≤ 0 nach diesem Treffer" und schreibt den Kill dem Verursacher gut). Bei
  `Enemy._die()` ([enemy.gd](enemy.gd) Z. ~592) den letzten Verursacher berücksichtigen.
- Reset der `*_round`-Zähler bei Wellenstart (`GameState.start_wave()` [game_state.gd](game_state.gd)
  Z. ~162 bzw. `WaveManager`) über alle platzierten Türme.

**G2 — Anzeige:** In [ui/tower_info.gd](ui/tower_info.gd) (`_update_stats_with_upgrades()` Z. ~513,
wo Live-Stats schon dargestellt werden) Zeilen für „Kills (Runde/Run)" und „Schaden (Runde/Run)"
ergänzen.

**Verifikation:** Eine Welle spielen → Turm wählen → TowerInfo zeigt Kills/Schaden der aktuellen
Runde und die Run-Summe; Runden-Werte resetten beim Start der nächsten Welle, Run-Werte laufen weiter.

---

## Part H — Items kombinieren/craften, alle paar Runden angeboten (#8)

**Ziel:** Statt viele Items nur verkaufen zu müssen, kann man Items zu stärkeren kombinieren —
angeboten in einem Panel alle paar Wellen (bestehendes Cadence-Muster wie bei Perks).

**Befund:** Es existiert **kein** Crafting — nur Verkaufen (`_on_sell_pressed`
[ui/item_inventory_ui.gd](ui/item_inventory_ui.gd) Z. ~446-468). Rundenbasierte Angebots-Panels
gibt es bereits als Muster: `should_show_upgrades(wave)` = `wave>=3 and wave%3==0`
([main.gd](main.gd) Z. ~424-427) → `wave_upgrade_ui.show_upgrades()` (Aufruf in `_on_wave_completed`
Z. ~945-949). Raritäten/Multiplikatoren liegen in `RARITIES`
([autoload/item_system.gd](autoload/item_system.gd) Z. ~19-24).

**Vorgehen (in 2 Teilschritten):**

**H1 — Combine-Logik:** `combine_items(uid_a, uid_b)` in [autoload/item_system.gd](autoload/item_system.gd),
neben `remove_item`/`equip_item`. Konkrete Default-Regel (im Code als Konstante, leicht tunbar):
zwei Items **gleicher Rarität** (optional: gleiche Kategorie) → ein Item der **nächsthöheren
Rarität**; Stat vom „besseren" der beiden übernehmen oder passend neu rollen. Beide Ausgangs-Items
entfernen, Ergebnis ins Inventar, `inventory_changed` emittieren. Reuse: `RARITIES`, `ITEMS`,
`_create_item_instance` (Z. ~435).

**H2 — UI + Cadence:** Neues Panel `ui/item_combine_ui.gd` (Vorbild: `ui/wave_upgrade_ui.gd`),
zeigt Inventar und lässt zwei kombinierbare Items auswählen. Angeboten alle N Wellen (z.B. 5) über
einen neuen Branch in `_on_wave_completed` ([main.gd](main.gd) Z. ~926) mit eigenem Cadence-Helper
analog `get_next_upgrade_wave()` (Z. ~430). Reihenfolge zu den bestehenden Post-Wave-Panels
(Ability/Perk/Core) sauber einreihen (early-return-Kette beachten).

**Offene Design-Detail-Entscheidungen (bei Ausführung festzulegen):** exakte Combine-Regel
(gleiche Kategorie erzwingen?), ob Combine Gold/Ressource kostet, Cadence-Intervall, ob im Panel
oder direkt im Inventar (Multi-Select in `_select_item`).

**Verifikation:** Bis Welle N spielen → Combine-Panel erscheint → zwei Commons kombinieren → ein
Uncommon im Inventar; Ausgangs-Items verschwunden; Inventar-UI aktualisiert.

---

## Part I — Balancing: zu viel Aether (#9)

**Ziel:** Der Aether-Zufluss (persistente Essence) wächst spät nicht mehr so stark; Progression
bleibt aber angenehm erreichbar.

**Befund:** Aether ist in [autoload/progression_system.gd](autoload/progression_system.gd)
zentral über `_award_essence()` (Z. ~283-293) verteilt und speist sich aus **fünf** gleichzeitig
skalierenden Kanälen, teils überlinear:
- Pro Kill / Streak-Meilenstein: `register_kill()` Z. ~209-215 (u. a. **+6 pro Boss**).
- Pro Welle: `register_wave_completed()` Z. ~224-228 (`base = 2 + wave/2`, jede 5. Welle `+10 + wave/5`).
- Account-Level-ups: `_add_account_xp()` Z. ~296-314 (`4 + account_level` pro Level).
- Meilensteine: `_check_milestones()` Z. ~321-328 (`8 + wave^1.15`).
- Run-Abschluss: `finish_run()` Z. ~244-262 (`round(wave^1.35 * 1.5)`).
- Alles zusätzlich mal `get_essence_multiplier()` (Z. ~503, `1 + scavenging_rank*0.10`).

**Vorgehen (iterativ, playtesting-getrieben):**
1. Hebel identifizieren (obige Formeln) — sie liegen alle in `progression_system.gd`.
2. Erste Reduktions-Runde vorschlagen und umsetzen, z.B.: Per-Wave-Base senken, Boss-`+6`
   reduzieren, Exponenten von Meilenstein/Run-Abschluss abflachen (`^1.15`/`^1.35` → näher an linear),
   ggf. Kanäle zusammenführen, damit sie sich nicht mehrfach überlagern.
3. Testlauf bis ~Welle 20 und Aether-Summe vorher/nachher vergleichen; sicherstellen, dass
   Meta-Forschung (`purchase_research`) in vernünftigem Tempo erreichbar bleibt.

**Verifikation:** Referenzlauf bis Welle ~20/30 spielen, kumulierten Aether messen; Zielkurve
soll früh belohnend, spät nicht mehr im Überfluss sein. Werte in `progression_system.gd` bündeln,
damit weiteres Nachtunen leicht ist (ergänzt `PROGRESS.md` Z. 11).

---

## Globale Verifikation / Abschluss

- Nach jedem Part: Spiel über `main.tscn` starten (Godot 4.6) und den jeweiligen Verifikations-
  schritt durchführen; keine Fehler in der Godot-Konsole.
- Nach Abschluss mehrerer Parts: `PROGRESS.md` aktualisieren (v. a. Balancing-Stand zu Aether)
  und ggf. erledigte Punkte hier abhaken.
- Reihenfolge frei; Parts sind entkoppelt. Empfohlener Start: A → B → C → D.
