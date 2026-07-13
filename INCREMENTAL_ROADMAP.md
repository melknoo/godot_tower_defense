# Incremental-Ausbau: Design und Umsetzungsplan

## Zielbild

Das Spiel bleibt ein aktives Tower-Defense, bekommt aber drei ineinandergreifende
Progressionsschleifen. Jede Aktion soll entweder sofort Zahlen wachsen lassen,
ein nahes Wellenziel fuettern oder dauerhaft den naechsten Run verbessern.

## Schleifen

### Sekunden: Kill-Serie

- Kills innerhalb von drei Sekunden bauen eine Serie auf.
- Alle sechs Kills steigt der Goldmultiplikator um 0,1 bis maximal 2,5.
- Jeder achte Serien-Kill erzeugt Aether; Bosse erzeugen einen groesseren Puls.
- HUD, Ablaufbalken, Goldzahl und Sound kommunizieren den Zustand unmittelbar.

### Minuten: Wellenwachstum

- Jede Welle zahlt Aether und Account-XP aus, Bosswellen deutlich mehr.
- Beste Wellen 3/5/10/15/25/40/60/100 sind dauerhafte Meilensteine.
- Bestehende Run-Perks, Ability-Upgrades, Elemente und Items bleiben die
  taktische Ebene. Das neue System ersetzt sie nicht, sondern rahmt sie.
- Freischaltbare Automation nimmt spaeter Routineklicks ab, ohne die fruehe
  Lernkurve zu ueberspringen.

### Runs: Arkanes Archiv

- Aether wird sofort persistent gutgeschrieben; ein Run-Endbonus belohnt Tiefe.
- Forschung verbessert Startgold, Leben, Supply, Schaden, Zinsen, Wellenertrag,
  Aethergewinn und Spieltempo.
- Forschung ist in drei Stufen gegliedert. Hoehere Stufen verlangen investierte
  Forschungsränge und schaffen sichtbare mittelfristige Ziele.
- Der Run-Abschluss zeigt Ertrag, Kills, hoechste Serie und dauerhaften Stand.
- Ein neuer Spielstand beginnt nur mit Schwert und Farm. Bogen, Zauberer,
  Fallensteller, Kanone und Aura werden dauerhaft im Archiv freigeschaltet.
- Turm-Freischaltungen gelten ab dem folgenden Run. Dadurch bleibt Scheitern ein
  klarer Teil der Progression und ein Kauf veraendert keinen laufenden Versuch.

## Economy-Leitplanken

- Der erste Run startet mit 60 Gold, 10 Leben und 3 Supply und ist bewusst nicht
  auf einen tiefen Durchlauf ausgelegt. Die erste Welle besteht sicher aus
  normalen Gegnern; der erste Element-Kern wartet hinter der Bosswelle 5.
- Der erste Forschungskauf ist nach wenigen Wellen erreichbar.
- Kosten wachsen exponentiell (ca. 1,55–2,0 pro Rang), Boni meist linear.
- Kampfboni bleiben klein genug, dass Run-Perks und Tower-Synergien relevant
  bleiben. Meta-Schaden startet bei 4 Prozent pro Rang.
- Bosswellen sind die wichtigsten Aether-Spikes. Der Abschlussbonus skaliert
  mit `Welle^1,35`, damit tiefere Runs effizienter als Neustart-Farming sind.
- Die Forschung `Essenz-Sieb` ist multiplikativ auf alle Aetherquellen und damit
  eine bewusste Investition in kuenftiges Wachstum.

## Art Direction

- Vorhandene Pixelassets bleiben die visuelle Sprache.
- UI-Hintergruende wechseln zu tiefem Blau-Schwarz; Cyan/Violett markieren
  persistente Magie, Gold markiert Economy, Rot unmittelbare Gefahr.
- Helle Pergamentkarten werden durch dunkle Arcane-Karten mit farbiger
  Kategorie-Kante ersetzt. Dadurch bleiben Spielwelt und UI kontrastreich.
- Zahlenhierarchie: grosse Belohnungszahl, kurze Ursache, kleiner Fortschritt.
- Animationen sind kurz (0,12–0,3 s), damit haeufige Auszahlungen knackig wirken.

## Naechste sinnvolle Ausbaustufen

1. Tower-Meisterschaft mit typgebundener XP und kosmetischen Evolutionsstufen.
2. Daily Seeds mit drei Modifikatoren und separater Bestleistung.
3. Prestige nach Welle 50 mit einer zweiten, langsameren Ressource.
4. Ereigniswellen und seltene Elitegegner als Build-Pruefungen.
5. Statistikscreen fuer DPS, Economy-Anteil und Build-Historie.

Diese Punkte sind bewusst nicht Teil der ersten Umsetzung: Erst muss die neue
Meta-Schleife balanciert und die vorhandene Featurebreite lesbar werden.
