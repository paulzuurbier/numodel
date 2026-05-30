# Changelog — numodel-bundle

This file aggregates release-level changes across the whole bundle.
For module-specific entries see `numodel/CHANGELOG.md` and
`numodel-plot/CHANGELOG.md` (shipped under
`doc/latex/numodel-bundle/<module>/` in the installation tree).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
each module independently adheres to [Semantic Versioning](https://semver.org/).

## [0.7.0] — 2026-05-30

- `numodel` 0.7.0 — multi-prefix `\diagrammodel` (one diagram across
  several model prefixes); `\textmodel` fix for multi-character
  numeric exponents (`T^{1.2}` instead of `T¹.2`); display
  translation for more expression functions inside `\mrule` bodies
  (`floor`, `ceil`, and the degree-valued and reciprocal trig
  families), rendered with slashed `\sfrac` fractions (new `xfrac`
  dependency).  See `numodel/CHANGELOG.md` for the full list.
- `numodel-plot` 0.7.0 — semi-transparent backgrounds behind tick
  labels, axis labels placed in the axis-arrow extension, and
  tick-scale-label suppression fixes.  See `numodel-plot/CHANGELOG.md`.

## [0.6.0] — 2026-05-26

- `numodel` 0.6.0 — new per-prefix accessor `\<prefix>steps`
  (iteration count $N$); `\mstep{<Name>}{<i>}` now errors on
  out-of-range indices; fix `\textmodel` regression so amsmath dots
  macros (`\cdots`, `\ldots`, …) work as `alias`/`aliasleft`/
  `aliasright` values; `\graphicmodel` auto-layout no longer leaves
  an empty middle row when the model has no auxiliary variables;
  `stockwidth` setup key (dead code) removed.  See
  `numodel/CHANGELOG.md` for the full list.
- `numodel-plot` 0.6.0 — version-sync bump only; no functional
  changes.  See `numodel-plot/CHANGELOG.md`.
- Build / packaging — both modules' user manuals moved out of the
  `.dtx` into stand-alone `numodel-manual.tex` /
  `numodel-plot-manual.tex` (Arial + Lete Sans Math + Fira Mono
  fonts, tcolorbox+listings example boxes).  Examples directory no
  longer shipped to CTAN — only `.dtx`/`.ins`/`.lua`/`-manual.tex`,
  extracted `.sty`/`.def`, typeset PDFs, README and CHANGELOG.

## [0.5.0] — 2026-05-23

- `numodel` 0.5.0 — multi-series `\diagrammodel` (comma-separated
  y-variables, unit-aware filtering, colour-blind safe + greyscale-
  legible palette); shared-inflow and shared-outflow Forrester
  diagrams with curved branches; improved flow-variable heuristic
  (aux/stock wins over constant in inflow terms; parenthesised
  sub-expressions are distributed before classification).  See
  `numodel/CHANGELOG.md` for details.
- `numodel-plot` 0.5.0 — version-sync bump only; no functional
  changes.

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
