# Changelog

All notable changes to `numodel` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased] — 0.4.0

### Added
- Expression reference table in the manual (`\subsection{Expression reference}`)
  listing all l3fp operators and functions with their XMILE and CoachTaal
  equivalents, including notes on constructions for functions not natively
  available in l3fp (hyperbolic functions, base-10 logarithm, modulo).
  Cross-checked against `interface3.pdf` §30.13 (l3fp) and the Coach 7
  NL Guide (CoachTaal standard math functions and reserved-words list).
  Compared to early drafts the table now also covers `cot`/`csc`/`sec`
  and their inverses (radians and degrees, 1- and 2-argument forms where
  applicable), `fact`, `logb`, `randint`, and the constants `deg`,
  `true`, `false`.
- Display translation for eight more `\fp_eval` functions inside
  `\mrule` bodies: `sqrt`, `exp`, `ln`, `sin`, `cos`, `tan`, `asin`,
  `acos`. Under `syntax=english` these render as `SQRT(...)`,
  `EXP(...)`, `LN(...)`, `SIN(...)`, `COS(...)`, `TAN(...)`,
  `ARCSIN(...)`, `ARCCOS(...)`; under `syntax=coachtaal` as `Sqrt(...)`,
  `Exp(...)`, `Ln(...)`, `Sin(...)`, `Cos(...)`, `Tan(...)`,
  `Arcsin(...)`, `Arccos(...)`. `atan` is intentionally left
  untranslated because its 1-argument form (`atan(x)`) and 2-argument
  form (`atan(y,x)`) map to different XMILE keywords (`ARCTAN` vs
  `ARCTAN2`); similarly `min`/`max` are left untranslated because
  CoachTaal uses `;` as argument separator.
- `numodel/tests/expr-render-test.tex` — visual inspection test that
  declares one variable and one rule per l3fp operator and function,
  then renders the model under both `syntax=EN` and `syntax=NL` on
  separate prefixes, so the translated forms can be compared
  side-by-side. `\computemodel` also runs against each prefix to
  verify that every expression evaluates without error.

### Fixed
- Expression reference, CoachTaal column: replaced several invented
  keywords with the names actually in the Coach 7 reserved-words list:
  `Wortel(x)` → `Sqrt(x)`, `Geheel(x)` → `Entier(x)` (for `floor`) or
  derived (for `trunc`/`ceil`), `Afronden(x,0)` → `Round(x)`,
  `Rest(x,y)` → derived `x - Entier(x/y)*y` (CoachTaal has no native
  modulo). Function names in the CoachTaal column are now capitalised
  (`Sin`/`Cos`/`Tan`/`Arcsin`/`Arccos`/`Arctan`) and argument lists use
  semicolons (`Min(x;y)`, `Max(x;y)`). The constant `Pi` is capitalised;
  `e` is shown as the derived `Exp(1)` (CoachTaal has no `e` constant);
  `true`/`false` map to the keywords `Aan` (255) / `Uit` (0). `\verb|Als ... Dan ... Anders ...|`
  blocks now terminate with `EindAls`. `RANDOM(lo,hi)` maps to the
  derived `lo + (hi-lo)*Rand`, and `rand()` maps to the native `Rand`
  (previously labelled "not supported").
- Expression reference, degree-to-radian conversions: corrected the
  derived forms for `asind`/`acosd`/`atand` from `360/PI*...` to
  `180/PI*...` (the previous factor was off by 2). Normalised the
  forward conversions from `2*PI/360*x` to the equivalent `PI/180*x`
  throughout the table for consistency.

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
