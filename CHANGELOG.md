# Changelog — numodel-bundle

All notable changes to the bundle are documented in this file. It
covers both modules: entries are grouped per release and, within a
release, per module. Every component of the bundle carries the same
version and is released together, so a module that did not change in a
given release is listed as a version-sync entry.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the bundle adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### numodel

#### Fixed
- `\diagrammodel` broke when the unit of a y-variable is a **robust
  command with an optional argument**, such as the unit macros of
  `physunits` (loaded by `physconst`): `\DeclareRobustCommand{\V}[1][ ]{…}`.
  The y-unit went through full expansion (`\tl_set:Ne` for the
  unit-compatibility check and `\edef\ylabelunit{\tl_use:N …}` for the
  axis label), which expanded `\V` down to its `\kernel@ifnextchar` and
  failed with `Use of \reserved@a doesn't match its definition`,
  followed by some twenty follow-up errors. The x-axis was never
  affected, because `\xlabelunit` is set with `\def`. The unit tokens
  are now copied verbatim (`\tl_set:Nv`, `\exp_not:V`), so the axis
  label is unchanged and the unit comparison now compares the
  unexpanded unit text. The `unit-mismatch` warning passed the same
  tokens through `\tl_use:N` into a fully expanded message argument and
  would have failed in the same way; it now uses `\tl_to_str:N`. New
  regression test `m004-diagrammodel-robust-unit` emulates such units
  (single series, two series sharing a unit, and a unit mismatch) and
  fails on 0.9.1.

### numodel-plot

#### Added
- `scale-format=input`, a third way for a scaled axis to present its
  power of ten. The existing two rewrite the unit: `prefix` folds the
  factor into an SI prefix and `exponent` pulls *every* prefix out —
  including those the user wrote — and shows one power of ten on the
  bare unit. `input` leaves the unit exactly as written and puts the
  axis factor in front of it. For a $y$-range up to $5\times10^7$ in
  `\mega\joule\per\kilo\gram` the three read `E (TJ/kg)`,
  `E (10¹² J/kg)` and `E (10⁶ MJ/kg)`; for `\kilo\metre` scaled by
  $10^3$, `input` gives `10³ km` where `exponent` gives `10⁶ m`. Maps
  straight onto siunitx's own `prefix-mode=input`. The default stays
  `prefix`. Regression test `p005-axislabels` now runs the same
  prefixed unit through all three values.

#### Changed
- The feasibility check behind `scale-format=prefix` — "can 10^k be
  folded into a prefix on this unit?" — now has two ways to obtain
  the parsed unit and picks one at run time. On siunitx 3.6 and newer
  it calls the new public `\siunitx_unit_parse:nN` (added for siunitx
  issue #864); on 3.5 and older it keeps reading
  `\l__siunitx_unit_parsed_prop` through the internals it always
  used. Needed because 3.6 also drops the internal
  `\__siunitx_unit_parse:n`: without the second path the `\cs_if_exist`
  guard would have shut on 3.6 and every `prefix` label would have
  silently come out in the 10^k form — `s (10³ m)` instead of
  `s (km)` — the moment 3.6 reached MiKTeX. Verified against real
  builds of siunitx 3.3.8, 3.4.14, 3.5.10 and the 3.6 development
  branch: all four render every label identically. The prefix ↔
  power-of-ten mapping is still read from siunitx's two internal
  props, which remain the package's last internal references.

## [0.9.1] — 2026-09-07

The first published release carrying the 0.9.0 work listed below it:
the 0.9.0 archive was prepared but never published, so everything
under both headings reaches users with this release.

### numodel

Version-sync release; no functional changes.

### numodel-plot

#### Fixed
- `\qtyPlain` produced wrong output on **siunitx 3.5.0 and newer**
  (released 2026-03-14). siunitx renamed the variable holding the
  current `prefix-mode` from `\l_siunitx_quantity_prefix_mode_tl` — a
  documented public variable through v3.4.14 — to
  `\l_siunitx_quantity_prefix_mode_str`, and left the old name
  declared but never assigned. 0.9.0 read only the `tl`, so it
  resolved an empty mode, matched no prefix-mode handler and fell
  through to plain `\qty`. Nothing errored: every scaled axis label
  silently gained a spurious `1`, `t (1 ks)` instead of `t (ks)`,
  which made `scale-format=prefix` — the 0.9.0 default — wrong on any
  current TeX distribution. The mode is now read from the `str` when
  it carries a value and from the `tl` otherwise, so both siunitx
  generations work. New regression test `p006-prefixmode` emulates
  both namings, so it pins the resolution order regardless of which
  siunitx is installed.

### Bundle

#### Changed
- The bundle now ships **one README and one CHANGELOG**, at the
  bundle root, on CTAN maintainer request. The per-module
  `README.md` / `CHANGELOG.md` pairs have been merged into these two
  files and removed; module-specific entries live under a per-module
  heading within each release above.

  This also settles the packaging problem that held 0.9.0 up.
  l3build's `copyctan()` copies `textfiles` flat into the package
  directory, so both modules and the bundle root wrote to the same two
  filenames and the bundle root — copied last — won; the module
  documents never reached the archive at all. The 0.9.0 archive worked
  around that with per-module subdirectories, which CTAN declined.
  With a single pair of files there is no collision left to resolve,
  so the `ctansetup.lua` helper that arranged the workaround has been
  dropped again.

## [0.9.0] — 2026-09-06

Prepared but never published: CTAN declined the archive over its
layout. Everything below ships as part of 0.9.1.

### numodel

Version-sync release; no functional changes.

### numodel-plot

#### Changed
- `\qtyPlain` no longer patches **siunitx** internals. It used to
  override `\__siunitx_number_output_integer:nnn` and
  `\__siunitx_quantity_print_unit:n` and read four internal
  variables; it is now built entirely on siunitx's documented
  code-level interface (`\siunitx_number_parse:nN`,
  `\siunitx_unit_format_extract_prefixes:nNN`,
  `\siunitx_number_adjust_exponent:Nn`, `\siunitx_number_process:NN`,
  `\siunitx_quantity_print:`, `\siunitx_print_unit:`) — the
  conclusion of the investigation behind siunitx issue #864, which
  established that the whole `prefix-mode` pipeline is already
  public. Axis labels are unchanged; the rewrite also fixes three
  cases the override got wrong:
  - `\qtyPlain{-1}{\metre}` and `\qtyPlain{<1}{\metre}` printed
    `-m` and `<m`, dropping the mantissa behind a sign or
    comparator; they now print `-1 m` and `<1 m`.
  - `\qtyPlain{1(1)}{\metre}` printed `(1)m`; a number carrying an
    uncertainty is now handed to `\qty` untouched.
  - The mantissa suppression fired only when `\qtyPlain` was reached
    through `\edef`, so a direct call under
    `prefix-mode=combine-exponent` printed `1 km` where the same
    call inside an axis label printed `km`. All three `prefix-mode`
    values now behave identically either way.
- `\pzuIfUnitNonEngTF` decides from the net power of ten siunitx
  extracts from the unit rather than from a hard-coded list of prefix
  control sequences — a list of which roughly half (`\cg`, `\dam`,
  `\hPa`, …) named control sequences siunitx does not define at all.
  Two units change verdict, both towards scaling:
  - `\centi\metre\per\centi\second` — the prefixes cancel ($10^0$),
    so the axis now scales instead of staying in `cm cs⁻¹`.
  - `\centi\metre\cubed` — `cm³` is $10^{-6}$ m³, a multiple of
    three, so a `cm³` axis now scales and is labelled `10⁻³ m³`
    instead of keeping four-digit ticks under `cm³`.
- **siunitx** is now requested with a date (`2023-11-06`, v3.3.8).
  Every function used has been public since v3.0.0, but v3.3.7 and
  v3.3.8 fixed the empty-exponent case of
  `prefix-mode=combine-exponent` and the printing of a bare `1` under
  `print-unity-mantissa=false`, both of which the scaled labels rely
  on. An older siunitx warns rather than errors.
- A scaled axis now presents its power of ten as an **SI prefix on
  the unit** by default: `s (km)` instead of `s (10³ m)`, `E (TJ/kg)`
  instead of `E (10⁶ MJ/kg)`, `m (Mg)` instead of `m (10³ kg)`. The
  fold respects unit powers (`10⁶ m²` → `km²`) and existing prefixes,
  and silently falls back to the power-of-ten form whenever no
  engineering prefix fits (`10³ m²` needs 10^1.5 per metre; `10³ m³`
  would need the non-engineering deca). Implemented with siunitx's
  `prefix-mode=combine-exponent` plus an own feasibility pre-check
  through the siunitx unit parser, because siunitx raises an error
  for non-convertible exponents and offers no public parse API yet
  (siunitx issue #864); the check is guarded so that a future siunitx
  rename degrades gracefully to the power-of-ten form.

#### Added
- New setup key `scale-format` controlling the above: `prefix` (the
  new default) folds the power of ten into the unit, `exponent`
  restores the previous `s (10³ m)` presentation.
- New setup key `halo-color` for the tick-label halo colour. The
  default `halo-color=auto` matches the halo to the surrounding
  background at every `\drawplot`: inside a `tcolorbox` it takes the
  box's `colback` (detected via the `tcblayer` nesting counter), on a
  beamer slide the colour theme's `bg`, on a page coloured through
  the `pagecolor` package `\thepagecolor`, and white otherwise. Any
  other value pins the halo to that colour
  (`\numodelplotsetup{halo-color=yellow!30}`); the resolved colour
  remains exposed as the named colour `numodelhalo`.
- Regression tests `p003-qtyplain` (the `\qtyPlain` contract across
  all three `prefix-mode` values, including the sign, comparator and
  uncertainty cases), `p004-unitnoneng` (the `\pzuIfUnitNonEngTF`
  classification, abbreviations, unit powers and cancelling prefixes
  included) and `p005-axislabels` (the label pipeline end to end:
  both `scale-format` values, a `\gram` axis, a `\centi` axis, a
  compound unit with cancelling prefixes and each of the five
  `axis-label-format` values).

## [0.8.0] — 2026-07-06

### numodel

#### Added
- `syntax=FPEVAL` (aliases `fpeval`, `l3fp`): a third rule-table
  rendering that shows each `\mrule`/`\mstop` body verbatim in l3fp
  (`\fpeval`) syntax — lowercase function names, literal `*`, `^`,
  `&&`, `||`, `?:` — typeset monospace, instead of translating it
  into XMILE/CoachTaal syllabus notation.  Variable macros still
  resolve to their `\<name>text` display names (wrapped in
  `\ensuremath` so subscripts and Greek render); the ternary is not
  expanded into `IF`/`THEN`/`ELSE` and the stop row reads
  `stop: <condition>`.  The decimal mark defaults to `point`.  Ships
  as `numodel-FPEVAL.def`.

### numodel-plot

#### Changed
- The semi-transparent white backing behind tick labels (added in
  0.7.0) is now applied **only to an axis that is drawn through the
  middle of the plot**, where curves pass behind the numbers. An axis
  placed on an edge (the default bottom/left, or the `top`/`right`
  placements used for single-sign data) leaves its labels on the white
  margin and gets no backing. In a quadrant I+IV plot, for example,
  the x-axis (middle) keeps its backing while the left-hand y-axis no
  longer carries one, so the backing no longer stands out where it
  served no purpose.
- The backing is no longer a filled rectangle but a **halo that
  follows the glyph outlines** of the scale numbers. The label is
  emitted twice: first stroke-only — a fat white pen (1.6pt, round
  joins, 80% opacity) traces the character outlines via the
  `pdfrender` package — and then the normal label on top. Between and
  around the digits the grid and curves now run through untouched
  instead of being cut off by a rectangular patch. The styles
  `numodel/xticklabel halo` and `numodel/yticklabel halo` apply this
  conditionally from `\calcplotdims`; the halo colour is the named
  colour `numodelhalo` (white by default, adjustable with
  `\colorlet{numodelhalo}{<color>}` for coloured backgrounds). New
  dependency: `pdfrender` (supported on pdfTeX and LuaTeX).
- The halo covers the plotted curves as well as the grid. Previously
  the backed tick labels were drawn before the curves, so a curve
  passing through a scale number ran *over* its backing, which only
  masked the dotted grid lines. When `\calcplotdims` places an axis
  through the middle it now activates PGFPlots layered graphics
  (`set layers`) and lifts the haloed labels onto the
  `axis descriptions` layer: the grid stays below the curves, the
  halo covers both, and the number sits on top of its own halo.

## [0.7.0] — 2026-05-30

### numodel

#### Added
- Multi-prefix `\diagrammodel`: the `prefix=` key now accepts a
  comma-separated list of prefixes, so the same set of y-variables
  can be plotted across several models in one diagram.  Series order
  is prefix-major (all y-variables of the first prefix come before
  any of the second).  When more than one prefix is supplied the
  prefix is appended in parentheses after each y-variable's display
  text in the legend, e.g. `$U_3$ (ptc)` vs `$U_3$ (pw)`.  Axis
  ranges reduce over the union of all (prefix, yvar) pairs; the unit
  filter is applied against the first prefix's first y-variable, so
  the same short names are assumed to share unit and display text
  across prefixes.  Single-prefix and bare-prefix invocations behave
  exactly as before; existing test files render byte-identical
  legends and mark layouts.
- `examples/test-multi-prefix.tex` — exercises the new feature
  alongside the legacy single-prefix paths (single yvar, multi yvar,
  multi prefix × single yvar, multi prefix × multi yvar).
- Display translation for more expression functions inside `\mrule`
  bodies, complementing the eight added in v0.4.0 (`sqrt`, `exp`,
  `ln`, `sin`, `cos`, `tan`, `asin`, `acos`):
  - `atan`, `min`, `max`, `floor`, and `ceil` (rendered as
    `ARCTAN` / `Arctan`, `MIN` / `Min`, `MAX` / `Max`, `INT` / `Entier`
    in the english / coachtaal syntax; `ceil(x)` as the l3fp identity
    `-INT(-x)` / `-Entier(-x)`).
  - Reciprocal trig `cot`, `csc`, `sec` — rendered as the slashed
    fraction `\sfrac{1}{tan(…)}`, `\sfrac{1}{sin(…)}`,
    `\sfrac{1}{cos(…)}` (l3fp has no direct token for them).  Arguments
    containing nested parentheses fall back to the older inline
    `1/tan(…)` form.
  - Inverse reciprocal trig `acsc`, `asec`, `acot` — rendered as
    `ARCSIN(\sfrac{1}{…})`, `ARCCOS(\sfrac{1}{…})`,
    `ARCTAN(\sfrac{1}{…})`.
  - Degree forward trig `sind`, `cosd`, `tand` — rendered as
    `SIN(\sfrac{\pi}{180}·…)` etc.
  - Degree inverse trig `asind`, `acosd`, `atand` — rendered as
    `\sfrac{180}{\pi}·ARCSIN(…)` etc.
  - Degree reciprocal trig `cotd`, `cscd`, `secd` — rendered as
    `\sfrac{1}{TAN(\sfrac{\pi}{180}·…)}` etc.
  - Degree inverse reciprocal trig `acscd`, `asecd`, `acotd` —
    rendered as `\sfrac{180}{\pi}·ARCSIN(\sfrac{1}{…})` etc.

  The functions whose conversion lives *inside* the parentheses
  (`acsc`/`asec`/`acot`, the `…d` reciprocals, the `…d` inverse
  reciprocals, and `ceil`) capture their argument, so a call whose
  argument itself contains parentheses is left untranslated rather
  than mis-rendered.  The two-argument `atan(y,x)` / `acot(y,x)` /
  `atand(y,x)` / `acotd(y,x)` (`ARCTAN2`) forms are not translated.
- `tests/expr-newfns-test.tex` — renders the new functions through
  `\textmodel` in both the english and coachtaal syntaxes.

#### Changed
- `\textmodel` now renders reciprocal trig functions (`cot`, `csc`,
  `sec`) as a slashed `\sfrac` fraction instead of an inline `1/…`,
  so the numerator no longer jams against a preceding term (e.g.
  `a + \sfrac{1}{sin(x)}` rather than `a + 1/sin(x)`).  Requires the
  new `xfrac` package dependency.

#### Fixed
- `\textmodel` rendering of multi-character numeric exponents.  The
  display pipeline in `\__numodel_vars_to_display:N` previously
  emitted raw `^1.2` (also `^12`, `^-3`, …) into the math-mode
  string assembled for the rule cell, so TeX math mode bound only
  the first token after `^` as the superscript: `T^1.2` typeset as
  `T¹.2` (the `.2` falling out to the baseline), `T^12` as `T¹2`.
  `\fp_eval:n`-side execution was unaffected — `\computemodel`
  always saw the full expression — so the bug was purely cosmetic
  but masked the actual rule a reader was meant to follow.  Numeric
  exponent literals (optional sign, digits, optional decimal part)
  are now wrapped in `{…}` before being typeset, so `T^1.2` reads
  `T^{1.2}` and `T^-3` reads `T^{-3}`.  Single-token literals like
  `T^4` were already correct and are now also wrapped (`T^{4}`,
  rendered identically by TeX), keeping the regex uniform.
  Explicitly braced (`^{…}`) and parenthesised (`^(…)`) exponents
  are left untouched because the regex requires a digit or sign
  immediately after `^`.

### numodel-plot

#### Added
- New example `examples/numodel-plot-example-quadrants.tex` that
  renders all nine quadrant configurations (four single-quadrant,
  four half-plane, and the full four-quadrant case) side by side, so
  the axis-line and axis-label placement rules can be inspected in
  one figure.

#### Changed
- Tick labels on both axes now render with a semi-transparent white
  background (`fill=white, fill opacity=0.8, text opacity=1, inner
  sep=1pt`) so the numbers remain optically separated from the grid
  and from plotted curves passing behind them.
- Tick labels at axis crossings are no longer hidden. The
  `numodel/axis` style sets `hide obscured x ticks=false` and
  `hide obscured y ticks=false`, so every scale number stays visible
  even where an axis line would otherwise obscure it; the new white
  background provides the visual separation from the crossing axis.
- Axis labels (quantity + unit) are now placed in the extension of
  the axis arrow rather than at the tick-label margin, in all five
  configurations where the axis line is moved off the plot edge
  (4Q, I+II, II+III, III+IV, IV+I).  The label sits exactly on the
  axis line, offset by `1em` past the arrow tip.  Previous placement
  used `xticklabel cs:1.05` / `yticklabel cs:1.05`, which positioned
  the label at the tick-label height rather than on the axis itself,
  giving an awkward diagonal offset relative to the arrow.

#### Fixed
- Tick-scale label (the `·10^n` factor that appears when a magnitude
  is extracted into the axis label) is now actually suppressed.
  The previous implementation hid it via `opacity=0` on
  `every {x,y} tick scale label`, which leaked through the new
  `text opacity=1` on the tick-label style and made the factor
  reappear near the origin.  Suppression now uses pgfplots' own
  `{x,y}tick scale label code/.code={}`, which prevents the node
  from being drawn at all (and keeps it out of the PDF text layer).

## [0.6.0] — 2026-05-26

### numodel

#### Changed (build / packaging)
- The user manual has moved out of `numodel.dtx` into a stand-alone
  `numodel-manual.tex`.  The `.dtx` is now pure docstrip source for
  `numodel.sty` / `numodel-EN.def` / `numodel-NL.def` and is no
  longer typesettable on its own.  `l3build doc` continues to build
  the manual but now compiles `numodel-manual.tex` instead of the
  `.dtx`.  No change to the package's installed files or user-facing
  API; only the build-time layout of the bundle changed.
- The `examples/` directory is no longer shipped to CTAN.  Local
  development examples stay in the repo but the CTAN upload now
  contains only the package source (.dtx/.ins/.lua/-manual.tex),
  the extracted .sty/.def, the typeset PDF, README and CHANGELOG.
  Same exclusion already in effect for `testfiles/`.

#### Added
- Per-prefix accessor `\<prefix>steps` set by `\computemodel`,
  expanding to the iteration count $N$ (= number of recorded
  samples).  Previously the count had to be derived by hand from
  e.g. `Tmax/dt`, which could be off by one depending on how
  `\mstop`'s inequality rounded.  Undefined before the first
  `\computemodel` call for that prefix.  Picking `steps` as an
  `\mvar` name now collides with this accessor (noted in the
  naming caveat of the manual).

#### Fixed
- `\textmodel` no longer raises "Undefined control sequence \DN@" /
  "\extrap@" / "\@cdots" warnings (and earlier silently scrambled
  cell contents) when an `\mvar`'s `alias`, `aliasleft`, or
  `aliasright` key holds `\cdots`, `\ldots`, or any other amsmath
  dots macro (`\dotsb`, `\dotsm`, `\dotsc`, `\dotsi`, `\dotso`,
  `\dots`).  Two interacting causes:
  - The startcell builder used `\tl_if_blank:eTF { \use:c { ... } }`
    to test whether each alias key was set.  The `:e` variant
    fully expanded `\cdots`, triggering its `\futurelet` lookahead
    outside a math context.  Replaced by
    `\str_if_eq:eeTF { \tl_to_str:c { ... } } { }`, which
    detokenizes the accessor's body after exactly one expansion
    and compares the resulting string to the empty string.  Two
    near-misses on the way to this: `\cs_if_eq:cNTF ... \c_empty_tl`
    and `\tl_if_empty:cTF`; both turn out to be `\if_meaning:w`
    comparisons against `\c_empty_tl`, and `\cs_gset:cpe` produces
    `\long\xdef` macros whose meaning never matches the
    non-`\long` `\c_empty_tl` — so empty-body accessors compared
    as not-empty.  The string-comparison route is prefix-agnostic.
  - When the alias value was then typeset inside the tabularray
    cell, `\cdots`'s lookahead still ran past the `$`-closer into
    document tokens (a regression introduced in v0.4.0 when
    `\textmodel` moved from plain `tabular` to `tabularray`'s
    `longtblr` — plain `tabular` did not pre-process cell contents,
    so the lookahead stayed contained).  Each alias substitution is
    now wrapped in an explicit `{...}` group so the lookahead is
    bounded to the cell.

#### Changed
- `\mstep{<Name>}{<i>}` now raises a `numodel` error when `<i>`
  falls outside the recorded range (`0..\<prefix>steps - 1` or, for
  Python-style negative indices, `-\<prefix>steps..-1`).  The
  previous behaviour was to silently expand to nothing, which let
  typo'd indices and off-by-one mistakes propagate into surrounding
  PGFPlots expressions as empty arguments.
- `\graphicmodel` auto-layout no longer leaves an empty row between
  the stocks row and the constants row when the model has no
  auxiliary variables to fill the middle row.  Constants drop down
  from `gridy=2` to `gridy=1` in that case, so simple
  stock-plus-constant models render without a vertical gap (visible
  in the `forrester` and `edu` examples of the manual's "Diagram
  styles in practice" section).
- Manual: assorted clarifications and corrections.

#### Removed
- `stockwidth` setup key and the `\halfstockwidth` macro it wrote
  to.  The value was never consumed — stock rectangles have used
  fixed `em`-based dimensions for a while — so the key only ever
  accepted input without effect.  No replacement; node sizes scale
  with the surrounding font size.

### numodel-plot

#### Changed (build / packaging)
- The user manual has moved out of `numodel-plot.dtx` into a
  stand-alone `numodel-plot-manual.tex`.  The `.dtx` is now pure
  docstrip source for `numodel-plot.sty` and is no longer
  typesettable on its own.  `l3build doc` continues to build the
  manual but now compiles `numodel-plot-manual.tex` instead of the
  `.dtx`.  Manual now uses Arial/Lete Sans Math/Fira Mono fonts
  (matching sibling `numodel`) and a tcolorbox+listings
  `plotexample` environment so each example body is shown verbatim
  and executed from a single source.  No change to the installed
  `.sty` or to the user-facing API.
- The `examples/` directory is no longer shipped to CTAN.  Local
  development examples stay in the repo but the CTAN upload now
  contains only the package source (.dtx/.ins/-manual.tex), the
  extracted .sty, the typeset PDF, README and CHANGELOG.

## [0.5.0] — 2026-05-23

### numodel

#### Added
- Multi-series `\diagrammodel`: the second argument now accepts a
  comma-separated list of y-variables.  Every entry whose `unitraw`
  matches the first one's is plotted in the same diagram as
  discrete model points (mark-only); the y-axis is scaled to the
  joint min/max of the kept series.  Entries with a non-matching
  unit are dropped and a `numodel/unit-mismatch` warning is issued.
  Series cycle through a colour-blind safe palette (Okabe & Ito,
  yellow omitted) ordered so consecutive colours differ in
  luminance as well — so they stay distinguishable on a greyscale
  printout.  The legend lists each kept variable's display text;
  the legacy single-entry form keeps the historical "model point"
  mark-only rendering unchanged.
- Shared-inflow Forrester diagrams: when one auxiliary variable is
  the inflow of more than one stock, `\graphicmodel` draws a single
  valve next to the first such stock, places the additional stocks
  side by side, and threads a curved branch (`to[bend left=30]`,
  matching the curved causal arrows) from the valve over the
  primary stock into each extra target.  Layout stays compact —
  the involved stocks share one row, no vertical stacking.
- Shared-outflow Forrester diagrams: mirror of the above for the
  outflow side.  When one variable drains more than one stock,
  the valve is placed to the right of the last-declared source
  stock and every earlier source attaches with a curved branch
  arcing back over the intervening stocks into the shared valve.
- `\flowarrowbent` / `\flowoutarrowbent` TikZ macros driving the
  curved inflow / outflow branches; both use the same
  `bend left=30` style as the existing curved causal arrows.
- New colour-blind safe palette `numodelseriesa`…`numodelseriesg`
  (Okabe & Ito with yellow omitted), ordered by luminance for
  greyscale legibility.  Reused as the multi-series cycle in
  `\diagrammodel`; available to user code as `\definecolor`-style
  names.
- `examples/test-multi-series.tex`,
  `examples/test-shared-inflow.tex`, and
  `examples/test-ptc-heuristic.tex` — exercise the new features
  (multi-series filtering with a unit-mismatch warning, shared
  inflow, and the PTC two-filament stocks with shared radiative
  outflow).
- Manual subsection §"Shared valves" describing the side-by-side
  layout and the curved-branch rendering for shared inflow and
  shared outflow.

#### Changed
- Flow-variable detection prefers `aux` and `stock` variables over
  `constant`s when both appear in the same inflow term.  The
  previous heuristic ("first declared wins") would mislabel an
  inflow valve as a scaling constant when that constant happened
  to be declared before the rate-bearing helper; the new rule
  picks the helper, so the valve label matches what the physics
  treats as flowing.
- Inflow term parsing now distributes top-level parenthesised
  sub-expressions of the form `(+A - B) * C` into `+A*C, -B*C`
  before flow classification.  This lets a rule such as
  `\T + (\P - \k * \T^4) * \Dt / \mc` surface `P` as the inflow
  valve and `k` as the outflow valve, instead of treating the
  whole bracket as one inflow term that masks the radiative
  `k * T^4` outflow.

#### Internal
- New Lua maps `flows.valve_extra_targets` and
  `flows.outvalve_extra_sources` track the extra stocks attached
  to a shared valve.  Exported to TeX through
  `\l__numodel_valve_extras_prop` and
  `\l__numodel_outvalve_extras_prop`.
- `auto_layout` now defers shared-valve placement to the
  designated primary source — first-declared for inflows
  (so the valve lands at the left of the stock row), last-declared
  for outflows (so it lands at the right) — and skips it for the
  other sharing stocks.  Their flow attaches with a curved branch
  emitted by `\__numodel_emit_valve_extras:n` /
  `\__numodel_emit_outvalve_extras:n`.
- `last_outflow` gap-detection in `auto_layout` now keys off
  whether the chain actually placed an outflow valve, so shared
  outflows no longer leave an empty grid cell between rows.

### numodel-plot

Version-sync release; no functional changes.

## [0.4.0] — 2026-05-19

### numodel

#### Added
- Expression reference table in the manual (`\subsection{Expression reference}`)
  listing all l3fp operators and functions with their XMILE and CoachTaal
  equivalents.
- Display translation for eight more `\fp_eval` functions inside
  `\mrule` bodies: `sqrt`, `exp`, `ln`, `sin`, `cos`, `tan`, `asin`,
  `acos`
- `\textmodel` now renders through `tabularray`'s `longtblr` (was
  plain `tabular`).  The table breaks across pages when long, the
  column header repeats on each continuation page, and continuation
  markers ("(Continued)" at the top, "Continued on next page" at the
  bottom) are localised to the current `syntax` (CoachTaal:
  "(Vervolg)" / "Wordt vervolgd op volgende pagina").
- `tblrenv` key for `\numodelsetup`, `\usepackage[tblrenv=...]{numodel}`,
  and `\textmodel[tblrenv=...]`.  Values: `tblr`, `longtblr` (default),
  `talltblr`.  Picks which `tabularray` environment wraps the table.
  Use `tblr` or `talltblr` when `\textmodel` sits inside an enclosing
  environment that already suppresses page breaks (`subfigure`,
  `minipage`, …); the default `longtblr` would otherwise emit
  spurious continuation markers in that setting.  Like `units`, the
  per-call form overrides the global only for that one render and the
  global state is restored afterwards.

#### Changed
- `numodel` now issues `\SetTblrInner{rowsep=0pt}` on package load so
  the `\textmodel` rule listing renders compactly.  This applies to
  *every* `tabularray` table in the document; users who want the
  default tabularray spacing back in their own tables can issue
  `\SetTblrInner{rowsep=2pt}` (or any other value) anywhere in their
  document.

### numodel-plot

Version-sync release; no functional changes beyond the rename below,
bumped to keep bundle component versions aligned (per CTAN's
bundle-versioning convention).

#### Changed
- Example files renamed to avoid generic filenames (CTAN maintainer
  feedback):
  - `examples/numodel-plot-simple.tex` →
    `examples/numodel-plot-example-basic.tex`
  - `examples/numodel-plot-scaled.tex` →
    `examples/numodel-plot-example-scaled.tex`

## [0.3.0] — 2026-05-17

### numodel

Version-sync release; no functional changes.

### numodel-plot

#### Added
- Rendered example plots in the manual: a minimum working example and a
  scaling demonstration in §Usage, three axis-label-format variants and
  three `grid` variants in §Keys, and three PGFPlots-style overrides in
  §PGFPlots styles.

#### Changed
- Moved `legend pos=outer north east` from `\drawplot`'s hard-coded
  axis options into the overridable `numodel/axis` style, so callers
  can change the legend position via
  `\pgfplotsset{numodel/axis/.append style={legend pos=...}}`.

#### Fixed
- `\calcplotdims` no longer emits stray `\par` tokens from blank lines
  in its source. When the macro was expanded inside a horizontal box
  (e.g. `\sbox`, a `subcaption`/`subfigure` cell), those `\par`s
  switched mode and added ~3.4 cm of empty space to the picture's
  bounding box on the left. `\drawplot` now produces a tight bounding
  box and tiles correctly in tabular/`subcaption` layouts.
- `\xlabelbuild`/`\ylabelbuild` skip the scaled-emit path (`\qtyPlain`)
  when the data magnitude lies in `[1e-2, 1e4]` and no factor-of-ten
  is needed, falling back to the simpler `\si{...}` rendering.
- Custom `grid` values passed to `\numodelplotsetup` now work as
  documented. The `grid .unknown` fallback was previously declared
  with the wrong `l3keys` syntax for a `.choice:` key (`grid .unknown`
  instead of `grid / unknown`), so any value other than `mm-dots` or
  `none` raised an "accepts only a fixed set of choices" error.

## [0.2.0] — 2026-05-16

Initial CTAN release of the bundle.

### numodel

#### Added
- `\mstep` (and `\mstepp`) accept negative indices, Python-style:
  `-1` returns the last recorded step, `-2` the penultimate, etc.
  Out-of-range indices return nothing as before. This makes
  end-of-simulation accessors writable without knowing the step
  count, e.g. `(\mstep{T}{-1}, \mstep{Y}{-1})` for the final
  $(t, y)$ pair.
- Three keys that fine-tune the Forrester diagram appearance,
  available globally via `\numodelsetup`, per-render via
  `\graphicmodel[...]`, and (for the cloud key) per-stock via
  `\mvar[...]`. Empty value resets to "follow `diagram-style`".
  - `flowarrow-style = hollow | filled` — `hollow` renders the
    classic Forrester double-line pipe with an open arrow head;
    `filled` renders a thick solid arrow. Default tracks
    `diagram-style` (`forrester` → `hollow`, otherwise `filled`).
  - `valve-style = valve | circle | edu` — `valve` draws the
    bow-tie/butterfly icon (Forrester); `circle` draws an empty
    circle; `edu` draws a labelled circle. Default tracks
    `diagram-style` (`forrester` → `valve`, otherwise `edu`).
  - `flowarrow-cloud-tip = true | false` — anchors the open end of
    inflow/outflow pipes to a cloud node (model-boundary marker).
    Default tracks `diagram-style` (`forrester` → `true`, otherwise
    `false`). Per-stock override on `\mvar` wins over the global
    default.
- `examples/test-flowarrow-11bg.tex` — exercises the three keys
  and the per-stock override.
- `examples/` directory with `free-fall.tex`, `projectile.tex`, and
  `oscillator.tex` (single-stock, two-stock, and harmonic-oscillator
  models).
- Package-time key processing: `\usepackage[syntax=english]{numodel}`
  is now wired up via `\ProcessKeyOptions`. Previously the option
  was documented but only accessible through `\numodelsetup`.
- `diagram-style` key for `\graphicmodel` and `\numodelsetup` (and
  package options), with three values:
  - `tight` (default) — current behaviour: the valve carries the
    label of the direct inflow/outflow helper or constant, and that
    helper/constant is not drawn as a separate node.
  - `forrester` — Forrester/Sterman convention: valve has no label;
    the helper/constant remains as a separate node connected to the
    valve by a causal arrow.
  - `edu` — didactic dual form: valve carries the label *and* the
    helper/constant is drawn as a separate node with a causal arrow
    to the valve.
  Passing `diagram-style=...` directly to `\graphicmodel` overrides
  the global setting for one render only; the global state is
  restored afterwards, so successive `\graphicmodel` calls can each
  pick a different style without re-issuing `\numodelsetup`.
- `examples/test-diagram-styles.tex` and
  `examples/test-diagram-styles-inline.tex` demonstrate the three
  styles side-by-side and the per-call key override.
- `units` boolean key for `\textmodel` and `\numodelsetup` (and as a
  package option), default `true`. When true, the *startwaarden*
  column of `\textmodel` renders each initial value via
  `\<prefix><Name>qty` (number + SI unit); when false, via
  `\<prefix><Name>num` (number only). Passing `units=false` directly
  to `\textmodel[units=false]` overrides the global setting for one
  render only; the global state is restored afterwards. No extra
  column is added; the unit appears inline in the existing cell.
- `examples/test-units.tex` demonstrates the default-on behaviour, the
  per-table override, the global override, and the restore.
- Localised column titles in `\textmodel`: the *startwaarden* header
  becomes "initial values" under `syntax=english` and stays
  "startwaarden" under `syntax=coachtaal`. The "model" header is
  identical in both. Implemented via two new keyword-table entries
  (`th_model`, `th_initvals`) in `\__numodel_kw:n`.
- `decimal-separator` key for `\numodelsetup` (and as a package
  option), values `comma` or `point`. Controls the decimal mark used
  in the *startwaarden* column of `\textmodel` (siunitx
  `output-decimal-marker`) and in the tick labels of `\diagrammodel`
  (pgfplots `/pgf/number format/use {comma,period}`). Default tracks
  `syntax`: `coachtaal` picks `comma`, `english` picks `point`. An
  explicit `decimal-separator=…` locks the choice and overrides any
  later `syntax` change. The override is scoped to a TeX group around
  the renderer body so a document-wide `\sisetup` is left untouched.
- `examples/test-i18n.tex` exercises both the column-title localisation
  and the decimal-separator override across the syntax/explicit-key
  matrix.

#### Changed
- `\diagrammodel` no longer needs an explicit `\calcplotdims` call
  before its internal `\drawplot` invocation. `numodel-plot` now
  performs the dimension calculation inside `\drawplot`.
- Default `syntax` is now `english` (was `coachtaal`).
- `\textmodel` *startwaarden* column now shows units by default
  (`units=true`). Previously it always rendered numbers only via
  `\<prefix><Name>num`. To restore the old number-only behaviour
  document-wide, add `\numodelsetup{units=false}`; to do it per
  render, use `\textmodel[units=false]`. The `aliasright` per-variable
  override is unaffected.
- `\textmodel` right-column header is now syntax-dependent (was
  hard-coded "startwaarden"). Documents using `syntax=english` will
  see "initial values" instead. Pass `\numodelsetup{syntax=coachtaal}`
  to keep the Dutch header.
- Default decimal mark in `\textmodel` and `\diagrammodel` now tracks
  `syntax`: a freshly loaded `\usepackage[syntax=english]{numodel}`
  document renders `0.05` and `-9.81`, where it would previously have
  inherited the user's `\sisetup`. `syntax=coachtaal` continues to
  produce `0,05` and `-9,81`. Override either with
  `\numodelsetup{decimal-separator=point|comma}`.
- `\__numodel_build_graphic:` now resets every variable's
  `gridx`/`gridy` from per-variable `gridxinit`/`gridyinit` snapshots
  recorded at `\mvar` time. This lets a model be rendered multiple
  times with different `diagram-style` values without auto-placed
  positions from a previous render being mistaken for manual
  placement.

#### Fixed
- Flow detection is now factor-aware (term-based instead of
  variable-based). A between-flow or stock-as-flow now requires the
  inflow term in one stock to be matched by a symmetric outflow term
  in the source stock — the conserved-quantity reading: stock B
  increases only because stock/source A decreases at the same rate.
  Previously, any flow variable appearing as `+fv` in one stock-rule
  and `-fv` in another was classified as a between-flow regardless
  of the surrounding factors, and any inflow whose flow var was
  itself a stock was classified as stock-as-flow regardless of
  whether the source stock actually decreased. `numodel.lua` now
  tokenises each rule into top-level additive terms and matches the
  full normalised term-string. Visible effects:
  - showcase's `EZ`/`Esys`/`dMGV` triple now renders `dMGV` as the
    between-valve from EZ to Esys (previously two unrelated valves).
  - `free-fall.tex`, `projectile.tex` and `oscillator.tex` no longer
    render their drive-stock (V, V_y, V) as a stock-as-flow into the
    integrated stock (Y, Y, X), because the drive stock does not
    decrease as the integrated stock grows. The relation is now a
    regular causal arrow.
- `\graphicmodel` no longer draws a slanted inflow arrow when a
  constant is the direct inflow of a stock. Constants now receive
  the same valve treatment as helper variables in
  `\__numodel_auto_layout:`: when detected as inflow, outflow, or
  between-flow they count as a stock for layout purposes and are
  placed adjacent to the stock on `gridy=0` instead of remaining on
  `gridy=2`.
- `\RequirePackage{float}` to support the `[H]` placement used by
  `\diagrammodel`.
- `\RequirePackage{amssymb}` for the `\leqslant`/`\geqslant` glyphs
  produced when a rule body contains `<=`/`>=`.
- Numeric output of `\<prefix><Name>num` / `\<prefix><Name>qty` no
  longer relies on the user's project-level `\sisetup` for
  `evaluate-expression`, `round-mode=figures`, or
  `exponent-mode=threshold`. These options are now passed explicitly
  to every `\num`/`\qty` call so that a standalone document with no
  `\sisetup` renders correctly. The bodies are assembled by non-expl3
  helper macros (`\NumodelDefNumCs`, `\NumodelDefQtyCs`,
  `\NumodelDefPreCs`) so that the option-string `:` separators retain
  their normal `other` catcode and siunitx's option parser can read
  them.

### numodel-plot

#### Changed
- `\drawplot` now invokes `\calcplotdims` internally; user code no
  longer needs an explicit `\calcplotdims` call before `\drawplot`.
  `\calcplotdims` remains public for advanced cases (overlay TikZ,
  custom `axis` environment).
- Default `axis-label-format` is now `ieee` (the former `parens`
  option, renamed for consistency with engineering convention).
  The `parens` key has been removed.

## [0.1] — 2026-04-24

### numodel

#### Added
- Initial release, extracted from internal project sources.
- Public API: `\newmodelprefix`, `\switchmodelprefix`, `\mvar`,
  `\mrule`, `\mruletext`, `\mstop`, `\mcoords`, `\mcoordsp`, `\mstep`,
  `\mstepp`, `\textmodel`, `\computemodel`, `\graphicmodel`,
  `\diagrammodel`.
- Bilingual rule syntax via package option `syntax=english`
  (default, XMILE-style ALL CAPS) or `syntax=coachtaal` /
  `syntax=dutch` (CoachTaal).
- Lua iteration backend (`numodel.lua`); per-prefix isolation of
  variable lists, step counters, and recorded time series.
- TikZ stock-and-flow diagram style: `stock`, `valve`, `aux`,
  `const`, `flowpipe`, `causal`, `gridscale`; helper macros
  `\flowarrow`, `\flowoutarrow`, `\flowbetweenarrow`, `\constnode`.
- Numeric output of `\textmodel` / `\computemodel` matches `siunitx`
  formatting via the user's `\sisetup` defaults.
- Optional integration with project-local `\ifinworksheet` and
  `\g_defqty_names_seq`; package functions normally without them.

### numodel-plot

#### Added
- Initial release, extracted from internal project sources.
- `\calcplotdims`, `\drawplot` — auto-sized PGFPlots rendering.
- `\numodelplotsetup` — key-value configuration for axis-label format,
  grid style, maximum axis dimensions.
- Five axis-label formats: `ieee`, `iso`, `brackets`, `qty-only`,
  `unit-only`. Automatic factor-of-ten extraction for tick magnitudes
  outside `[1e-2, 1e4]`.
- Quadrant-aware axis-line and label placement (1-, 2-, and
  4-quadrant graphs).
- Helper macros `\qtyPlain`, `\pzuIfUnitNonEngTF` exposed for reuse.
- PGFPlots styles `numodel/grid`, `numodel/ticks`, `numodel/axis`
  as project-level customisation hooks.

Pre-1.0; breaking changes may still occur before 1.0.0.
