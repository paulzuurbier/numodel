# Coach-bestanden genereren met numodel

Stand van zaken op 7 oktober 2026. Doel: bij elk model in de module
modelleren levert numodel tijdens het compileren een Coach 7-bestand
(`.cma7`) dat leerlingen direct in Coach openen. Ze hoeven dan niets
over te typen of te kopiëren uit de PDF.

## Waarom deze route

- Leerlingen werken op Chromebooks met de PDF-viewer van Chrome en de
  Coach 7-app uit de Play Store. Andere software is uitgezet.
- **Kopiëren uit de PDF (`/ActualText`) valt af.** De kolommen
  modelregels en startwaarden zijn niet los te selecteren, en Coach
  heeft daar aparte vensters voor. Ook ondersteunt Chrome
  `/ActualText` waarschijnlijk niet of maar half. Dit kan opnieuw
  bekeken worden als de school overstapt op Linux.
- **Coach-bestanden genereren werkt.** Een proefbestand voor de vrije
  val opent en rekent goed in Coach op de Chromebook (getest door Paul,
  7-10-2026).

## Bevindingen over het bestandsformaat

Het formaat is niet gedocumenteerd; dit is achterhaald uit de bestanden
in `CMA Coach Projects/NL/5. Modelleren` en uit een zelf opgeslagen
leeg tekstmodel.

- **Kop:** 16 bytes, begint met `CMA `.
- **Container:** `u64 lengte` · `0e 00 00 00 00` · `u8 naamlengte` ·
  naam · kinderen. De lengte telt het lengteveld zelf mee.
- **Blad (veld):** `u32 lengte` · `0b 00 00 00` · `u8 naamlengte` ·
  `u8 vlag` · `u8 type` · naam · waarde.
  - type `00` = byte/boolean, `02` = int32, `03` = 80-bit Extended
    (Delphi), `04` = ANSI-tekst, `06` = UTF-16LE-tekst
  - Elke tekst staat er twee keer in: `Naam` (ANSI, Δ wordt `?`) en
    `Naam_uuuu` (UTF-16).
  - Vlag `1` = lange tekst zonder naam, met 4 nulbytes vóór de tekst.
- **Geen checksum.** Alleen lengtes; die herberekent `cma.py`.
- `cma.py` leest en schrijft alle 57 voorbeeldbestanden byte voor byte
  identiek terug. `BinaryResults` wordt als ruwe bytes bewaard.

### Relevante onderdelen

| Onderdeel | Inhoud |
|---|---|
| `Description / CanSwitchModelModes` | `01` = leerling mag wisselen tussen grafisch en tekst, `00` = niet |
| `GrModMain / Mode` | `00` = grafische weergave, `01` = tekstweergave |
| `ModelXML` | het grafische model als XML (`<model xmlversion="7.1">`); **dit is de bron** |
| `ModelBody` | modelregels als platte tekst (Coachtaal, `\n` als regeleinde) |
| `ModelInit` | startwaarden als platte tekst |
| `VarList` | per variabele: `NameN`, `LabelN`, `UnitN`, `MinN`, `MaxN` (Extended), `DecimalsN` (byte); `Number` = aantal |

In `ModelXML` staan in de kop `<start>`, `<stop>`, `<step>` (met
decimale komma), `<method>Euler</method>`, `<usestopcondition>` en
`<stopcondition>`. Daarna komen `<modelobject>`'s van het type
`Independent`, `State`, `Flow` (`fig1` = bron, `fig2` = doel),
`Aux`, `Constant`, `Relation` (pijl van `fig1` naar `fig2`),
`Process` en `Comment`, elk met `label`, `expr`, `unit`, `x`/`y`
en condities (`usecondition`, `condition`, `conditiontrue`,
`conditionfalse`).

### Belangrijke valkuil

De tekstweergave is een **afgeleide** van het grafische model. Een
bestand met alleen `ModelBody`/`ModelInit` opent goed in
tekstweergave. Maar wisselt de leerling naar grafisch en terug, dan
maakt Coach de tekst opnieuw uit het (lege) `ModelXML`, en dan is het
model weg. Met `CanSwitchModelModes = 00` kan de leerling niet wisselen;
dat is getest en werkt.

## Plan

### Fase 1 — tekstmodel, wisselen uit (eerst doen)

1. **Coachtaal als platte tekst uit numodel.** Een nieuwe uitvoerroute
   naast de huidige tabel. Die zet regels in NL-syntaxis (`Als … Dan …
   EindAls`, `Teken`, `Sqrt`, …) zonder wiskundemodus om: ASCII `*`,
   `-`, `:=`, decimale komma en `Stop`. Startwaarden krijgen hun eenheid
   als commentaar (`'m/s`).
2. **Bestandsschrijver in Lua** (numodel draait al op LuaLaTeX). Port
   `cma.py` + `make_textmodel.py` naar `numodel.lua`:
   - sjabloon = het lege tekstmodel, ingebed in numodel of meegeleverd
     als bestand;
   - vul `ModelBody`, `ModelInit`, `VarList`, en `stop`/`step` in
     `ModelXML`;
   - zet `CanSwitchModelModes` op `00` en `Mode` op `01`.
3. **Interface**, bijvoorbeeld `\textmodel[coachfile=vrije-val]` of
   een sleutel in `\numodelsetup`. Het bestand komt in een map naar
   keuze (voor Classroom); optioneel gaat het als bijlage in de PDF.
4. **Testen**
   - Een regressietest die een `.cma7` maakt en controleert dat
     `cma.py` het kan teruglezen.
   - Handmatig in Coach op de Chromebook: openen, rekenen, eenheden.
   - Bijlagen in de PDF-viewer van Chrome: kan een leerling een
     bijlage openen of opslaan? Zo niet, dan alleen via de map in
     Classroom.

### Fase 2 — ook het grafische model (later, optioneel)

Vul `ModelXML` met een volledig grafisch model, zodat wisselen weer
kan. numodel heeft de gegevens al voor `\graphicmodel` (zie
`numodel.dump_layout`): het type per variabele, de rasterpositie, de
stromen per voorraad en de afhankelijkheden. Aandachtspunten:

- Na wisselen schrijft Coach de tekst in zijn eigen stijl en volgorde,
  die afwijkt van de tabel in de PDF.
- Niet elk tekstmodel past in een grafisch model (`Als…Dan`,
  tussenregels). Daar valt numodel terug op fase 1.
- Een tekstmodel rekent regel voor regel (`y := y + v*dt` gebruikt de
  nieuwe v); een grafisch model rekent alle stromen uit de oude
  waarden. De uitkomsten kunnen dus iets verschillen.

Beslis pas over fase 2 als duidelijk is hoeveel modellen in de module
ook als `\graphicmodel` voorkomen.

## Open vragen

- Welke modellen uit de module moeten een bestand krijgen, en hoe
  heten de bestanden?
- Opent de Coach-app een `.cma7` rechtstreeks vanuit Drive/Classroom
  op de Chromebook? (Getest is alleen dat de bestanden zelf werken.)
- Moet ook de instructietekst van de activiteit (`NewText`/`HTMLText`)
  gevuld worden, bijvoorbeeld met de opdracht uit de module?

## Bestanden in deze map

| Bestand | Wat |
|---|---|
| `PLAN.md` | dit document |
| `cma.py` | lezen/schrijven van het CMA-containerformaat; `python3 cma.py <bestand> dump` toont de boom |
| `make_textmodel.py` | bouwt een tekstmodel uit het sjabloon (`build(...)`) |
| `maak_vrije_val.py` | maakt de drie proefbestanden opnieuw (draaien vanuit de repo-root) |
| `vrije-val.cma7`, `vrije-val.cmr7` | proef: tekstmodel, wisselen mogelijk (model verdwijnt na wisselen) |
| `vrije-val-vast.cma7` | proef: tekstmodel, wisselen uitgezet — **dit is het doelformaat voor fase 1** |

Het sjabloon `0. Leeg model tekst.cmr7` staat in de root van de repo
(opgeslagen in Coach V7.0.723). De voorbeeldbestanden van CMA staan op
de Mac in `~/Pictures/CMA/Coach7/Full/CMA Coach Projects/NL/5. Modelleren`.
