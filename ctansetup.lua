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
-- ctan(), so it wins: up to and including v0.8.0 the CTAN zip shipped
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
-- Copy the module's own text files a second time, into a per-module
-- subdirectory of the CTAN package.  That is where the bundle
-- CHANGELOG's cross-references already point ("see
-- numodel/CHANGELOG.md and numodel-plot/CHANGELOG.md") and what the
-- bundle build.lua's `flatten = false` was reaching for.
--
-- copyctan is a global defined by l3build-ctan.lua, which l3build
-- loads before build.lua, so it can simply be wrapped.  Everything it
-- reads (ctandir, ctanpkg, textfiledir, textfiles) is resolved at
-- call time, i.e. after l3build-variables.lua has run.

local stock_copyctan = copyctan

function copyctan()
  stock_copyctan()
  local moduledir = ctandir .. "/" .. ctanpkg .. "/" .. module
  mkdir(moduledir)
  for _, file in pairs(textfiles) do
    -- Fail loudly: a silent miss here is the very bug this file
    -- exists to correct.
    if cp(file, textfiledir, moduledir) ~= 0 then
      error("ctansetup: could not copy " .. file .. " into " .. moduledir)
    end
  end
end
