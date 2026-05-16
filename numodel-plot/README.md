# numodel-plot

A PGFPlots engine that auto-sizes plots to a whole number of tick
intervals, supports configurable axis-label formats (IEEE by default,
ISO 80000-1 selectable), and automatically selects label placement
for 1-, 2-, and 4-quadrant graphs.

Part of the `numodel` package suite, but loadable standalone as an
independent PGFPlots styling layer.

## Installation

`numodel-plot` ships as a module of the `numodel-bundle` source tree,
built with [`l3build`](https://ctan.org/pkg/l3build). From the
bundle root:

```
l3build unpack             # extract numodel-plot.sty
l3build doc                # build numodel-plot.pdf
l3build install            # copy into TEXMFHOME
```

On TeX Live, after CTAN release:

```
tlmgr install numodel-bundle
```

## Minimum working example

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

## Configuration

```latex
\numodelplotsetup{
  axis-label-format = ieee,    % ieee | iso | brackets | qty-only | unit-only
  grid              = mm-dots, % mm-dots | none | <pgfplots-style-list>
  xcmmax            = 12,      % max axis width  (cm)
  ycmmax            = 10       % max axis height (cm)
}
```

Full reference: see the package PDF (`numodel-plot.pdf`).

## Requirements

LuaLaTeX with TeX Live 2022 or later. Depends on:
`expl3`, `xparse`, `l3keys2e`, `siunitx`, `pgfplots` (`compat=1.18`).

## License

LaTeX Project Public License 1.3c. See the file headers for details.

## Author

Paul Zuurbier — `mail@paulzuurbier.nl`
