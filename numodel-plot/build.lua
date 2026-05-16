#!/usr/bin/env texlua

-- Build configuration for the numodel-plot module (within numodel-bundle).
-- Inherits most settings from the bundle build.lua.

-- Identify the bundle + module ------------------------------------------

bundle  = "numodel-bundle"
module  = "numodel-plot"
maindir = ".."

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

sourcefiles  = {"numodel-plot.dtx", "numodel-plot.ins"}
installfiles = {"numodel-plot.sty"}

-- Documentation ----------------------------------------------------------

typesetfiles = {"numodel-plot.dtx"}

textfiles    = {"README.md", "CHANGELOG.md"}
demofiles    = {"examples/*.tex"}

-- Regression tests ------------------------------------------------------

testfiledir = "testfiles"
