#!/usr/bin/env texlua

-- Build configuration for the numodel module (within numodel-bundle).
-- Most settings are inherited from the bundle build.lua; this file
-- only defines what is specific to this module.

-- Identify the bundle + module ------------------------------------------

bundle  = "numodel-bundle"
module  = "numodel"
maindir = ".."

-- Tagging: share `release_tag` / `release_date` / `tagfiles` /
-- `update_tag` with the bundle and the sibling module, so a single
-- `l3build tag` propagates everywhere from one source.  See
-- ../tagsetup.lua for the workflow.
dofile(maindir .. "/tagsetup.lua")

-- CTAN packaging: share the wrapper that also copies this module's
-- README.md / CHANGELOG.md into a per-module subdirectory of the CTAN
-- package.  Without it both modules and the bundle root collide on
-- those two filenames and only the bundle root's copies survive.  See
-- ../ctansetup.lua.
dofile(maindir .. "/ctansetup.lua")

-- Engines / formats ------------------------------------------------------

-- numodel depends on LuaTeX features (luacode, the Lua iteration
-- backend), so every target uses LuaLaTeX.
checkengines = {"luatex"}
stdengine    = "luatex"
checkformat  = "latex"
typesetexe   = "lualatex"
unpackexe    = "luatex"
typesetruns  = 3

-- File lists -------------------------------------------------------------

-- Source files that l3build copies into the unpack/test sandbox.
-- numodel.lua is a hand-written companion to the .sty (not generated
-- by docstrip) and must therefore be listed alongside the .dtx/.ins.
-- numodel-manual.tex is a stand-alone LaTeX file (no longer carried
-- inside the .dtx) and gets typeset by the `doc` target via
-- typesetfiles below.
sourcefiles = {
  "numodel.dtx",
  "numodel.ins",
  "numodel.lua",
  "numodel-manual.tex",
}

-- Files produced by unpacking that should be installed into the TDS
-- tree.  numodel.lua is not produced by unpacking but is copied
-- through from sourcefiles into unpackdir, so it can be listed here.
installfiles = {
  "numodel.sty",
  "numodel-EN.def",
  "numodel-NL.def",
  "numodel-FPEVAL.def",
  "numodel.lua",
}

-- Documentation ----------------------------------------------------------

-- Manual lives in numodel-manual.tex (standalone LaTeX, no longer
-- inside the .dtx).  The .dtx itself is pure docstrip source and is
-- no longer typesettable; `l3build doc` therefore points at the
-- manual file directly.
typesetfiles = {"numodel-manual.tex"}

-- The manual loads `\usepackage{numodel}` to render live examples,
-- so numodel-plot must be visible during the typeset run
-- (numodel-plot ships in the sibling module).  l3build copies
-- typesetdeps into the local typesetting sandbox before compiling.
typesetdeps = {maindir .. "/numodel-plot"}
unpackdeps  = {}

-- Extra files shipped in the CTAN zip but not installed into TDS.
-- The runnable examples in examples/ stay in the repo for local
-- development but are NOT shipped to CTAN (kept lean: only the
-- broodnodige files end up in the upload).  See the bundle-level
-- excludefiles for the corresponding sweep.
textfiles    = {"README.md", "CHANGELOG.md"}

-- Regression tests ------------------------------------------------------

testfiledir = "testfiles"
