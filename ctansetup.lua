-- ============================================================
-- ctansetup.lua — what a *module* contributes to the CTAN source tree.
-- ============================================================
--
-- Loaded from:
--   numodel/build.lua               (via maindir)
--   numodel-plot/build.lua          (via maindir)
--
-- Deliberately NOT loaded from the bundle build.lua: this is about
-- the per-module contribution to the shared CTAN directory, and at
-- bundle level `module` is empty.
--
-- Why this exists
-- ---------------
-- l3build's copyctan() copies `textfiles` flat into
-- <ctandir>/<ctanpkg> (see l3build-ctan.lua):
--
--     for _,file in pairs(textfiles) do cp(file, textfiledir, pkgdir) end
--
-- Both modules list README.md and CHANGELOG.md there, and the bundle
-- root lists its own two under exactly those names, so all three
-- pairs collide on one filename.  The bundle root is copied last by
-- ctan(), so it wins: up to and including v0.9.0 the CTAN zip shipped
-- only the bundle-level README and CHANGELOG, and the two module
-- CHANGELOGs -- the ones the bundle CHANGELOG tells readers to
-- consult -- never reached CTAN at all.
--
-- The bundle's `flatten = false` does not prevent this.  `flatten`
-- only guards copyctan()'s internal copyfiles() helper, not the
-- textfiles loop; and a module build run never reads the bundle
-- build.lua, so inside a module `flatten` keeps its default of true
-- regardless.
--
-- The TDS view was never affected: install_files() lays documentation
-- out per module under doc/latex/<bundle>/<module>/.  But we ship no
-- .tds.zip (packtdszip = false), so the source tree is what CTAN and
-- the distributions actually receive.
--
-- The fix
-- -------
-- All the collision needs is six distinct names, not six distinct
-- paths.  CTAN prefers a flat source archive, so each module's text
-- files are re-copied under a module-qualified name --
-- CHANGELOG-numodel.md, README-numodel-plot.md, and so on -- rather
-- than into a per-module subdirectory.  The bundle root keeps the
-- unsuffixed README.md / CHANGELOG.md, which is what CTAN shows.
--
-- copyctan is a global defined by l3build-ctan.lua, which l3build
-- loads before build.lua, so it can simply be wrapped.  Everything it
-- reads (ctandir, ctanpkg, textfiledir, textfiles) is resolved at
-- call time, i.e. after l3build-variables.lua has run.  Copy-then-
-- rename is the same two-step l3build itself uses for `ctanreadme`;
-- it also frees the plain name again for the next writer, so the
-- module runs and the bundle root do not tread on each other.

local stock_copyctan = copyctan

function copyctan()
  stock_copyctan()
  local pkgdir = ctandir .. "/" .. ctanpkg
  for _, file in pairs(textfiles) do
    local base, ext = file:match("^(.+)%.([^.]+)$")
    local target = base and (base .. "-" .. module .. "." .. ext)
                        or (file .. "-" .. module)
    -- Fail loudly: a silent miss here is the very bug this file
    -- exists to correct.
    if cp(file, textfiledir, pkgdir) ~= 0 then
      error("ctansetup: could not copy " .. file .. " into " .. pkgdir)
    end
    ren(pkgdir, file, target)
    if not fileexists(pkgdir .. "/" .. target) then
      error("ctansetup: " .. target .. " did not reach the CTAN tree")
    end
  end
end
