# numodel-bundle

LuaLaTeX packages for writing and rendering numerical models — aimed
at physics teaching material.  The bundle currently contains two
modules:

| Module                          | Purpose                                                       |
|---------------------------------|---------------------------------------------------------------|
| [`numodel`](numodel/)           | Modelling engine: `\mvar`, `\mrule`, `\textmodel`, `\graphicmodel`, `\computemodel`, `\diagrammodel`. Forrester stock-and-flow diagrams; Euler integration in Lua. |
| [`numodel-plot`](numodel-plot/) | PGFPlots styling layer: `\drawplot`, `\calcplotdims`. Auto-sizes plots to a clean tick lattice; configurable axis-label formats (IEEE / ISO 80000-1). |

`numodel` depends on `numodel-plot` for its `\diagrammodel` command;
both modules ship together.

The bundle is pre-1.0 (current release `v0.2.0`); breaking changes
may still occur.

## Build workflow

The bundle is managed with [`l3build`](https://ctan.org/pkg/l3build).
From this directory:

```
l3build unpack             # extract .sty / .def files from .dtx
l3build doc                # typeset numodel.pdf + numodel-plot.pdf
l3build check              # run all regression tests (.lvt against .tlg)
l3build install            # copy generated files into TEXMFHOME
l3build clean              # remove generated files
l3build ctan               # build a CTAN-ready zip
```

Single-module variants are available by `cd`-ing into the module
directory and running the same target.

### Releasing a new version

Update `release_date` and `release_tag` in [`build.lua`](build.lua),
then run

```
l3build tag
```

to propagate the new date+version into every source file that carries
them (`.dtx` `\ProvidesPackage`, `\ProvidesExplFile`, `numodel.lua`
header).  Move the `## [Unreleased]` heading in each module's
`CHANGELOG.md` to the new version section by hand.

### Per-module Lua-level tests

`numodel/tests/` contains a separate Lua test suite that exercises
`numodel.lua` directly (no LaTeX run).  Run via

```
cd numodel/tests
texlua run.lua
```

These tests are independent of the l3build regression tests in
`numodel/testfiles/`.

## Layout

```
numodel-bundle/
  build.lua           bundle-level configuration (CTAN metadata, update_tag)
  support/            shared support files (currently empty)
  numodel/
    build.lua         module configuration
    numodel.dtx       documented source
    numodel.ins       DocStrip installer
    numodel.lua       hand-written Lua iteration backend (ships as-is)
    README.md
    CHANGELOG.md
    examples/         showcase documents
    testfiles/        l3build regression tests (.lvt + .tlg)
    tests/            Lua-level unit tests (texlua run.lua)
  numodel-plot/
    build.lua         module configuration
    numodel-plot.dtx
    numodel-plot.ins
    README.md
    CHANGELOG.md
    examples/
    testfiles/
```

## License

LaTeX Project Public License 1.3c.

## Author

Paul Zuurbier — `mail@paulzuurbier.nl`
