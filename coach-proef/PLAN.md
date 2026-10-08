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

### CoachTaal volgens de handleiding

Bron: `docs/Coach_7_Guide_NL.pdf`, hoofdstuk 12 (blz. 209–222).

- **Namen:** kaal alleen `A–Z a–z 0–9` en `£ _ & ~ ! | { } [ ]`, niet
  beginnend met een cijfer, hoofdlettergevoelig. Tussen `[ ]` vervallen
  alle beperkingen (`[2πr]`). Gereserveerde woorden (lijst op blz. 212,
  hoofdletterongevoelig) mogen niet als naam. `dt`, `deltat` en `Δt`
  zijn in een tekstmodel hetzelfde. → numodel: kaal waar mogelijk,
  anders tussen haken (`[ω]`, `[Max]`); `Δt` blijft kaal.
- **Getallen:** decimaalteken volgens het besturingssysteem (komma of
  punt), mag niet met het scheidingsteken beginnen (`0,5`, niet `,5`);
  `1,5E-3`; max. 11 significante cijfers.
- **Rangorde:** unair `-` en `^` prioriteit 1, `* /` 2, `+ -` 3,
  vergelijkingen 4; gelijke prioriteit van links naar rechts. Dus
  `-x^2` = `(-x)^2` en `a^b^c` = `(a^b)^c` — anders dan l3fp.
- **Logisch:** `Niet` (1), `En` (2), `Of` (3); spaties eromheen
  verplicht; vergelijkingen in een logische expressie tussen haakjes.
  Waar/Onwaar = `Aan`/`Uit` = 255/0.
- **Vergelijkingen:** `= <> < > <= >=`.
- **Toekenning:** `:=`, `=` of `Wordt`.
- **Functies:** `Sin Cos Tan` (graden/radialen volgens instelling),
  `Arcsin Arccos Arctan` (radialen), `Exp Ln Log Sqr Sqrt Abs Entier
  Round Fac Max(x1;x2;…) Min(…) Rand Teken`, `Puls(x;b;l;h)`,
  `PulsHerhaald(x;b;l;i;h)`; argumenten gescheiden door `;`.
- **Commentaar:** niet beschreven in de handleiding. `'` werkte in de
  proef met de startwaarden; nog na te gaan in de modelregels (de
  `\mruletext`-rij wordt `' tekst`).
- **Aantal iteraties:** standaard 101, in te stellen bij
  Modelinstellingen. Coach leidt het af uit `ModelXML`:
  (`stop` − `start`)/`step` + 1. Bevestigd: 10/0,1 + 1 = 101 (leeg
  model) en 10/0,01 + 1 = 1001 (`oscillator-vast.cma7`). Een tekstmodel
  heeft zijn eigen stapgrootte in de startwaarden, dus numodel-coach
  zet `start=0`, `step=1`, `stop=N−1` (`iteration_settings` in
  `make_textmodel.py`). Te bevestigen met `iteraties-250.cma7`.

### Aantal iteraties in het Coach-bestand

Besloten op 8-10-2026: **één boekhouding, `maxiter`.** Het Coach-bestand
krijgt als aantal iteraties de waarde van `\numodelsetup{maxiter=…}`
(standaard 20000), via `numodel.get_model(p).maxiter`. De `Stop`-regel
in het model beëindigt de run; `maxiter` is alleen de bovengrens, zodat
het model blijft werken als een leerling parameters aanpast. Het aantal
stappen van `\computemodel` wordt niet gebruikt, en er komt geen aparte
sleutel per bestand: wie voor één model een ander aantal wil, zet
`\numodelsetup{maxiter=…}` vóór de export van dat model.

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
2. ✅ **Klaar (7-10-2026, nog niet gecommit):** `numodel.plaintext`,
   `plain_expr`, `plain_name`, `plain_unit`, `write_plaintext` in
   `numodel.lua`; tests `m006-plaintext` en `tests/test_plaintext.lua`.
   Te verifiëren in Coach met `oscillator-vast.cma7` (zie hieronder).
   **Laag 1 in numodel: platte tekst.** Een uitvoerroute naast de
   huidige tabel. Die zet regels in NL-syntaxis (`Als … Dan …
   EindAls`, `Teken`, `Sqrt`, …) om zonder wiskundemodus: ASCII `*`,
   `-`, `:=`, decimale komma en `Stop`. Startwaarden krijgen hun eenheid
   als commentaar (`'m/s`). Te testen met een eenvoudige
   `.txt`-export per model.
3. ✅ **Klaar (8-10-2026, nog niet gecommit):** map `numodel-coach/` met
   `numodel-coach.dtx` (`\coachmodel`, `\coachsetup`),
   `numodel-coach.lua` (schrijver, byte-identiek aan de geteste
   Python-versie), `numodel-coach-template.lua` (opgeschoond sjabloon,
   gegenereerd door `tools/gen_template.py`), handleiding en test
   `c001-coachmodel`. `attach=true` werkt (embedfile; de bijlage is
   byte-identiek aan het geschreven bestand).
   **Laag 2, module `numodel-coach`: bestandsschrijver in Lua.** Port
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

- ✅ `vrije-val-pakket.cma7` (opgeschoond sjabloon, iteraties uit
  `maxiter`) opent goed in Coach (8-10-2026).
- ✅ Bijlage in de PDF: zichtbaar in Adobe, **niet** in de PDF-viewer
  van Chrome (8-10-2026). Voor leerlingen op Chromebooks dus de map in
  Classroom; `attach` blijft als optie voor wie Adobe gebruikt.
- ✅ `instructie-test.cma7`: het instructievenster toont de opmaak
  keurig (alinea's, vet, cursief, sub/sup, lijsten, Δ, ≤, °C;
  8-10-2026).
- ✅ **VarList Min/Max/Decimalen:** alleen weergave-instellingen in
  Coach. Min/Max = asbereik van een nieuwe grafiek of meter met die
  variabele; decimalen = aantal decimalen in tabel en waardeweergave
  (Coach kent geen significante cijfers). Besluit 8-10-2026: decimalen
  blijven 2; Min/Max = het asbereik van `\diagrammodel` (dezelfde
  grafiek als in de PDF, na afronding door `\calcplotdims`; vereniging
  bij meerdere diagrammen), anders 0–10. Gebouwd; test
  `c003-axis-range`; in Coach getest met `asbereik-test.cma7`.
- ✅ **Asbereik getest in Coach** (8-10-2026): nieuwe grafieken krijgen
  de assen van de PDF.
- ✅ **CTAN:** numodel-coach gaat mee; l3build levert al een platte
  zip (gecontroleerd met `l3build ctan`). Bundelbeschrijving in
  `build.lua` en README bijgewerkt. Over CMA: geen bezwaar verwacht
  (de module bevordert het gebruik van Coach).
- ✅ **Instructietekst** (gebouwd 8-10-2026): de omgeving
  `coachinstruction` *definieert* de instructie van een model (één per
  prefix; een tweede geeft een waarschuwing) en zet niets;
  `\coachinstructiontext[prefix=…]` *toont* hem in de PDF, nul of meer
  keer; `\coachmodel` schrijft hem naar Coach. Eén bron. HTML-weergave
  in Coach getest: ziet er keurig uit.

- **Verspreiden onder leerlingen** (afweging Paul, 8-10-2026): via
  Classroom moeten leerlingen eerst doorklikken voordat de
  downloadknop verschijnt; dat moet in de klas goed worden uitgelegd.
  Een rechtstreeks gedeelde map in Google Drive is korter, maar een
  nieuwe route. Tussenvorm: de gedeelde Drive-map als link in
  Classroom plaatsen (vertrouwd beginpunt, kortere weg). Nog na te
  gaan: opent de Coach-app een `.cma7` rechtstreeks vanuit Drive op de
  Chromebook?
- Welke modellen uit de NLT-module een bestand krijgen, hoort bij het
  schrijven van die module, niet bij het pakket.

## Bestanden in deze map

| Bestand | Wat |
|---|---|
| `PLAN.md` | dit document |
| `cma.py` | lezen/schrijven van het CMA-containerformaat; `python3 cma.py <bestand> dump` toont de boom |
| `make_textmodel.py` | bouwt een tekstmodel uit het sjabloon (`build(...)`) |
| `maak_vrije_val.py` | maakt de drie proefbestanden opnieuw (draaien vanuit de repo-root) |
| `vrije-val.cma7`, `vrije-val.cmr7` | proef: tekstmodel, wisselen mogelijk (model verdwijnt na wisselen) |
| `vrije-val-vast.cma7` | proef: tekstmodel, wisselen uitgezet — **dit is het doelformaat voor fase 1** |
| `iteraties-250.cma7` | test van het aantal iteraties: harmonische trilling met Δt = 0,01 en een stopconditie bij t ≥ 10, maar 250 iteraties ingesteld. Verwacht: Modelinstellingen toont 250, de run eindigt bij t = 2,49 |
| `vrije-val-pakket.cma7`, `coachtest.pdf` | gemaakt met het pakket `numodel-coach` zelf; de PDF bevat het `.cma7` als bijlage. Getest: opent in Coach; bijlage alleen zichtbaar in Adobe |
| `instructie-test.cma7`, `instr.pdf` | test van `coachinstruction`: dezelfde tekst in de PDF en in het instructievenster van Coach. Getest: ziet er keurig uit |
| `asbereik-test.cma7`, `asbereik.pdf` | test van het asbereik uit `\diagrammodel` |
| `oscillator-vast.cma7` | test van de platte-tekstvertaling: `[ω]`, `Δt`, haakjes bij `EN`, berekende startwaarden (`k := 2*3`, `[ω] := Sqrt(k/m)`), `'`-commentaar in de modelregels; nog te testen in Coach. Het model is een syntaxtest, geen zinnige fysica |

Het sjabloon `0. Leeg model tekst.cmr7` staat in de root van de repo
(opgeslagen in Coach V7.0.723). De voorbeeldbestanden van CMA staan op
de Mac in `~/Pictures/CMA/Coach7/Full/CMA Coach Projects/NL/5. Modelleren`.
