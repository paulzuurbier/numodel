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

## Architectuur

Besloten op 7 oktober 2026: **twee lagen, met een aparte module
`numodel-coach`.**

**Laag 1 — in numodel zelf: het model als platte tekst + een Lua-interface.**
- De vertaling naar Coachtaal hangt aan de syntaxisbestanden
  (`numodel-NL.def` enz.). In een aparte module zou die logica dubbel
  onderhouden moeten worden.
- Het is breder bruikbaar dan Coach: een `.txt` per model, later
  kopieerblokken of `/ActualText` (bij een overstap op Linux), of
  andere exportdoelen.
- Exportmodules lezen het model alleen via een gedocumenteerde
  Lua-functie (werknaam `numodel.get_model(prefix)`), nooit via
  interne TeX-namen (`\__numodel_…`).

**Laag 2 — module `numodel-coach`: het CMA-bestand.**
- Het formaat is niet gedocumenteerd en kan breken bij een update van
  Coach. Dan is alleen deze module stuk, niet numodel.
- Coach wordt vrijwel alleen in Nederland en Vlaanderen gebruikt; de
  meeste gebruikers van numodel hebben het niet nodig.
- Het sjabloon en de binaire schrijver horen niet in de kern.
- Laden: `\usepackage{numodel-coach}` na numodel. In tegenstelling tot
  numodel-plot (dat volledig los staat) hangt deze module af van
  numodel, met de Lua-interface als enige koppeling.
- Naam `numodel-coach` en niet `numodel-export`: het algemene deel zit
  al in laag 1. Een eventueel tweede doel krijgt een eigen module op
  dezelfde interface, bijvoorbeeld `numodel-xmile` (XMILE: open
  standaard voor systeemdynamica, gelezen door o.a. Stella en Insight
  Maker).

### Wat de Lua-kant nu al heeft en wat ontbreekt

Gecontroleerd in `numodel.lua` en `numodel.dtx` (versie 0.9.1):

| Gegeven | Nu in Lua? | Opmerking |
|---|---|---|
| variabelen in declaratievolgorde, type, rasterpositie | ja (`set_meta`) | `text` is de TeX-weergave, bijv. `v` of `F_{res}` |
| modelregels in volgorde | ja (`add_rule`) | ruwe expressie met macronamen (`\ballV + \ballG * \ballDt`), soort `calc`/`ternary` |
| stopconditie (`\mstop`) | ja (`set_stop`) | sinds 7-10-2026 |
| startwaarden | ja (`value`, `value_expr`) | sinds 7-10-2026; zonder startwaarde: `nil` |
| eenheden | ja (`unit`) | ruwe siunitx-tekst (`\m \per \s `); omzetting naar Coach-tekst nog nodig |
| significante cijfers | ja (`sigfigs`) | vijfde argument van `\mvar` |
| `\mruletext` | ja (rij `text`) | vrije TeX, niet betrouwbaar te exporteren → waarschuwing |
| aliassen | n.v.t. | alleen weergave; export gebruikt de rekenregel |

De omzetting naar NL-syntaxis gebeurt nu in TeX met regex
(`\__numodel_vars_to_display:N`) en levert wiskundemodus op (`\cdot`,
`\leqslant`, …). De platte-tekstroute heeft een eigen vertaling naar
ASCII nodig: een parallelle TeX-functie, of in Lua op de ruwe
expressie uit `add_rule`.

### Besluiten over namen en eenheden (7-10-2026)

- **Namen:** automatisch afgeleid uit de TeX-weergave:
  `F_{res}` → `F_res`, `\Delta t` → `Δt`, `\text{…}` en accolades
  weg. Geen aparte sleutel per variabele.
- **Eenheden:** via een vertaaltabel in numodel(-coach)
  (`\m\per\s` → `m/s`, `\micro\gram` → `ugram`); geen nieuwe
  sleutel of extra argument bij `\mvar`.

### Coach-conventies (uit de voorbeeldbestanden van CMA)

- Eenheden: `m/s^2`, `kg*m/s^2`, `mol/(L*s)`, `1/s`, `ugram`
  (micro als `u`), `Ohm`, `%`, ook vrije tekst als `dag` of `aantal`.
- Namen mogen `_` en blokhaken bevatten: `v_k`, `m_sat`,
  `k_heen`, `[A]`. In UTF-16 kan ook `Δ` (Coach gebruikt zelf `Δt`).
- De instelling `AngleUnits` in `Description` bepaalt graden of
  radialen; relevant voor `sind`/`cosd`.

## Plan

### Fase 1 — tekstmodel, wisselen uit (eerst doen)

Volgt de opzet in twee lagen uit [Architectuur](#architectuur).

1. ✅ **Klaar (7-10-2026, nog niet gecommit):** `numodel.get_model(prefix)` en
   `numodel.dump_model(prefix)` in `numodel.lua`; tests `m005-model-api`
   en `tests/test_model_api.lua`.
   **Laag 1 in numodel: Lua-interface.** Vul de modeltabel in
   `numodel.lua` aan tot alles wat een export nodig heeft (zie de
   tabel bij Architectuur). Bied het aan via één gedocumenteerde
   functie, bijvoorbeeld `numodel.get_model(prefix)`.
2. **Laag 1 in numodel: platte tekst.** Een uitvoerroute naast de
   huidige tabel. Die zet regels in NL-syntaxis (`Als … Dan …
   EindAls`, `Teken`, `Sqrt`, …) om zonder wiskundemodus: ASCII `*`,
   `-`, `:=`, decimale komma en `Stop`. Startwaarden krijgen hun eenheid
   als commentaar (`'m/s`). Te testen met een eenvoudige
   `.txt`-export per model.
3. **Laag 2, module `numodel-coach`: bestandsschrijver in Lua.** Port
   `cma.py` + `make_textmodel.py`:
   - bij voorkeur het sjabloon in Lua opbouwen in plaats van een
     door Coach opgeslagen bestand mee te leveren (licentie, en er staat
     nu bijvoorbeeld "FaceTime HD-camera" in);
   - vul `ModelBody`, `ModelInit`, `VarList`, en `stop`/`step` in
     `ModelXML`;
   - zet `CanSwitchModelModes` op `00` en `Mode` op `01`.
4. **Laag 2: interface**, bijvoorbeeld `\coachmodel[file=vrije-val]`
   of een sleutel in `\numodelsetup` die `numodel-coach` toevoegt. Het
   bestand komt in een map naar keuze (voor Classroom); optioneel gaat
   het als bijlage in de PDF.
5. **Testen**
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
