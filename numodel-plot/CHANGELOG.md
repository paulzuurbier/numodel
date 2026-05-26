# Changelog

All notable changes to `numodel-plot` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.7.0] — 2026-05-26

### Added
- New example `examples/numodel-plot-example-quadrants.tex` that
  renders all nine quadrant configurations (four single-quadrant,
  four half-plane, and the full four-quadrant case) side by side, so
  the axis-line and axis-label placement rules can be inspected in
  one figure.

### Changed
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

### Fixed
- Tick-scale label (the `·10^n` factor that appears when a magnitude
  is extracted into the axis label) is now actually suppressed.
  The previous implementation hid it via `opacity=0` on
  `every {x,y} tick scale label`, which leaked through the new
  `text opacity=1` on the tick-label style and made the factor
  reappear near the origin.  Suppression now uses pgfplots' own
  `{x,y}tick scale label code/.code={}`, which prevents the node
  from being drawn at all (and keeps it out of the PDF text layer).

## [0.6.0] — 2026-05-26

### Changed (build / packaging)
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

Version-sync release.  No functional changes to `numodel-plot`;
bumped to keep bundle component versions aligned with `numodel`
0.5.0.

## [0.4.0] — 2026-05-19

Version-sync release.  No functional changes to `numodel-plot`;
bumped to keep bundle component versions aligned with `numodel`
0.4.0 (per CTAN's bundle-versioning convention).

### Changed
- Example files renamed to avoid generic filenames (CTAN maintainer
  feedback):
  - `examples/numodel-plot-simple.tex` →
    `examples/numodel-plot-example-basic.tex`
  - `examples/numodel-plot-scaled.tex` →
    `examples/numodel-plot-example-scaled.tex`

## [0.3.0] — 2026-05-17

### Added
- Rendered example plots in the manual: a minimum working example and a
  scaling demonstration in §Usage, three axis-label-format variants and
  three `grid` variants in §Keys, and three PGFPlots-style overrides in
  §PGFPlots styles.

### Changed
- Moved `legend pos=outer north east` from `\drawplot`'s hard-coded
  axis options into the overridable `numodel/axis` style, so callers
  can change the legend position via
  `\pgfplotsset{numodel/axis/.append style={legend pos=...}}`.

### Fixed
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

### Changed
- `\drawplot` now invokes `\calcplotdims` internally; user code no
  longer needs an explicit `\calcplotdims` call before `\drawplot`.
  `\calcplotdims` remains public for advanced cases (overlay TikZ,
  custom `axis` environment).
- Default `axis-label-format` is now `ieee` (the former `parens`
  option, renamed for consistency with engineering convention).
  The `parens` key has been removed.

## [0.1] — 2026-04-24

### Added
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
