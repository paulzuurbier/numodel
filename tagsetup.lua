-- ============================================================
-- tagsetup.lua — single source of truth for the release tag/date.
-- ============================================================
--
-- `l3build tag X.Y.Z [-d YYYY-MM-DD]` walks `tagfiles` and calls
-- `update_tag()` on each match.  Both are defined here so the bundle
-- build.lua AND each module build.lua can dofile this file and
-- behave identically: one tag run from the bundle root then
-- rewrites every version/date string across the whole project.
--
-- Loaded from:
--   build.lua                       (bundle root)
--   numodel/build.lua               (via maindir)
--   numodel-plot/build.lua          (via maindir)
--
-- Workflow for a release bump:
--   1. l3build tag 0.5.0 -d 2026-05-23
--      (or: l3build tag 0.5.0-pre -d 2026-05-23 for a pre-release;
--      pre-release suffixes after a dash are accepted.)
--   2. Hand-edit CHANGELOG.md in the bundle root, in numodel/, and
--      in numodel-plot/ to describe what changed.  Changelog content
--      is inherently human-authored, so it stays manual.
--   3. Re-run `l3build doc` to refresh the typeset PDFs.
--
-- Per CTAN bundle maintenance guidance, every component of the
-- bundle uses the same version; we always upload the entire bundle
-- together to keep numodel and numodel-plot in sync.

-- The default l3build `tagfiles` only matches *.dtx / *.ins.  We
-- extend it so the companion Lua module, this build script itself,
-- and the bundle README's "current release" line get the new
-- values too -- without the tagsetup.lua entry the next
-- `l3build tag` run would still read the stale release_tag /
-- release_date constants and the propagation would silently no-op.
tagfiles = {"*.dtx", "*.ins", "*.lua", "build.lua", "README.md"}

release_date = "2026/05/23"
release_tag  = "0.5.0-pre"

-- Version strings may include a pre-release suffix (`0.5.0-pre`,
-- `1.0.0-rc.2`, ...).  Pattern matches the alphanumeric + dot/dash
-- form l3build accepts on the command line.
local VERSION_PAT = "v[%w%.%-]+"

function update_tag(file, content, tagname, tagdate)
  -- l3build passes the date as YYYY-MM-DD; LaTeX `\Provides...`
  -- headers and build.lua itself use YYYY/MM/DD, so normalize here.
  tagdate = (tagdate or release_date):gsub("%-", "/")
  tagname = tagname or release_tag

  if file:match("%.dtx$") then
    -- \ProvidesPackage{...}[YYYY/MM/DD vX.Y.Z ...]  and
    -- \ProvidesFile{...}[YYYY/MM/DD vX.Y.Z ...]   (used by
    -- \GetFileInfo in the driver to populate \fileversion /
    -- \filedate in the title footnote).
    content = content:gsub(
      "(\\Provides[A-Za-z]+{[^}]+}%[)%d%d%d%d/%d%d/%d%d " .. VERSION_PAT,
      "%1" .. tagdate .. " v" .. tagname)
    -- \ProvidesExplFile{...}{YYYY/MM/DD}{vX.Y.Z}{...}  (the `v`
    -- prefix is optional in this form so accept both)
    content = content:gsub(
      "(\\ProvidesExplFile{[^}]+}){%d%d%d%d/%d%d/%d%d}{v?[%w%.%-]+}",
      "%1{" .. tagdate .. "}{" .. tagname .. "}")
  elseif file:match("%.ins$") then
    -- copyright year line
    content = content:gsub(
      "Copyright %(C%) %d%d%d%d",
      "Copyright (C) " .. tagdate:sub(1, 4))
  elseif file:match("%.lua$")
     and not file:match("build%.lua$")
     and not file:match("tagsetup%.lua$") then
    -- header comment with version line, format
    --   -- numodel.lua  vX.Y.Z  YYYY/MM/DD
    content = content:gsub(
      "(%-%-%s+numodel[^\n]-%s+)" .. VERSION_PAT .. "%s+%d%d%d%d/%d%d/%d%d",
      "%1v" .. tagname .. "  " .. tagdate)
  elseif file:match("tagsetup%.lua$") then
    -- Self-update the source-of-truth constants so the next tag run
    -- starts from the freshly-released version, not the previous one.
    content = content:gsub(
      '(release_date%s*=%s*)"[^"]+"',
      '%1"' .. tagdate .. '"')
    content = content:gsub(
      '(release_tag%s*=%s*)"[^"]+"',
      '%1"' .. tagname .. '"')
  elseif file:match("README%.md$") then
    -- The bundle README mentions the current release in prose
    -- (`current release \`v0.5.0-pre\``).  Keep that one phrase in
    -- sync; the rest of README.md is hand-written.
    content = content:gsub(
      "(current release `)" .. VERSION_PAT .. "`",
      "%1v" .. tagname .. "`")
  end

  return content
end
