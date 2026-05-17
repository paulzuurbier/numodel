# Changelog

All notable changes to `numodel-plot` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.0] — 2026-05-17

### Added
- Rendered example plots in the manual: a minimum working example and a
  scaling demonstration in §Usage, three axis-label-format variants and
  three `grid` variants in §Keys, and three PGFPlots-style overrides in
  §PGFPlots styles.

### Changed
- `\drawplot` now invokes `\calcplotdims` internally; user code no
  longer needs an explicit `\calcplotdims` call before `\drawplot`.
  `\calcplotdims` remains public for advanced cases (overlay TikZ,
  custom `axis` environment).
- Default `axis-label-format` is now `ieee` (the former `parens`
  option, renamed for consistency with engineering convention).
  The `parens` key has been removed.
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
