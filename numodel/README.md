# numodel

A LuaLaTeX numerical modelling package for physics teaching material.
Define stocks, flows, and rules using a built-in keyword table — English
(XMILE-style) or Dutch (CoachTaal), with extra languages pluggable as
drop-in `numodel-<LANG>.def` files — and the package iterates the model
in Lua and renders the resulting time-series, text-mode listing, or
causal diagram.

## Installation

`numodel` ships as a module of the `numodel-bundle` source tree,
built with [`l3build`](https://ctan.org/pkg/l3build). From the
bundle root:

```
l3build unpack             # extract numodel.sty, numodel-EN.def, numodel-NL.def
l3build doc                # build numodel.pdf
l3build install            # copy into TEXMFHOME
```

Or, from inside `numodel/`, run the same commands on just this
module (still uses the shared `build/` tree at the bundle root).

On TeX Live, after CTAN release:

```
tlmgr install numodel-bundle
```

`numodel` requires `numodel-plot` for the `\diagrammodel` command;
both packages live in the same bundle and are installed together.

## Minimum working example

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

## Syntax options

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

## Requirements

LuaLaTeX with TeX Live 2022 or later. Depends on:
`expl3`, `xparse`, `l3keys2e`, `amsmath`, `tikz`, `luacode`,
`siunitx`, `numodel-plot`.

## License

LaTeX Project Public License 1.3c. See the file headers for details.

## Author

Paul Zuurbier — `mail@paulzuurbier.nl`
