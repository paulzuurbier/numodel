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
sourcefiles = {
  "numodel.dtx",
  "numodel.ins",
  "numodel.lua",
}

-- Files produced by unpacking that should be installed into the TDS
-- tree.  numodel.lua is not produced by unpacking but is copied
-- through from sourcefiles into unpackdir, so it can be listed here.
installfiles = {
  "numodel.sty",
  "numodel-EN.def",
  "numodel-NL.def",
  "numodel.lua",
}

-- Documentation ----------------------------------------------------------

typesetfiles = {"numodel.dtx"}

-- The dtx loads `\usepackage{numodel}` to typeset its own
-- documentation, so numodel-plot must be visible during the typeset
-- run (numodel-plot ships in the sibling module).  l3build copies
-- typesetdeps into the local typesetting sandbox before compiling.
typesetdeps = {maindir .. "/numodel-plot"}
unpackdeps  = {}

-- Extra files shipped in the CTAN zip but not installed into TDS:
-- the changelog and the runnable examples directory.
textfiles    = {"README.md", "CHANGELOG.md"}
demofiles    = {"examples/*.tex", "examples/*.layout.txt"}

-- Regression tests ------------------------------------------------------

testfiledir = "testfiles"
