# Changelog

All notable changes to `numodel` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.7.0] — Unreleased

### Added
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

### Fixed
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

## [0.6.0] — 2026-05-26

### Changed (build / packaging)
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

### Added
- Per-prefix accessor `\<prefix>steps` set by `\computemodel`,
  expanding to the iteration count $N$ (= number of recorded
  samples).  Previously the count had to be derived by hand from
  e.g. `Tmax/dt`, which could be off by one depending on how
  `\mstop`'s inequality rounded.  Undefined before the first
  `\computemodel` call for that prefix.  Picking `steps` as an
  `\mvar` name now collides with this accessor (noted in the
  naming caveat of the manual).

### Fixed
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

### Changed
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

### Removed
- `stockwidth` setup key and the `\halfstockwidth` macro it wrote
  to.  The value was never consumed — stock rectangles have used
  fixed `em`-based dimensions for a while — so the key only ever
  accepted input without effect.  No replacement; node sizes scale
  with the surrounding font size.

## [0.5.0] — 2026-05-23

### Added
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

### Changed
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

### Internal
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

## [0.4.0] — 2026-05-19

### Added
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

### Changed
- `numodel` now issues `\SetTblrInner{rowsep=0pt}` on package load so
  the `\textmodel` rule listing renders compactly.  This applies to
  *every* `tabularray` table in the document; users who want the
  default tabularray spacing back in their own tables can issue
  `\SetTblrInner{rowsep=2pt}` (or any other value) anywhere in their
  document.

## [0.3.0] — 2026-05-17

Version-sync release.  No functional changes to `numodel`; bumped to
keep bundle component versions aligned with `numodel-plot` 0.3.0 (per
CTAN's bundle-versioning convention).

## [0.2.0] — 2026-05-16

### Added
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

### Changed
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

### Fixed
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

## [0.1] — 2026-04-24

### Added
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
