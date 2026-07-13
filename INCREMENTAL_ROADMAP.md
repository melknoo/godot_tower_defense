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

## Charaktere: Spielstile und Rekrutierung

### Zielbild

- Der Menuepunkt `Charaktere` wird zur Sammlungs- und Rekrutierungsuebersicht.
  Die Auswahl fuer den naechsten Run bleibt im Ablauf von `Neues Spiel`.
- Die vorhandenen Charaktere Pyromant, Kryomant, Geomant und Aeromant bleiben
  leicht verstaendliche Generalisten. Aktuell unterscheiden sie sich nur durch
  ihre Start-Ability; langfristig erhaelt jeder Charakter zusaetzlich eine
  kleine Passive und eine erhoehte Chance auf thematisch passende Ability-
  Angebote.
- Charaktere sind Seitwaertsfortschritt und neue Spielweisen, keine linearen
  Macht-Upgrades. Harte Elementbeschraenkungen sind nicht vorgesehen.
- Gesperrte Karten zeigen Name, Silhouette, Spielstil und Zielfortschritt statt
  nur `???`, damit sie als sichtbare mittelfristige Ziele funktionieren.

### Freischaltung und Waehrung

- Es gibt vorerst keine weitere ausgebbare Waehrung. Eine Figur wird durch ein
  Spielziel sichtbar freigeschaltet und danach einmalig mit Aether rekrutiert.
- Der erste zusaetzliche Charakter soll direkt als Meilenstein-Belohnung ohne
  Aetherkosten vergeben werden. So lernen Spieler das System kennen, ohne den
  ersten Charakter gegen notwendige Archivforschung abwaegen zu muessen.
- Charakterkosten bleiben moderat, weil das Archiv dauerhafte Macht verkauft,
  Charaktere dagegen vor allem Build-Vielfalt schaffen.
- Keine Charakter-Passive darf Aether oder Account-XP erhoehen. Andernfalls
  entstuende ein wirtschaftlich optimaler Farm-Charakter.
- Spaeter kann jeder Charakter eine nicht ausgebbare Meisterschaftsleiste fuer
  kosmetische Rahmen, Portraets, Titel und persoenliche Statistiken erhalten.
  Diese Meisterschaft ist keine zweite Waehrung.
- Die fuer Prestige nach Welle 50 geplante langsame Ressource bleibt vom
  normalen Charakterkader getrennt.

### Erste freischaltbare Charaktere

Die Werte sind Arbeitswerte fuer einen ersten Balance-Test. Die ersten vier
Kandidaten verwenden bereits definierte Abilities und begrenzen so den
Implementierungsumfang.

| Charakter | Start-Ability | Geplante Passive | Beispiel-Freischaltung |
| --- | --- | --- | --- |
| Aschenweberin | Inferno | Brenneffekte halten 20 Prozent laenger. | 500 Gegner besiegen; erster Meilenstein-Charakter ohne Aetherkosten. |
| Gezeitenhueter | Tsunami | Verlangsamte Gegner erleiden 8 Prozent mehr Turmschaden. | Beste Welle 10 und 90 Aether. |
| Sturmjaeger | Kettenblitz | Ein zusaetzlicher Kettensprung und 15 Prozent mehr Sprungreichweite. | Hoechste Kill-Serie 24 und 120 Aether. |
| Runenwaechter | Erdspalte | Beginnt jeden Run mit 2 zusaetzlichen Leben. | Beste Welle 15 und 160 Aether. |

Die Startleben-Passive des Runenwaechters wirkt auf die Basis und setzt weder
Tower-HP noch ein allgemeines Buff-System voraus.

### Spaetere Charaktere

- Chronomantin: `Zeitbruch` setzt Gegner einen kurzen Abschnitt auf dem Pfad
  zurueck und eroeffnet einen kontrollorientierten Spielstil.
- Arkanist: Verschiedene Elemente nacheinander zu wirken baut Resonanz auf und
  belohnt gemischte Ability-Sets.
- Konstrukteur: Uebertaktet gezielt einen einzelnen Turm und spielt staerker
  ueber Positionierung als ueber Flaechenschaden.
- Seelenhirtin: Gegner-Tode laden eine manuell ausloesbare Seelenwelle auf.

### Technische Reihenfolge fuer das Charakter-MVP

1. Charakterdaten um Passive, Unlock-Bedingung, Aetherkosten und
   Freischaltungsstatus erweitern.
2. Charakter-Freischaltungen in den persistenten Progressions-Save aufnehmen
   und eine Migration fuer bestehende Saves vorsehen.
3. Den leeren Menuepunkt `Charaktere` als Uebersicht mit Fortschritt und
   Rekrutierungsaktion umsetzen.
4. Passive Effekte zentral anwenden und die Ability-Auswahl leicht nach der
   Affinitaet des gewaehlten Charakters gewichten.
5. Kosten, Passivwerte und Unlock-Ziele in mehreren Runs testen und danach
   festschreiben.

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
