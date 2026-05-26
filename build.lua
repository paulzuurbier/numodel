#!/usr/bin/env texlua

-- Build configuration for the numodel bundle
-- (See l3build documentation for variable reference.)

-- Bundle metadata --------------------------------------------------------

bundle = "numodel-bundle"

-- `modules` is auto-discovered by l3build from subdirectories that
-- contain a build.lua; we do not set it explicitly.

-- Engine config (`typesetexe`, `unpackexe`, `checkengines`, ...) lives
-- in each module's build.lua: l3build does not propagate those from
-- the bundle script into per-module runs.

-- File handling ----------------------------------------------------------

-- Demo + regression fixtures live in the modules but are not shipped in
-- the CTAN zip: end users get the dtx, ins, sty/def, lua, README,
-- CHANGELOG and the typeset PDF.
excludefiles = {
  "*/build",
  "*/tests",            -- developer-only Lua unit tests
  "*/testfiles",        -- developer-only l3build regression tests
  "*/examples",         -- runnable demos kept locally, not shipped
  "docs",               -- local reference PDFs, not shipped to CTAN
}

-- Bundle packaging -------------------------------------------------------

-- Preserve the per-module subdirectory layout in the source view of
-- the CTAN zip (without this, README.md/CHANGELOG.md from both
-- modules clash in a flat layout and one silently overwrites the
-- other).  The TDS view is always laid out by TDS rules regardless.
flatten = false

-- Do NOT ship a .tds.zip inside the upload archive: CTAN does not
-- require it and Erik Braun (CTAN maintainer) has asked us to omit it
-- unless a TeX distribution explicitly demands it.
packtdszip = false

-- Tagging ----------------------------------------------------------------

-- Single source of truth for `release_tag`, `release_date`,
-- `tagfiles`, and `update_tag`.  Lives in tagsetup.lua at the bundle
-- root so the bundle config AND each module config can dofile it
-- and share the same release-bump behaviour -- `l3build tag X.Y.Z`
-- then rewrites every version/date string across the whole project
-- from one source.  See tagsetup.lua for the release-bump workflow.
dofile("tagsetup.lua")

-- CTAN upload ------------------------------------------------------------

ctanpkg     = "numodel-bundle"
ctanreadme  = "README.md"

-- Read the release announcement from release-<tag>.txt when present,
-- so a fresh file per release is picked up automatically by
-- `l3build upload`.  For releases where no announcement should be
-- sent (e.g. 0.4.0), simply omit the file; the upload then proceeds
-- with an empty `announcement` field.
local function read_release_notes()
  local fname = "release-" .. release_tag .. ".txt"
  local f = io.open(fname, "r")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end

uploadconfig = {
  pkg         = ctanpkg,
  version     = "v" .. release_tag,
  author      = "Paul Zuurbier",
  uploader    = "Paul Zuurbier",
  email       = "mail@paulzuurbier.nl",
  license     = "lppl1.3c",
  summary     = "Numerical physics models with Forrester diagrams and auto-sized plots",
  description = [[
A LuaLaTeX bundle for writing and rendering numerical models
(Euler-integrated dynamical systems) directly inside LaTeX documents,
aimed at physics teaching material.  The bundle contains numodel
(the modelling engine with stock-and-flow diagrams) and numodel-plot
(a PGFPlots styling layer that auto-sizes plots to whole-number tick
intervals).
]],
  topic       = {"physics", "luatex", "diagram", "diagram-flow",
                 "graphics-plot", "pgf-tikz", "teaching", "use-luatex"},
  ctanPath    = "/macros/luatex/latex/numodel-bundle",
  repository  = "https://github.com/paulzuurbier/numodel",
  bugtracker  = "https://github.com/paulzuurbier/numodel/issues",
  announcement = read_release_notes(),
  update      = true,
}

-- l3build's stock `upload` target has no bundle_func, so on a bundle it
-- iterates submodules and looks for the CTAN zip inside each module
-- directory.  Our zip is built once at the bundle root, so make
-- `l3build upload` run there directly.
if target_list and target_list.upload then
  target_list.upload.bundle_func = upload
end
