#!/usr/bin/env texlua

-- Build configuration for the numodel-plot module (within numodel-bundle).
-- Inherits most settings from the bundle build.lua.

-- Identify the bundle + module ------------------------------------------

bundle  = "numodel-bundle"
module  = "numodel-plot"
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

-- numodel-plot loads pgfplots; LuaLaTeX is used so the resulting
-- documentation matches what numodel itself produces.
checkengines = {"luatex"}
stdengine    = "luatex"
checkformat  = "latex"
typesetexe   = "lualatex"
unpackexe    = "luatex"
typesetruns  = 3

-- File lists -------------------------------------------------------------

-- numodel-plot-manual.tex is a stand-alone LaTeX file (no longer
-- carried inside the .dtx) and gets typeset by the `doc` target
-- via typesetfiles below.
sourcefiles  = {
  "numodel-plot.dtx",
  "numodel-plot.ins",
  "numodel-plot-manual.tex",
}
installfiles = {"numodel-plot.sty"}

-- Documentation ----------------------------------------------------------

-- Manual lives in numodel-plot-manual.tex (standalone LaTeX, no
-- longer inside the .dtx).  The .dtx itself is pure docstrip source
-- and is no longer typesettable.
typesetfiles = {"numodel-plot-manual.tex"}

-- Examples in examples/ stay in the repo for local development but
-- are NOT shipped to CTAN (kept lean: only the broodnodige files
-- end up in the upload).
textfiles    = {"README.md", "CHANGELOG.md"}

-- Regression tests ------------------------------------------------------

testfiledir = "testfiles"
