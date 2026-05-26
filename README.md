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

The bundle is pre-1.0 (current release `v0.6.0`); breaking
changes may still occur.

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

The single source of truth for the release tag and date lives in
[`tagsetup.lua`](tagsetup.lua) at the bundle root; the bundle
`build.lua` and both module `build.lua`s dofile it so a single
`l3build tag` run propagates the values everywhere.  To bump:

```
l3build tag 0.6.0 -d 2026-08-01
```

(use a pre-release suffix such as `0.6.0-pre` or `1.0.0-rc.1` if
needed — `tagsetup.lua`'s patterns accept them).  This rewrites:

- `\ProvidesFile` / `\ProvidesPackage` / `\ProvidesExplFile` headers
  in every `.dtx`
- `Copyright (C) YYYY` lines in every `.ins`
- the version line in `numodel.lua`'s header comment
- the `release_tag` / `release_date` constants in `tagsetup.lua`
  itself, so the next run starts from the freshly-released values

After tagging, hand-edit `CHANGELOG.md` in the bundle root, in
`numodel/`, and in `numodel-plot/` to describe what changed
(changelog content is inherently human-authored, so it stays
manual), and re-run `l3build doc` to refresh the typeset PDFs.

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
  build.lua           bundle-level configuration (CTAN metadata, packaging)
  tagsetup.lua        single source of truth for release_tag/release_date
                      plus the update_tag function; dofile'd by all
                      build.lua's so `l3build tag` propagates everywhere
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
