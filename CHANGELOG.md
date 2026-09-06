# Changelog — numodel-bundle

This file aggregates release-level changes across the whole bundle.
For module-specific entries see `numodel/CHANGELOG.md` and
`numodel-plot/CHANGELOG.md` (shipped under
`doc/latex/numodel-bundle/<module>/` in the installation tree).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
each module independently adheres to [Semantic Versioning](https://semver.org/).

## [0.9.0] — 2026-09-06

- `numodel-plot` 0.9.0 — a scaled axis now shows its power of ten as
  an SI prefix on the unit by default (`s (km)` instead of
  `s (10³ m)`), controlled by the new `scale-format` key; the new
  `halo-color` key makes the tick-label halo match the surrounding
  background automatically. Internally, `\qtyPlain` no longer patches
  siunitx internals — it is built on siunitx's documented code-level
  interface — and `\pzuIfUnitNonEngTF` derives its verdict from the
  unit's net power of ten rather than a hard-coded list of prefix
  control sequences. siunitx 3.3.8 (2023-11-06) or newer is now
  requested. See `numodel-plot/CHANGELOG.md`.
- `numodel` 0.9.0 — version-sync release; no functional changes.

## [0.8.0] — 2026-07-06

- `numodel` 0.8.0 — new `syntax=FPEVAL` rule-table rendering (aliases
  `fpeval`, `l3fp`) that shows `\mrule`/`\mstop` bodies verbatim in
  l3fp syntax instead of translating them into syllabus notation;
  ships as `numodel-FPEVAL.def`.  See `numodel/CHANGELOG.md`.
- `numodel-plot` 0.8.0 — the tick-label backing is now a
  semi-transparent halo that follows the glyph outlines of the scale
  numbers (via the new `pdfrender` dependency) instead of a filled
  rectangle, is applied only to axes drawn through the middle of the
  plot, and covers the plotted curves as well as the grid (PGFPlots
  `set layers`).  Halo colour adjustable via
  `\colorlet{numodelhalo}{<color>}`.  See `numodel-plot/CHANGELOG.md`.

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
