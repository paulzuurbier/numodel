# Changelog — numodel-bundle

This file aggregates release-level changes across the whole bundle.
For module-specific entries see `numodel/CHANGELOG.md` and
`numodel-plot/CHANGELOG.md` (shipped under
`doc/latex/numodel-bundle/<module>/` in the installation tree).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
each module independently adheres to [Semantic Versioning](https://semver.org/).

## [0.4.0] — 2026-05-19

- `numodel` 0.4.0 — display translation for `sqrt`/`exp`/`ln`/`sin`/
  `cos`/`tan`/`asin`/`acos`; expression reference table in the
  manual; `\textmodel` migrated to `tabularray`'s `longtblr` with
  localised continuation markers; new `tblrenv` key (`tblr`,
  `longtblr`, `talltblr`) for `\textmodel`/`\numodelsetup`/package
  option.  See `numodel/CHANGELOG.md` for details.
- `numodel-plot` 0.4.0 — version-sync bump only; no functional
  changes.  Example files renamed from `numodel-plot-simple.tex`/
  `numodel-plot-scaled.tex` to `numodel-plot-example-basic.tex`/
  `numodel-plot-example-scaled.tex` (CTAN feedback: avoid generic
  filenames).

## [0.3.0] — 2026-05-17

- `numodel-plot` 0.3.0 — rendering-bug fixes plus worked examples in
  the manual; see `numodel-plot/CHANGELOG.md` for details.
- `numodel` 0.3.0 — version-sync bump only; no functional changes
  (CTAN convention: bundle module versions stay aligned).

## [0.2.0] — 2026-05-16

Initial CTAN release of the bundle.

- `numodel` 0.2.0 — modelling engine with `\mvar`, `\mrule`,
  `\textmodel`, `\graphicmodel`, `\computemodel`, `\diagrammodel`.
  Adds three Forrester diagram styles, units key, decimal-separator
  key, localised column titles, factor-aware flow detection, and
  Python-style negative indices in `\mstep`.
- `numodel-plot` 0.2.0 — PGFPlots styling layer with `\drawplot`
  (auto-sizing to a clean tick lattice) and `\calcplotdims`.
  Five axis-label formats: `ieee`, `iso`, `brackets`, `qty-only`,
  `unit-only`.

Pre-1.0; breaking changes may still occur before 1.0.0.
