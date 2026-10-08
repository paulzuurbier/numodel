# numodel-bundle

LuaLaTeX packages for numerical models in physics teaching material.
You declare a model once — variables, rules, a stop condition — and
the bundle computes it and typesets it in every form a lesson needs:
the model as text, as a stock-and-flow diagram, and as graphs of the
results. It can also hand the model to the modelling software pupils
use.

The bundle is pre-1.0 (current release `v0.10.0`); breaking changes
may still occur.

| Module | Purpose |
|---|---|
| [`numodel`](#numodel) | The modelling engine: declare a model, compute it (Euler, in Lua), typeset it as a text model, a Forrester stock-and-flow diagram and graphs. |
| [`numodel-plot`](#numodel-plot) | PGFPlots layer that sizes plots to a clean tick lattice, with configurable axis-label formats. Also usable on its own. |
| [`numodel-coach`](#numodel-coach) | Exports a `numodel` model as a CMA Coach 7 modelling activity (`.cma7`). |

All modules ship together and carry the same version.

## Installation

The bundle is part of TeX Live and MiKTeX after its CTAN release:

```
tlmgr install numodel-bundle
```

All packages need **LuaLaTeX**.

## Documentation

Each package has its own manual: `numodel-manual.pdf`,
`numodel-plot-manual.pdf` and `numodel-coach-manual.pdf`
(`texdoc numodel`, `texdoc numodel-plot`, `texdoc numodel-coach`).
What changed in each release is in `CHANGELOG.md`.

---

## numodel

Declare the variables and rules of a numerical model; `numodel`
iterates it in Lua and typesets it:

- `\textmodel` — the model as text, in the notation of the syllabus:
  English (XMILE-style) or Dutch (Coachtaal), with extra languages as
  drop-in `numodel-<LANG>.def` files;
- `\graphicmodel` — the Forrester stock-and-flow diagram, laid out
  automatically from the rules;
- `\computemodel` and `\diagrammodel` — the computed results as a
  graph, with units from `siunitx`.

Quantities, units and numbers come from one declaration, so text,
diagram and graphs never disagree.

### Minimum working example

```latex
\documentclass{article}
\usepackage[syntax=EN]{numodel}       % or syntax=NL for Coachtaal
\begin{document}

\newmodelprefix{ball}
\mvar{T}{t}{0}{\s}{2}{system}
\mvar{Dt}{dt}{0.1}{\s}{2}{system}
\mvar{Y}{y}{100}{\m}{2}{stock}
\mvar{V}{v}{0}{\m\per\s}{2}{stock}
\mvar{G}{g}{-9.81}{\m\per\s\squared}{2}{constant}

\mrule{V}{\ballV + \ballG * \ballDt}
\mrule{Y}{\ballY + \ballV * \ballDt}
\mrule{T}{\ballT + \ballDt}
\mstop{\ballY <= 0}

\textmodel
\graphicmodel
\computemodel
\diagrammodel{T}{Y}{ballfall}

\end{document}
```

### Syntax options

```latex
\usepackage{numodel}                    % default: syntax=EN
\usepackage[syntax=EN]{numodel}         % XMILE-style ALL CAPS
\usepackage[syntax=NL]{numodel}         % Dutch Coachtaal
\usepackage[syntax=FPEVAL]{numodel}     % the rules as typed (l3fp)
```

`syntax=XX` loads the keyword table `numodel-XX.def`. To add a
language, put your own `numodel-XX.def` where TeX finds it and select
it with `\usepackage[syntax=XX]{numodel}`.

### Requirements

LuaLaTeX, TeX Live 2022 or later. Depends on `expl3`, `xparse`,
`l3keys2e`, `amsmath`, `amssymb`, `xfrac`, `tikz`, `luacode`,
`siunitx`, `float`, `tabularray` and `numodel-plot`.

---

## numodel-plot

A PGFPlots engine that sizes plots to a whole number of tick
intervals, supports configurable axis-label formats (IEEE by default,
ISO 80000-1 selectable), folds the power of ten of a scaled axis into
an SI prefix (`s (km)`), and places labels for 1-, 2- and 4-quadrant
graphs. `numodel` uses it for `\diagrammodel`; it also works on its
own.

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

### Requirements

LuaLaTeX, TeX Live 2022 or later. Depends on `expl3`, `xparse`,
`l3keys2e`, `siunitx` (2023-11-06 / v3.3.8 or newer), `pgfplots`
(`compat=1.18`) and `pdfrender`.

---

## numodel-coach

Writes a `numodel` model as a modelling activity for
[CMA Coach 7](https://cma-science.nl) (`.cma7`), in Coach's text mode.
Pupils open the file in Coach and get exactly the model of the text,
without retyping it from the PDF:

- the model rules and initial values in Coachtaal, with units as
  comments;
- every variable in Coach's variable list, with the axis range of its
  graph in the document;
- the iteration count from `numodel`'s `maxiter`;
- optionally an instruction text, written once in LaTeX and shown both
  in the PDF and in Coach's instruction window.

### Minimum working example

```latex
\documentclass{article}
\usepackage[syntax=NL]{numodel}
\usepackage{numodel-coach}
\begin{document}
\newmodelprefix{ball}
\mvar{T}{t}{0}{\s}{2}{systeem}
\mvar{Dt}{dt}{0.05}{\s}{2}{systeem}
\mvar{V}{v}{0}{\m\per\s}{3}{voorraad}
\mvar{Y}{y}{100}{\m}{3}{voorraad}
\mvar{G}{g}{-9.81}{\m\per\s\squared}{3}{constante}
\mrule{V}{\ballV + \ballG * \ballDt}
\mrule{Y}{\ballY + \ballV * \ballDt}
\mrule{T}{\ballT + \ballDt}
\mstop{\ballY <= 2}

\begin{coachinstruction}
Een bal valt vanuit rust van \qty{100}{\m}. Wat is de eindsnelheid?
\end{coachinstruction}

\coachinstructiontext          % the instruction in the PDF
\textmodel
\coachmodel{vrije-val}         % writes vrije-val.cma7
\end{document}
```

Options (`\coachmodel[...]` or `\coachsetup{...}`): `dir` (output
directory), `attach` (also embed the file in the PDF), `switch` (allow
switching to Coach's graphical view; off by default), `prefix`.

CMA does not document the `.cma7` format; the package was developed
against files saved by Coach 7.0 and tested with Coach 7 on
Chromebooks. Please report problems with other Coach versions.

### Requirements

LuaLaTeX; `numodel` (same version) and `embedfile`.

---

## Source code and bug reports

<https://github.com/paulzuurbier/numodel> — issues welcome. For
building and testing the bundle from source, see
[DEVELOPMENT.md](DEVELOPMENT.md) in the repository.

## License

LaTeX Project Public License 1.3c.

## Author

Paul Zuurbier — `mail@paulzuurbier.nl`
