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

-- Single source of truth for the current release.  Read by
-- update_tag() so a single `l3build tag` call propagates version and
-- date into every source file that carries them.  Per CTAN bundle
-- maintenance guidance, every component of the bundle uses this same
-- version; we always upload the entire bundle together to keep
-- numodel and numodel-plot in sync.
release_date = "2026/05/19"
release_tag  = "0.4.0"

function update_tag(file, content, tagname, tagdate)
  -- l3build passes the date as YYYY-MM-DD; LaTeX provides expect
  -- YYYY/MM/DD, so normalize here.
  tagdate = (tagdate or release_date):gsub("%-", "/")
  tagname = tagname or release_tag

  if file:match("%.dtx$") then
    -- \ProvidesPackage{...}[YYYY/MM/DD vX.Y.Z ...]  and
    -- \ProvidesFile{...}[YYYY/MM/DD vX.Y.Z ...]   (used by \GetFileInfo
    -- in the driver to populate \fileversion / \filedate in the title
    -- footnote).
    content = content:gsub(
      "(\\Provides[A-Za-z]+{[^}]+}%[)%d%d%d%d/%d%d/%d%d v[%d.]+",
      "%1" .. tagdate .. " v" .. tagname)
    -- \ProvidesExplFile{...}{YYYY/MM/DD}{vX.Y.Z}{...}
    content = content:gsub(
      "(\\ProvidesExplFile{[^}]+}){%d%d%d%d/%d%d/%d%d}{[v]?[%d.]+}",
      "%1{" .. tagdate .. "}{" .. tagname .. "}")
  elseif file:match("%.ins$") then
    -- copyright year line
    content = content:gsub(
      "Copyright %(C%) %d%d%d%d",
      "Copyright (C) " .. tagdate:sub(1, 4))
  elseif file:match("%.lua$") then
    -- header comment with version line, format
    --   -- numodel.lua  vX.Y.Z  YYYY/MM/DD
    content = content:gsub(
      "(%-%-%s+numodel[^\n]-%s+)v[%d.]+%s+%d%d%d%d/%d%d/%d%d",
      "%1v" .. tagname .. "  " .. tagdate)
  end

  return content
end

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
