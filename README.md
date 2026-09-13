# numodel-bundle

LuaLaTeX packages for writing and rendering numerical models — aimed
at physics teaching material.  The bundle currently contains two
modules:

| Module                          | Purpose                                                       |
|---------------------------------|---------------------------------------------------------------|
| [`numodel`](#numodel)           | Modelling engine: `\mvar`, `\mrule`, `\textmodel`, `\graphicmodel`, `\computemodel`, `\diagrammodel`. Forrester stock-and-flow diagrams; Euler integration in Lua. |
| [`numodel-plot`](#numodel-plot) | PGFPlots styling layer: `\drawplot`, `\calcplotdims`. Auto-sizes plots to a clean tick lattice; configurable axis-label formats (IEEE / ISO 80000-1). |

`numodel` depends on `numodel-plot` for its `\diagrammodel` command;
both modules ship together and carry the same version.

The bundle is pre-1.0 (current release `v0.9.1`); breaking
changes may still occur.

## Installation

On TeX Live or MiKTeX, after CTAN release:

```
tlmgr install numodel-bundle
```

From the source tree, built with
[`l3build`](https://ctan.org/pkg/l3build):

```
l3build unpack             # extract .sty / .def files from .dtx
l3build install            # copy generated files into TEXMFHOME
```

Both modules are installed together.

---

## numodel

A LuaLaTeX numerical modelling package for physics teaching material.
Define stocks, flows, and rules using a built-in keyword table — English
(XMILE-style) or Dutch (CoachTaal), with extra languages pluggable as
drop-in `numodel-<LANG>.def` files — and the package iterates the model
in Lua and renders the resulting time-series, text-mode listing, or
causal diagram.

### Minimum working example

```latex
\documentclass{article}
\usepackage[syntax=english]{numodel}     % or syntax=coachtaal
\begin{document}

\newmodelprefix{ball}
\mvar{T}{t}{0}{\s}{2}{systeem}
\mvar{Dt}{dt}{0.1}{\s}{2}{systeem}
\mvar{Y}{y}{100}{\m}{2}{voorraad}
\mvar{V}{v}{0}{\m\per\s}{2}{voorraad}
\mvar{G}{g}{-9.81}{\m\per\s\squared}{2}{constante}

\mrule{V}{\ballV + \ballG * \ballDt}
\mrule{Y}{\ballY + \ballV * \ballDt}
\mstop{\ballY <= 0}

\textmodel
\computemodel
\diagrammodel{T}{Y}{ballfall}

\end{document}
```

### Syntax options

```latex
\usepackage{numodel}                    % default: syntax=EN
\usepackage[syntax=EN]{numodel}         % XMILE-style ALL CAPS
\usepackage[syntax=NL]{numodel}         % Dutch CoachTaal
\usepackage[syntax=english]{numodel}    % legacy alias for EN
\usepackage[syntax=coachtaal]{numodel}  % legacy alias for NL
\usepackage[syntax=dutch]{numodel}      % legacy alias for NL
```

Each tag `<LANG>` loads the keyword table from `numodel-<LANG>.def` via
`kpse`. To add a third language, drop your own `numodel-XX.def` in
`TEXMFHOME/tex/latex/numodel/` and select it with
`\usepackage[syntax=XX]{numodel}` — no package rebuild required.

Full reference: see the package PDF (`numodel.pdf`).

### Requirements

LuaLaTeX with TeX Live 2022 or later. Depends on:
`expl3`, `xparse`, `l3keys2e`, `amsmath`, `tikz`, `luacode`,
`siunitx`, `numodel-plot`.

---

## numodel-plot

A PGFPlots engine that auto-sizes plots to a whole number of tick
intervals, supports configurable axis-label formats (IEEE by default,
ISO 80000-1 selectable), and automatically selects label placement
for 1-, 2-, and 4-quadrant graphs.

Part of this bundle, but loadable standalone as an independent
PGFPlots styling layer.

### Minimum working example

```latex
\documentclass{article}
\usepackage{siunitx}
\usepackage{numodel-plot}
\begin{document}
\def\xmin{0}\def\xmax{10}
\def\ymin{0}\def\ymax{5}
\def\xlabelqty{t}\def\xlabelunit{\s}
\def\ylabelqty{v}\def\ylabelunit{\m\per\s}
\drawplot{\addplot[domain=\xmin:\xmax]{0.5*x};}
\end{document}
```

`\drawplot` automatically calls `\calcplotdims` to round the axis range
to a clean tick lattice, computes axis dimensions in centimetres, and
renders a full `tikzpicture`+`axis`. Labels are built from
`\xlabelqty`+`\xlabelunit` (and the `y`-axis equivalents).

### Configuration

```latex
\numodelplotsetup{
  axis-label-format = ieee,    % ieee | iso | brackets | qty-only | unit-only
  grid              = mm-dots, % mm-dots | none | <pgfplots-style-list>
  scale-format      = prefix,  % prefix | exponent | input
  halo-color        = auto,    % auto | <colour expression>
  xcmmax            = 12,      % max axis width  (cm)
  ycmmax            = 10       % max axis height (cm)
}
```

Full reference: see the package PDF (`numodel-plot.pdf`).

### Requirements

LuaLaTeX with TeX Live 2022 or later. Depends on:
`expl3`, `xparse`, `l3keys2e`, `siunitx` (2023-11-06 / v3.3.8 or
newer), `pgfplots` (`compat=1.18`), `pdfrender`.

---

## Build workflow

The bundle is managed with [`l3build`](https://ctan.org/pkg/l3build).
From the bundle root:

```
l3build unpack             # extract .sty / .def files from .dtx
l3build doc                # typeset numodel.pdf + numodel-plot.pdf
l3build check              # run all regression tests (.lvt against .tlg)
l3build install            # copy generated files into TEXMFHOME
l3build clean              # remove generated files
l3build ctan               # build a CTAN-ready zip
```

Single-module variants are available by `cd`-ing into the module
directory and running the same target (still using the shared
`build/` tree at the bundle root).

### Releasing a new version

The single source of truth for the release tag and date lives in
[`tagsetup.lua`](tagsetup.lua) at the bundle root; the bundle
`build.lua` and both module `build.lua`s dofile it so a single
`l3build tag` run propagates the values everywhere.  To bump:

```
l3build tag 0.10.0 --date 2026-10-01
```

(use a pre-release suffix such as `0.10.0-pre` or `1.0.0-rc.1` if
needed — `tagsetup.lua`'s patterns accept them).  This rewrites:

- `\ProvidesFile` / `\ProvidesPackage` / `\ProvidesExplFile` headers
  in every `.dtx`
- `Copyright (C) YYYY` lines in every `.ins`
- the version line in `numodel.lua`'s header comment
- the `release_tag` / `release_date` constants in `tagsetup.lua`
  itself, so the next run starts from the freshly-released values

After tagging, hand-edit `CHANGELOG.md` at the bundle root to describe
what changed (changelog content is inherently human-authored, so it
stays manual), and re-run `l3build doc` to refresh the typeset PDFs.

The CTAN archive is flat and carries exactly one `README.md` and one
`CHANGELOG.md`, both from the bundle root.

### Per-module Lua-level tests

`numodel/tests/` contains a separate Lua test suite that exercises
`numodel.lua` directly (no LaTeX run).  Run via

```
cd numodel/tests
texlua run.lua
```

These tests are independent of the l3build regression tests in
`numodel/testfiles/` and `numodel-plot/testfiles/`.

## Layout

```
numodel-bundle/
  build.lua           bundle-level configuration (CTAN metadata, packaging)
  tagsetup.lua        single source of truth for release_tag/release_date
                      plus the update_tag function; dofile'd by all
                      build.lua's so `l3build tag` propagates everywhere
  README.md           this file — covers both modules
  CHANGELOG.md        one changelog for the whole bundle
  support/            shared support files (currently empty)
  numodel/
    build.lua         module configuration
    numodel.dtx       documented source
    numodel.ins       DocStrip installer
    numodel.lua       hand-written Lua iteration backend (ships as-is)
    numodel-manual.tex
    examples/         showcase documents
    testfiles/        l3build regression tests (.lvt + .tlg)
    tests/            Lua-level unit tests (texlua run.lua)
  numodel-plot/
    build.lua         module configuration
    numodel-plot.dtx
    numodel-plot.ins
    numodel-plot-manual.tex
    examples/
    testfiles/
```

## License

LaTeX Project Public License 1.3c.

## Author

Paul Zuurbier — `mail@paulzuurbier.nl`
