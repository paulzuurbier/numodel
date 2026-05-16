-- ====================================================================
-- numodel tests — run.lua
-- ====================================================================
-- Minimalistic test runner. No external dep (no busted/luaunit).
--
--   texlua tests/run.lua            run all tests, fail on diff
--   texlua tests/run.lua --update   regenerate snapshots
--   texlua tests/run.lua flow       run only test_flow
--
-- Tests are .lua files in tests/ named test_<topic>.lua.  Each returns
-- a table { name = "...", run = function(ctx) ... end }.  The runner
-- exposes ctx.assert_eq, ctx.assert_snapshot, ctx.update_mode, etc.
-- ====================================================================

-- Make tests/ runnable from numodel/ regardless of cwd.
local script_dir = arg[0]:match("(.*[/\\])") or "./"
package.path = script_dir .. "?.lua;" .. script_dir .. "../?.lua;" .. package.path

-- Stub tex.sprint so numodel.lua loads under texlua.
if not tex then tex = {} end
if not tex.sprint then
    local sink = {}
    tex._sprint_sink = sink
    function tex.sprint(...)
        local args = {...}
        local s
        if type(args[1]) == "number" and #args > 1 then
            s = table.concat(args, " ", 2)
        else
            s = table.concat(args, " ")
        end
        sink[#sink + 1] = s
    end
end

require("numodel")

local update_mode  = false
local filter       = nil
for _, a in ipairs(arg) do
    if a == "--update" then update_mode = true
    elseif not a:match("^%-") then filter = a end
end

local snapshots_dir = script_dir .. "snapshots/"
local fixtures_dir  = script_dir .. "fixtures/"

local total, failed, updated = 0, 0, 0
local failures = {}

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local c = f:read("*a"); f:close(); return c
end

local function write_file(path, content)
    -- Ensure parent dir exists.  texlua has no mkdir; rely on user.
    local f, err = io.open(path, "w")
    if not f then error("cannot write "..path..": "..tostring(err)) end
    f:write(content); f:close()
end

local function diff_lines(expected, actual)
    -- Cheap line-by-line diff.
    local elines, alines = {}, {}
    for l in (expected.."\n"):gmatch("([^\n]*)\n") do elines[#elines+1] = l end
    for l in (actual  .."\n"):gmatch("([^\n]*)\n") do alines[#alines+1] = l end
    local out = {}
    local n = math.max(#elines, #alines)
    for i = 1, n do
        local e, a = elines[i] or "", alines[i] or ""
        if e ~= a then
            out[#out+1] = string.format("  line %d:", i)
            out[#out+1] = "    expected: " .. e
            out[#out+1] = "    actual:   " .. a
        end
    end
    return table.concat(out, "\n")
end

local ctx = {
    update_mode  = update_mode,
    fixtures_dir = fixtures_dir,
}

function ctx.load_fixture(name)
    local path = fixtures_dir .. name .. ".lua"
    local chunk, err = loadfile(path)
    if not chunk then error("fixture "..name..": "..err) end
    return chunk()
end

function ctx.apply_fixture(fx)
    -- Reset the prefix in numodel state.
    local p = fx.prefix
    numodel.models[p] = nil
    numodel.init_prefix(p)
    for _, v in ipairs(fx.vars) do
        numodel.register(p, v.name)
        numodel.set_meta(p, v.name, {
            type  = v.type,
            text  = v.text or v.name,
            gridx = v.gridx or -1,
            gridy = v.gridy or -1,
        })
    end
    for _, r in ipairs(fx.rules or {}) do
        numodel.add_rule(p, r.target, r.expr, r.kind or "calc")
    end
    return p
end

function ctx.assert_eq(label, expected, actual)
    total = total + 1
    if expected ~= actual then
        failed = failed + 1
        failures[#failures+1] = string.format(
            "FAIL %s\n  expected: %s\n  actual:   %s",
            label, tostring(expected), tostring(actual))
    end
end

function ctx.assert_snapshot(name, actual)
    total = total + 1
    local path = snapshots_dir .. name .. ".txt"
    local expected = read_file(path)
    if update_mode then
        if expected ~= actual then
            write_file(path, actual)
            updated = updated + 1
        end
        return
    end
    if expected == nil then
        failed = failed + 1
        failures[#failures+1] = string.format(
            "FAIL %s — no snapshot at %s.  Run with --update to create.",
            name, path)
        return
    end
    if expected ~= actual then
        failed = failed + 1
        failures[#failures+1] = string.format(
            "FAIL %s\n%s", name, diff_lines(expected, actual))
    end
end

-- Discover test files: tests/test_*.lua (filter optional).
local function list_tests()
    local found = {}
    -- texlua has lfs sometimes; fall back to a hard-coded ordered list.
    local known = { "flow", "layout", "causals", "edge_cases", "wrap" }
    for _, topic in ipairs(known) do
        if (not filter) or filter == topic then
            local path = script_dir .. "test_" .. topic .. ".lua"
            local f = io.open(path, "r")
            if f then
                f:close()
                found[#found+1] = { topic = topic, path = path }
            end
        end
    end
    return found
end

for _, t in ipairs(list_tests()) do
    local chunk, err = loadfile(t.path)
    if not chunk then
        print(string.format("ERROR loading %s: %s", t.path, err))
        failed = failed + 1
    else
        local mod = chunk()
        if mod and mod.run then
            io.write(string.format("== %s ==\n", mod.name or t.topic))
            mod.run(ctx)
        end
    end
end

io.write(string.format("\n%d checks, %d failed", total, failed))
if updated > 0 then io.write(string.format(", %d snapshots updated", updated)) end
io.write("\n")
if failed > 0 then
    io.write("\n--- failures ---\n")
    for _, f in ipairs(failures) do io.write(f.."\n\n") end
    os.exit(1)
end
os.exit(0)
