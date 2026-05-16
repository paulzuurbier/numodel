# Changelog

All notable changes to `numodel-plot` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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
