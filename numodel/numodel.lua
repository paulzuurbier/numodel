-- ====================================================================
-- numodel.lua --- Lua data store for the numodel package (per-prefix)
-- numodel.lua  v0.10.0  2026/10/08
-- ====================================================================
--
-- Copyright (C) 2026 Paul Zuurbier <mail@paulzuurbier.nl>
--
-- This work may be distributed and/or modified under the conditions
-- of the LaTeX Project Public License, either version 1.3c of this
-- license or (at your option) any later version.  The latest version
-- of this license is in https://www.latex-project.org/lppl.txt
--
-- This work has the LPPL maintenance status 'maintained'.
-- The Current Maintainer of this work is Paul Zuurbier.
--
-- This work consists of the files numodel.dtx and numodel.ins, the
-- derived file numodel.sty, and the companion Lua module numodel.lua.
-- ====================================================================
-- Stores values per (prefix, variable name).  Each model (prefix)
-- has its own varlist, steps and step counter.
--
-- Usage from TeX:
--   \directlua{numodel.init_prefix("lift")}
--   \directlua{numodel.register("lift", "liftV")}
--   \directlua{numodel.init("lift")}                   -- between runs
--   \directlua{numodel.record("lift", "liftV", 3.14)}
--   \directlua{numodel.end_step("lift")}
--   \directlua{numodel.get_coords("lift", "liftT", "liftV")}
--   \directlua{numodel.get_min("lift", "liftV")}
--   \directlua{numodel.get_max("lift", "liftV")}
--   \directlua{numodel.get_step("lift", "liftV", 3)}

local M = {}
numodel = M
M.models = {}  -- prefix -> {varlist, steps, nsteps}
-- Package settings that exporters need (mirrored from \numodelsetup).
M.settings = { maxiter = 20000, blanks = "open" }

function M.set_setting(name, value)
    M.settings[name] = value
end
debug = true

local function ensure(p)
    if not M.models[p] then
        M.models[p] = {varlist = {}, steps = {}, nsteps = 0}
    end
    return M.models[p]
end

function M.init_prefix(p)
    ensure(p)
end

function M.register(p, name)
    local m = ensure(p)
    m.steps[name] = {}
    m.varlist[#m.varlist + 1] = name
end

-- Reset step data for prefix p (keeps varlist, clears steps and nsteps).
function M.init(p)
    local m = M.models[p]
    if not m then return end
    for _, name in ipairs(m.varlist) do
        m.steps[name] = {}
    end
    m.nsteps = 0
end

function M.record(p, name, value)
    local m = M.models[p]
    if not m then return end
    local t = m.steps[name]
    if not t then return end
    t[#t + 1] = value
end

function M.end_step(p)
    local m = M.models[p]
    if not m then return end
    m.nsteps = m.nsteps + 1
end

function M.get_coords(p, xvar, yvar)
    local m = M.models[p]
    if not m then return end
    local xd = m.steps[xvar]
    local yd = m.steps[yvar]
    if not xd or not yd then return end
    local n = math.min(#xd, #yd)
    local parts = {}
    for i = 1, n do
        if xd[i] and yd[i] then
            parts[#parts + 1] = "(" .. xd[i] .. "," .. yd[i] .. ")"
        end
    end
    tex.sprint(table.concat(parts, " "))
end

function M.get_min(p, name)
    local m = M.models[p]
    if not m then tex.sprint("inf") return end
    local data = m.steps[name]
    if not data or #data == 0 then
        tex.sprint("inf")
        return
    end
    local mn = math.huge
    for _, v in ipairs(data) do
        if v and v < mn then mn = v end
    end
    tex.sprint(tostring(mn))
end

function M.get_max(p, name)
    local m = M.models[p]
    if not m then tex.sprint("-inf") return end
    local data = m.steps[name]
    if not data or #data == 0 then
        tex.sprint("-inf")
        return
    end
    local mx = -math.huge
    for _, v in ipairs(data) do
        if v and v > mx then mx = v end
    end
    tex.sprint(tostring(mx))
end

-- Value of variable 'name' at step 'step' (0-based).
-- Step 0 = initial state (before the first rule application).
-- Step 1 = state after the first rule application, etc.
function M.get_step(p, name, step)
    local m = M.models[p]
    if not m then return end
    local data = m.steps[name]
    if not data then return end
    -- Non-negative step: 0-based forward index (step 0 = initial values).
    -- Negative step: index from the end (-1 = last recorded step).
    local n = #data
    local idx = step >= 0 and step + 1 or n + step + 1
    if idx < 1 or idx > n then
        tex.error(string.format(
            "numodel: \\mstep index %d out of range for variable '%s' " ..
            "(prefix '%s' has %d recorded sample%s; valid indices: " ..
            "0..%d or %d..-1)",
            step, name, p, n, n == 1 and "" or "s",
            n - 1, -n),
            { "Call \\computemodel before \\mstep, and keep the index ",
              "within the recorded range -- see \\<prefix>steps." })
        return
    end
    tex.sprint(tostring(data[idx]))
end

-- Value of variable 'name' at the first recorded step where variable
-- 'at' (typically the time) has reached 'value'.  Robust against the
-- round-off of an accumulated time step: t = 0.99999999 counts as 1.
-- Assumes 'at' does not decrease (time); raises an error when 'at'
-- never reaches 'value'.
function M.get_at(p, name, at, value)
    local m = M.models[p]
    local data = m and m.steps[name]
    local times = m and m.steps[at]
    if not data or not times then
        tex.error("numodel: \\mstepat: unknown variable '" ..
            (data and at or name) .. "' in model '" .. p .. "'")
        return
    end
    value = tonumber(value)
    local eps = 1e-9 * math.max(1, math.abs(value))
    for i = 1, math.min(#data, #times) do
        if times[i] >= value - eps then
            tex.sprint(tostring(data[i]))
            return
        end
    end
    tex.error(string.format(
        "numodel: \\mstepat: '%s' never reaches %s in model '%s'" ..
        " (last value %s)", at, tostring(value), p,
        tostring(times[#times])),
        { "Call \\computemodel first, and ask for a value within ",
          "the simulated range." })
end

-- --- name collisions ----------------------------------------------------
-- Every \mvar defines \<fullname> plus a family of accessors
-- \<fullname><suffix>; \computemodel adds \<prefix>steps.  Two
-- declarations collide when their macro names meet:
--   "model"     a variable of another model has the same full name
--               (prefix para + gX = prefix parag + X): always a bug;
--   "accessor"  the full name is another variable's accessor
--               (T + max = Tmax), or the reverse: the documented trap
--               of the manual's naming caveat.
-- check_name returns the kind and a message, or nil when the name is
-- free; \mvar turns "model" into an error and "accessor" into a
-- warning (existing documents rely on T next to Tmax).
M.accessor_suffixes = {
    "text", "unit", "unitraw", "sign", "type", "min", "max", "num",
    "qty", "pre", "gridx", "gridy", "gridxinit", "gridyinit", "alias",
    "aliasleft", "aliasright", "flowcloud", "blank",
}
M.owner = {}        -- full variable name -> prefix

function M.check_name(p, fullname)
    local o = M.owner[fullname]
    if o and o ~= p then
        return "model", "'" .. fullname .. "' is already a variable of"
            .. " model '" .. o .. "'"
    end
    for _, sfx in ipairs(M.accessor_suffixes) do
        local base = fullname:sub(1, -#sfx - 1)
        if base ~= "" and fullname:sub(-#sfx) == sfx and M.owner[base] then
            return "accessor", "'" .. fullname .. "' is also the '" ..
                sfx .. "' accessor of variable '" .. base .. "'"
        end
        if M.owner[fullname .. sfx] then
            return "accessor", "the '" .. sfx .. "' accessor of '" ..
                fullname .. "' is also variable '" .. fullname .. sfx .. "'"
        end
    end
    if fullname == p .. "steps" then
        return "accessor", "'" .. fullname .. "' is also the iteration"
            .. " count of model '" .. p .. "'"
    end
    return nil
end

-- TeX-side helpers for \mvar (results as catcode-12 strings).
function M.clash_kind(p, fullname)
    tex.sprint(-2, (M.check_name(p, fullname)) or "none")
end
function M.clash_message(p, fullname)
    local _, msg = M.check_name(p, fullname)
    tex.sprint(-2, msg or "")
end
function M.claim_name(p, fullname)
    M.owner[fullname] = M.owner[fullname] or p
end

function M.reset()
    M.models = {}
    M.owner = {}
end

-- ====================================================================
-- Layout pipeline (Pillar A)
-- ====================================================================
-- Sole source of truth for flow-detection and auto-layout; the TeX
-- side renders the result via numodel.tex_writeback / emit_causals.
-- Term-aware flow classification (post-A4): between-flows are
-- detected by comparing normalized term-strings, so factor mismatches
-- correctly reject false positives (REFACTORNUMODEL.MD §1.5 / A4).
--
-- Per-prefix substructures populated below:
--
--   meta[name] = { type, text, gridx_init, gridy_init, decl_order,
--                  value, value_expr, unit, sigfigs }
--   rules[i]   = { target, expr, kind }
--   program[i] = { kind, target, expr, starred, text }
--                (every model row in display order; see get_model)
--   stop       = raw \mstop condition (or nil)
--   deps[target]      = { src1, src2, ... }   (declaration-order set)
--   flows.inflow[stock]        = flow_var
--   flows.outflow[stock]       = flow_var
--   flows.valve_for[var]       = stock        (var = inflow valve of stock)
--   flows.outvalve_for[var]    = stock
--   flows.between_valve[var]   = src_stock
--   flows.between_target[var]  = tgt_stock
--   flows.stock_valve[stock]   = src_stock    (stock-as-flow inflow)
--   layout[name] = { gridx, gridy, role, vpos_x, vpos_y }
--   occupied["gx,gy"] = name                  (kept as map for parity)
--   causals[i] = { src, tgt, bend, tgt_is_valve }

local function ensure_meta(p)
    local m = ensure(p)
    m.meta    = m.meta    or {}
    m.rules   = m.rules   or {}
    m.program = m.program or {}
    return m
end

function M.set_meta(p, name, opts)
    local m = ensure_meta(p)
    local prev = m.meta[name]
    local order = (prev and prev.decl_order) or (#m.varlist)
    m.meta[name] = {
        type       = opts.type or "aux",
        text       = opts.text or name,
        gridx_init = tonumber(opts.gridx) or -1,
        gridy_init = tonumber(opts.gridy) or -1,
        decl_order = order,
        -- Export data (all optional; the layout pipeline ignores them).
        -- value      = evaluated start value, nil without a start value
        -- value_expr = start value as the user wrote it (detokenized)
        -- unit       = siunitx unit as the user wrote it (detokenized)
        -- sigfigs    = significant figures (fifth \mvar argument)
        value      = tonumber(opts.value),
        value_expr = opts.value_expr,
        unit       = opts.unit,
        sigfigs    = tonumber(opts.sigfigs),
        blank      = opts.blank and true or false,   -- \mvar[blank]
    }
end

function M.add_rule(p, target, expr, kind, starred, blank)
    local m = ensure_meta(p)
    m.rules[#m.rules + 1] = {
        target = target,
        expr   = expr or "",
        kind   = kind or "calc",
    }
    m.program[#m.program + 1] = {
        kind    = kind or "calc",
        target  = target,
        expr    = expr or "",
        starred = starred and true or false,
        blank   = blank and true or false,          -- \mrule[blank]
    }
end

-- Axis range of variable name as drawn by \diagrammodel (after
-- \calcplotdims rounding).  A variable shown in several diagrams gets
-- the union of their ranges.
function M.set_axis(p, name, lo, hi)
    local m = ensure_meta(p)
    lo, hi = tonumber(lo), tonumber(hi)
    if not (lo and hi) then return end
    m.axis = m.axis or {}
    local a = m.axis[name]
    if a then
        a.min, a.max = math.min(a.min, lo), math.max(a.max, hi)
    else
        m.axis[name] = { min = lo, max = hi }
    end
end

-- Axis range \calcplotdims (numodel-plot) would give a series from lo
-- to hi on an axis of at most cmmax cm: the range is widened to a whole
-- number of ticks of 1, 2, 2.5 or 5 times a power of ten.  Mirrors
-- \calcplotdims, so a variable that is not drawn still gets the range
-- its diagram would have.  Returns nil for an empty series or an
-- all-zero one.
function M.nice_range(lo, hi, cmmax)
    cmmax = cmmax or 10
    if not lo or not hi then return nil end
    if lo == hi then                      -- a constant: from 0 to it
        if lo == 0 then return nil end
        lo, hi = math.min(0, lo), math.max(0, hi)
    end
    local log = math.floor(math.log(hi - lo, 10))
    local S = (hi - lo) / 10^log
    local cm
    if S <= cmmax / 10 then cm = 10 * S
    elseif S <= cmmax / 5 then cm = 5 * S
    elseif S <= cmmax / 4 then cm = 4 * S
    elseif S <= cmmax / 2 then cm = 2 * S
    elseif S <= cmmax then cm = S
    else cm = S / 2 end
    local tick = S / cm * 10^log
    -- Snap tick to the decimal it stands for (0.25, not 0.2499999...).
    tick = tonumber(string.format("%.12g", tick))
    local function snap(x) return tonumber(string.format("%.12g", x)) end
    return snap(math.floor(lo / tick + 1e-9) * tick),
           snap(math.ceil(hi / tick - 1e-9) * tick)
end

-- Free-text row (\mruletext): display only, never executed.
function M.add_ruletext(p, text)
    local m = ensure_meta(p)
    m.program[#m.program + 1] = { kind = "text", text = text or "" }
end

-- Stop condition (\mstop).  Also recorded as a program row, so that
-- exporters see it at the position where it appears in \textmodel.
function M.set_stop(p, expr, blank)
    local m = ensure_meta(p)
    m.stop = expr or ""
    m.program[#m.program + 1] = { kind = "stop", expr = m.stop,
        blank = blank and true or false }
end

-- --- helpers ----------------------------------------------------------

local function var_iter(m)
    -- Walk variables in declaration order (= varlist order).
    local i = 0
    return function()
        i = i + 1
        local n = m.varlist[i]
        if n then return n, m.meta[n] end
    end
end

-- Match \name as a control sequence in a detokenized-style string.
-- After \detokenize a control word is followed by a non-letter
-- (typically a space).  Within hand-built fixture strings we accept
-- the same boundaries.  Letters = ASCII a-zA-Z (TeX default catcodes).
local function cs_in_expr(name, expr)
    -- Need non-letter after the cs.  Anchor at start or after non-letter.
    -- Lua patterns: %a = letters.  We match "\name" + (non-letter | end).
    local pat = "\\" .. name:gsub("(%W)", "%%%1")
    local s, e = expr:find(pat, 1, false)
    while s do
        local nxt = expr:sub(e + 1, e + 1)
        if nxt == "" or not nxt:match("%a") then return true end
        s, e = expr:find(pat, e + 1, false)
    end
    return false
end

-- Find first variable (declaration order) whose \name appears in term,
-- excluding the target itself, system-typed vars, and display "dt".
-- An aux or stock variable wins over a constant: when both can be the
-- flow var of a term, the rate-bearing one is the meaningful valve
-- label, not the parameter that scales it.  Falls back to the first
-- constant if no aux/stock candidate is present.
local function first_flow_var(m, target, term)
    local fallback = nil
    for name, meta in var_iter(m) do
        if name ~= target
           and meta.type ~= "system"
           and meta.text ~= "dt"
           and cs_in_expr(name, term)
        then
            if meta.type == "aux" or meta.type == "stock" then
                return name
            elseif not fallback then
                fallback = name
            end
        end
    end
    return fallback
end

-- Tokenize an additive expression into top-level (sign, term) pairs.
-- Parentheses, braces, and brackets are treated as opaque blocks; only
-- top-level `+`/`-` split.  The leading term has implicit "+" if the
-- expression starts without an explicit sign.  Whitespace is preserved
-- in the returned term strings; callers normalise via normalize_term.
function M._tokenize_terms(expr)
    local terms = {}
    local n = #expr
    local i = 1
    while i <= n and expr:sub(i, i):match("%s") do i = i + 1 end
    local sign = "+"
    if i <= n and (expr:sub(i, i) == "+" or expr:sub(i, i) == "-") then
        sign = expr:sub(i, i)
        i = i + 1
    end
    while i <= n do
        while i <= n and expr:sub(i, i):match("%s") do i = i + 1 end
        local start = i
        local depth = 0
        while i <= n do
            local c = expr:sub(i, i)
            if c == "(" or c == "{" or c == "[" then
                depth = depth + 1
            elseif c == ")" or c == "}" or c == "]" then
                depth = depth - 1
            elseif (c == "+" or c == "-") and depth == 0 then
                break
            end
            i = i + 1
        end
        local term = expr:sub(start, i - 1):gsub("%s+$", "")
        if term ~= "" then
            terms[#terms + 1] = { sign = sign, term = term }
        end
        if i <= n then
            sign = expr:sub(i, i)
            i = i + 1
        else
            break
        end
    end
    return terms
end

-- Strip all whitespace for term-string equality comparison.  The
-- between-flow detection requires `\X * \Dt` and `\X*\Dt` to match.
local function normalize_term(s)
    return (s:gsub("%s+", ""))
end

-- Locate the first top-level parenthesised group in `s`.  Returns
-- start, end (character indices of the matching `(` and `)`) or nil
-- if no balanced top-level pair exists.  Square brackets and braces
-- count as their own nesting level but are not unwrapped here -- only
-- `(...)` is considered for term distribution.
local function find_top_paren(s)
    local n = #s
    local i = 1
    while i <= n do
        local c = s:sub(i, i)
        if c == "(" then
            local startp = i
            local d = 1
            local j = i + 1
            while j <= n and d > 0 do
                local cj = s:sub(j, j)
                if cj == "(" then d = d + 1
                elseif cj == ")" then d = d - 1 end
                j = j + 1
            end
            if d == 0 then return startp, j - 1 end
            return nil
        end
        i = i + 1
    end
    return nil
end

-- If `term` has the shape `<before>(A op B op ...)<after>` with at
-- least one top-level `+`/`-` inside the parens, redistribute it into
-- one term per inner additive component, combining the outer `sign`
-- with each inner sign.  Otherwise the original (sign, term) is
-- returned unchanged.  Only the leftmost top-level paren-group is
-- expanded; nested or sibling groups are left alone to avoid
-- combinatorial explosion.  Mirrors hand-distributing
-- `+(A - B) * C` into `+A*C , -B*C` for flow-classification purposes
-- -- the numeric value of the term does not need to be preserved,
-- only the variables it references and their sign.
function M._distribute_paren_term(sign, term)
    local sp, ep = find_top_paren(term)
    if not sp then
        return { { sign = sign, term = term } }
    end
    local inner = term:sub(sp + 1, ep - 1)
    local inner_terms = M._tokenize_terms(inner)
    if #inner_terms < 2 then
        return { { sign = sign, term = term } }
    end
    local before = term:sub(1, sp - 1)
    local after  = term:sub(ep + 1)
    -- Bail out if there's another paren-group on either side; the
    -- two-paren product `(A-B)*(C-D)` would need 4-way distribution.
    if before:find("(", 1, true) or after:find("(", 1, true) then
        return { { sign = sign, term = term } }
    end
    local out = {}
    for _, it in ipairs(inner_terms) do
        local combined_sign = (sign == it.sign) and "+" or "-"
        out[#out + 1] = {
            sign = combined_sign,
            term = before .. it.term .. after,
        }
    end
    return out
end

-- Split a top-level ternary `cond ? a : b`.  Returns
-- { cond, then_expr, else_expr } or nil if no top-level `?:`.
-- Parentheses/braces/brackets are opaque; nested `?:` pairs are
-- balanced so `c1 ? (c2 ? a : b) : c` returns the outermost split.
function M._split_ternary(expr)
    local n = #expr
    local depth, q_at = 0, nil
    local i = 1
    while i <= n do
        local c = expr:sub(i, i)
        if c == "(" or c == "{" or c == "[" then depth = depth + 1
        elseif c == ")" or c == "}" or c == "]" then depth = depth - 1
        elseif depth == 0 and c == "?" then q_at = i; break end
        i = i + 1
    end
    if not q_at then return nil end
    local balance, j = 1, q_at + 1
    while j <= n do
        local c = expr:sub(j, j)
        if c == "(" or c == "{" or c == "[" then depth = depth + 1
        elseif c == ")" or c == "}" or c == "]" then depth = depth - 1
        elseif depth == 0 then
            if c == "?" then balance = balance + 1
            elseif c == ":" then
                balance = balance - 1
                if balance == 0 then
                    return {
                        cond      = expr:sub(1, q_at - 1),
                        then_expr = expr:sub(q_at + 1, j - 1),
                        else_expr = expr:sub(j + 1),
                    }
                end
            end
        end
        j = j + 1
    end
    return nil
end

-- Flatten a (possibly nested) ternary into its terminal branches.
-- The condition strings are dropped: only term-bearing branches
-- contribute candidate flow terms.
function M._ternary_branches(expr)
    local s = M._split_ternary(expr)
    if not s then return { expr } end
    local out = {}
    for _, b in ipairs(M._ternary_branches(s.then_expr)) do
        out[#out + 1] = b
    end
    for _, b in ipairs(M._ternary_branches(s.else_expr)) do
        out[#out + 1] = b
    end
    return out
end

-- --- build_deps -------------------------------------------------------

function M.build_deps(p)
    local m = ensure_meta(p)
    m.deps = {}
    for _, r in ipairs(m.rules) do
        if r.kind == "calc" or r.kind == "ternary" then
            local list = {}
            for name, _ in var_iter(m) do
                if name ~= r.target and cs_in_expr(name, r.expr) then
                    list[#list + 1] = name
                end
            end
            -- Last write wins (mirrors \prop_gput for repeated targets).
            m.deps[r.target] = list
        end
    end
end

-- --- classify_flows ---------------------------------------------------
-- Term-aware flow classification.  Each stock rule is split into
-- additive terms; the self-carry term `+S` is dropped, and the
-- remaining `+T`/`-T` are treated as candidate inflow/outflow terms.
-- The flow variable for a term is the first non-system, non-dt,
-- non-target var appearing in the term (after \detokenize-style cs
-- matching).
--
-- Between-flow detection compares the *normalized term-string*, so
-- factor differences matter: `Eel = Eel - 2*P*dt` paired with
-- `Q = Q + 2*P*dt` is a between-flow; pairing it with `Q = Q + 3*P*dt`
-- is not.  Stock-as-flow detection requires either (a) the source
-- stock has no rule (truly conserved) or (b) the source rule has a
-- matching outflow term — without that, the term is not a real flow.
--
-- Single-flow-per-stock invariant: classify_flows still records at
-- most one entry per stock in `flows.inflow` / `flows.outflow`,
-- because every downstream emitter (tex_writeback, populate_occupied,
-- auto_layout) assumes one valve per stock.  Multi-flow stocks would
-- need a follow-up to lift that assumption first.

function M.classify_flows(p)
    local m = ensure_meta(p)
    m.flows = {
        inflow              = {},
        outflow             = {},
        valve_for           = {},
        -- Secondary stocks that share an inflow with the primary
        -- valve_for[fv] target.  Map: fv -> ordered list of stocks.
        -- Used by the renderer to draw a curved branch from the
        -- shared valve, sweeping over the primary stock into each
        -- additional target.  Empty when no inflow is shared.
        valve_extra_targets = {},
        outvalve_for        = {},
        -- Extra source stocks that share an outflow with the primary
        -- outvalve_for[fv] source.  Map: fv -> ordered list of stocks.
        -- Mirrors valve_extra_targets but for the outflow side: the
        -- primary is the LAST stock to claim the valve (so the valve
        -- ends up to the right of all sharing stocks); previously-
        -- registered sources are demoted to this list and rendered
        -- with a curved branch over the intermediate stocks.
        outvalve_extra_sources = {},
        between_valve       = {},
        between_target      = {},
        stock_valve         = {},
        stock_phantom_valve = {},
    }
    -- Step 1: tokenize each stock rule, build per-stock term lists.
    -- Ternary rules contribute terms from all branches; if the same
    -- (term, fv) appears as inflow in one branch and outflow in
    -- another, inflow wins.
    local in_terms, out_terms = {}, {}
    local has_rule = {}
    for _, r in ipairs(m.rules) do
        local meta = m.meta[r.target]
        if meta and meta.type == "stock"
           and (r.kind == "calc" or r.kind == "ternary") then
            has_rule[r.target] = true
            in_terms[r.target]  = {}
            out_terms[r.target] = {}
            local self_cs = "\\" .. r.target
            local branches = (r.kind == "ternary")
                and M._ternary_branches(r.expr)
                or  { r.expr }
            local in_set, in_order   = {}, {}
            local out_set, out_order = {}, {}
            for _, br in ipairs(branches) do
                for _, raw in ipairs(M._tokenize_terms(br)) do
                    for _, t in ipairs(
                            M._distribute_paren_term(raw.sign, raw.term)) do
                        local norm = normalize_term(t.term)
                        if not (t.sign == "+" and norm == self_cs) then
                            local fv = first_flow_var(m, r.target, t.term)
                            if fv then
                                local key = norm .. "|" .. fv
                                if t.sign == "+" then
                                    if not in_set[key] then
                                        in_set[key] = { term = norm, fv = fv,
                                                        used = false }
                                        in_order[#in_order+1] = key
                                    end
                                else
                                    if not out_set[key] then
                                        out_set[key] = { term = norm, fv = fv,
                                                         used = false }
                                        out_order[#out_order+1] = key
                                    end
                                end
                            end
                        end
                    end
                end
            end
            -- Inflow wins: drop outflow entries that collide with inflow.
            for _, key in ipairs(in_order) do
                in_terms[r.target][#in_terms[r.target]+1] = in_set[key]
            end
            for _, key in ipairs(out_order) do
                if not in_set[key] then
                    out_terms[r.target][#out_terms[r.target]+1] = out_set[key]
                end
            end
        end
    end
    -- Step 2: inflow → valve_for / stock_valve.  Factor-aware:
    -- stock-as-flow only when the source stock has a matching
    -- outflow term (the conserved-quantity interpretation: a between
    -- flow exists only when the increase of one stock is caused by
    -- the decrease of another).  Source stocks with no rule are
    -- treated as exogenous and pass through.  Failed stock-as-flow
    -- drops the inflow entirely so that build_deps emits a regular
    -- causal arrow.
    for tgt, _ in var_iter(m) do
        local ins = in_terms[tgt]
        if ins then
            for _, in_t in ipairs(ins) do
                local fv = in_t.fv
                local fmeta = m.meta[fv]
                if fmeta and fmeta.type == "stock" then
                    local matched = false
                    if has_rule[fv] then
                        for _, out_t in ipairs(out_terms[fv]) do
                            if not out_t.used and out_t.term == in_t.term then
                                out_t.used = true
                                matched = true
                                break
                            end
                        end
                    end
                    -- stock_valve = conserved-quantity between-flow: source
                    -- stock has a matching outflow term, so the inflow
                    -- arrow may attach to it directly.
                    -- stock_phantom_valve = source stock acts as a rate
                    -- factor without a matching outflow; render with a
                    -- cloud-fed inflow valve, source linked via causal.
                    if matched then
                        m.flows.stock_valve[tgt] = fv
                    else
                        m.flows.stock_phantom_valve[tgt] = fv
                    end
                    m.flows.inflow[tgt] = fv
                    in_t.used = true
                else
                    local current = m.flows.valve_for[fv]
                    if current and current ~= tgt then
                        -- Shared inflow: tgt becomes a secondary
                        -- target on the existing valve for fv.  The
                        -- renderer draws a curved branch from the
                        -- valve, sweeping over the primary stock to
                        -- this one.
                        local extras = m.flows.valve_extra_targets[fv]
                        if not extras then
                            extras = {}
                            m.flows.valve_extra_targets[fv] = extras
                        end
                        local seen = false
                        for _, x in ipairs(extras) do
                            if x == tgt then seen = true; break end
                        end
                        if not seen then extras[#extras+1] = tgt end
                        m.flows.inflow[tgt] = fv
                    else
                        m.flows.valve_for[fv] = tgt
                        m.flows.inflow[tgt]   = fv
                    end
                    in_t.used = true
                end
            end
        end
    end
    -- Step 3: outflow → outvalve_for or between (term + fv match).
    -- Always record outflow[src] = fv even when fv is a stock,
    -- mirroring the previous code path so contrived rules with stock
    -- flow-vars still surface in the outflow map.
    for src, _ in var_iter(m) do
        local outs = out_terms[src]
        if outs then
            for _, out_t in ipairs(outs) do
                if not out_t.used then
                    local fv = out_t.fv
                    m.flows.outflow[src] = fv
                    local fmeta = m.meta[fv]
                    if fmeta and fmeta.type ~= "stock" then
                        local already = m.flows.valve_for[fv]
                        local match_between = false
                        if already and already ~= src then
                            for _, in_t in ipairs(in_terms[already] or {}) do
                                if in_t.fv == fv
                                   and in_t.term == out_t.term then
                                    match_between = true
                                    break
                                end
                            end
                        end
                        if match_between then
                            m.flows.between_valve[fv]  = src
                            m.flows.between_target[fv] = already
                            m.flows.valve_for[fv]      = nil
                        else
                            local prev = m.flows.outvalve_for[fv]
                            if prev and prev ~= src then
                                -- Shared outflow: the new src becomes
                                -- primary (so the valve is placed to
                                -- the right of the last-declared
                                -- source), and the previously-claimed
                                -- source is demoted to extras --
                                -- rendered with a curved arrow over
                                -- the intervening stocks.
                                local xs =
                                    m.flows.outvalve_extra_sources[fv]
                                if not xs then
                                    xs = {}
                                    m.flows.outvalve_extra_sources[fv] = xs
                                end
                                local seen = false
                                for _, x in ipairs(xs) do
                                    if x == prev then
                                        seen = true; break
                                    end
                                end
                                if not seen then xs[#xs+1] = prev end
                            end
                            m.flows.outvalve_for[fv] = src
                        end
                    end
                    out_t.used = true
                end
            end
        end
    end
end

-- --- populate_occupied + auto_layout ---------------------------------
-- Mirrors \__numodel_populate_occupied: + \__numodel_auto_layout: 1:1.

local function occupy(m, gx, gy, name)
    m.occupied[string.format("%d,%d", gx, gy)] = name
end

local function set_layout(m, name, gx, gy, role)
    local L = m.layout[name] or {}
    L.gridx = gx; L.gridy = gy
    if role then L.role = role end
    m.layout[name] = L
end

local function set_valve_pos(m, keep_natural, name, gx, gy)
    -- Mirrors \__numodel_set_valve_pos:nn
    gy = gy or 0
    if keep_natural then
        local L = m.layout[name] or {}
        L.vpos_x = gx; L.vpos_y = gy
        m.layout[name] = L
        occupy(m, gx, gy, name .. "__v")
    else
        set_layout(m, name, gx, gy)
        occupy(m, gx, gy, name)
    end
end

local function valve_unplaced(m, keep_natural, name)
    if keep_natural then
        return (m.layout[name] or {}).vpos_x == nil
    else
        return (m.layout[name] or {}).gridx == nil
            or  m.layout[name].gridx == -1
    end
end

function M.populate_occupied(p)
    local m = ensure_meta(p)
    m.occupied = {}
    m.layout   = m.layout or {}
    -- Reset layout to user-supplied gridx/gridy (mirrors gridxinit copy
    -- at the top of \__numodel_build_graphic).
    for name, meta in var_iter(m) do
        m.layout[name] = {
            gridx = meta.gridx_init,
            gridy = meta.gridy_init,
        }
    end
    -- Register every non-system var whose user gridx is set.
    for name, meta in var_iter(m) do
        if meta.type ~= "system" and meta.gridx_init ~= -1 then
            occupy(m, meta.gridx_init, meta.gridy_init, name)
        end
    end
end

-- Shift every auto-placed variable whose effective y-coordinate is at
-- or above `threshold` up by one row, then rebuild the corresponding
-- entries in m.occupied.  Manual items (gridx_init != -1) and the
-- reservation markers around them stay where they are.  Used by
-- auto_layout when the gridmaxx wrap threshold is exceeded.
local function shift_up_at_or_above(m, threshold)
    local moves = {}
    for _, name in ipairs(m.varlist) do
        local meta = m.meta and m.meta[name]
        if meta and meta.gridx_init == -1 then
            local L = m.layout[name]
            if L then
                if L.gridx and L.gridx ~= -1
                   and L.gridy and L.gridy ~= -1
                   and L.gridy >= threshold then
                    local new_y = L.gridy + 1
                    moves[#moves+1] = {
                        old    = string.format("%d,%d", L.gridx, L.gridy),
                        new    = string.format("%d,%d", L.gridx, new_y),
                        marker = name,
                    }
                    L.gridy = new_y
                end
                if L.vpos_x and L.vpos_y
                   and L.vpos_y >= threshold then
                    local new_y = L.vpos_y + 1
                    moves[#moves+1] = {
                        old    = string.format("%d,%d", L.vpos_x, L.vpos_y),
                        new    = string.format("%d,%d", L.vpos_x, new_y),
                        marker = name .. "__v",
                    }
                    L.vpos_y = new_y
                end
                if L.sv_gridx then
                    local sy = L.sv_gridy or 0
                    if sy >= threshold then
                        local new_y = sy + 1
                        moves[#moves+1] = {
                            old    = string.format("%d,%d", L.sv_gridx, sy),
                            new    = string.format("%d,%d", L.sv_gridx, new_y),
                            marker = name .. "__sv",
                        }
                        L.sv_gridy = new_y
                    end
                end
            end
        end
    end
    for _, mv in ipairs(moves) do
        if m.occupied[mv.old] == mv.marker then
            m.occupied[mv.old] = nil
        end
    end
    for _, mv in ipairs(moves) do
        m.occupied[mv.new] = mv.marker
    end
end

function M.auto_layout(p, diagram_style, max_gridx)
    diagram_style = diagram_style or "tight"
    max_gridx = tonumber(max_gridx) or 0
    local wrap = max_gridx > 0
    local m = ensure_meta(p)
    local F = m.flows
    local keep_natural = (diagram_style == "forrester")
                      or (diagram_style == "edu")

    -- Count auto vars per type.
    local const_count, aux_count, stock_count = 0, 0, 0
    for name, meta in var_iter(m) do
        if meta.gridx_init == -1 then
            if meta.type == "constant" then
                if F.valve_for[name] or F.outvalve_for[name]
                                     or F.between_valve[name] then
                    stock_count = stock_count + 1
                    if keep_natural then const_count = const_count + 1 end
                else
                    const_count = const_count + 1
                end
            elseif meta.type == "aux" then
                if F.inflow[name] then
                    -- stock-as-flow source: skip
                elseif F.valve_for[name] or F.outvalve_for[name]
                                         or F.between_valve[name] then
                    stock_count = stock_count + 1
                    if keep_natural then aux_count = aux_count + 1 end
                else
                    aux_count = aux_count + 1
                end
            elseif meta.type == "stock" then
                stock_count = stock_count + 1
                if F.stock_valve[name] or F.stock_phantom_valve[name] then
                    stock_count = stock_count + 1
                end
                local ofv = F.outflow[name]
                if ofv and not F.between_valve[ofv]
                   -- Shared outflow: only the primary source owns the
                   -- valve cell; extras share it and add no cells.
                   and (F.outvalve_for[ofv] == name
                        or F.outvalve_for[ofv] == nil) then
                    stock_count = stock_count + 1
                end
            end
        end
    end

    -- Skip cells already occupied by manually-placed vars.
    local function next_free(gx, gy)
        while m.occupied[string.format("%d,%d", gx, gy)] do
            gx = gx + 1
        end
        return gx
    end

    -- 0b. Reserve neighbour cells of manually-positioned stocks for
    -- their inflow / outflow valves so that the aux/const rows below
    -- don't claim those cells.  Step 4 (manual stocks) overwrites the
    -- placeholder with the real valve marker.
    local function reserve(gx, gy, marker)
        local key = string.format("%d,%d", gx, gy)
        if not m.occupied[key] then
            occupy(m, gx, gy, marker)
        end
    end
    for name, meta in var_iter(m) do
        if meta.type == "stock" and meta.gridx_init ~= -1 then
            local sgx, sgy = meta.gridx_init, meta.gridy_init
            if F.inflow[name]  then reserve(sgx - 1, sgy, name .. "__inreserve")  end
            if F.outflow[name] then reserve(sgx + 1, sgy, name .. "__outreserve") end
        end
    end

    -- Walk back from S through any between-flow that ends at S to
    -- find the head of the chain.  Stops at a stock that has no
    -- between-inflow, or at a manually placed predecessor (chain
    -- placement only spans auto stocks).
    local function chain_head(S)
        local seen = { [S] = true }
        while true do
            local ifv = F.inflow[S]
            if not ifv then return S end
            local pred = F.between_valve[ifv]
            if not pred or seen[pred]
               or F.between_target[ifv] ~= S then
                return S
            end
            local pmeta = m.meta[pred]
            if not pmeta or pmeta.gridx_init ~= -1 then return S end
            seen[pred] = true
            S = pred
        end
    end

    -- Build the between-flow chain starting at `head`, walking forward
    -- through outflow → between_valve → between_target.  All members
    -- are auto-placed stocks; a manual link breaks the chain.
    local function build_chain(head)
        local chain = { head }
        local cur = head
        while true do
            local ofv = F.outflow[cur]
            if not ofv or F.between_valve[ofv] ~= cur then break end
            local nxt = F.between_target[ofv]
            if not nxt then break end
            local nmeta = m.meta[nxt]
            if not nmeta or nmeta.gridx_init ~= -1 then break end
            chain[#chain+1] = nxt
            cur = nxt
        end
        return chain
    end

    -- Width (in grid cells) of a between-flow chain on row 0.  Each
    -- chain member contributes one stock cell; the n-1 between valves
    -- between them are shared (counted once).  The head can have a
    -- non-chain inflow valve / phantom valve in front, the tail can
    -- have a non-between outflow valve behind.
    local function chain_width(chain)
        local n  = #chain
        local s1 = chain[1]
        local sn = chain[n]
        local w  = n + (n - 1)  -- stocks + shared between valves
        local sv = F.stock_valve[s1] or F.stock_phantom_valve[s1]
        if sv then
            w = w + 1
        else
            local ifv = F.inflow[s1]
            if ifv and valve_unplaced(m, keep_natural, ifv) then
                w = w + 1
            end
        end
        local ofv = F.outflow[sn]
        if ofv and not F.between_valve[ofv]
           and valve_unplaced(m, keep_natural, ofv)
           -- Shared outflow: only the primary's chain owns the valve
           -- cell; extras render with a curved branch and add nothing
           -- to the chain width.
           and (F.outvalve_for[ofv] == sn
                or F.outvalve_for[ofv] == nil) then
            w = w + 1
        end
        return w
    end

    -- Emit a one-line warning to the LaTeX log + stderr.  Used when a
    -- between-flow chain is wider than gridmaxx — we keep the chain
    -- on a single row anyway because splitting it would break the
    -- continuous between-flow arrow.
    local function warn_oversized_chain(chain, total_w)
        local msg = string.format(
            "between-flow chain {%s} needs %d columns, " ..
            "exceeds gridmaxx=%d; kept on one row anyway.",
            table.concat(chain, ","), total_w, max_gridx)
        if texio and texio.write_nl then
            texio.write_nl("Package numodel Warning: " .. msg)
        else
            io.stderr:write("[numodel] " .. msg .. "\n")
        end
    end

    -- 1. Constants on gridy=2 -- or on gridy=1 when no aux is going
    -- to occupy that row, so the diagram never contains an empty row
    -- between stocks and constants.
    local const_y = (aux_count > 0) and 2 or 1
    local cursor = 0
    for name, meta in var_iter(m) do
        if meta.type == "constant" and meta.gridx_init == -1 then
            local place_high = true
            if not keep_natural then
                if F.valve_for[name] or F.outvalve_for[name]
                                     or F.between_valve[name] then
                    place_high = false
                end
            end
            if place_high then
                if wrap and cursor >= max_gridx then
                    shift_up_at_or_above(m, const_y)
                    cursor = 0
                end
                cursor = next_free(cursor, const_y)
                set_layout(m, name, cursor, const_y, "constant")
                occupy(m, cursor, const_y, name)
                cursor = cursor + 1
            end
        end
    end

    -- 2. Aux on gridy=1.  Centred relative to the constants row when
    -- gridmaxx wrapping is off; cursor 0 when wrap is active so the
    -- per-row fill is predictable.
    local offset = wrap and 0 or math.max(0,
        math.floor((const_count - aux_count + 1) / 2))
    cursor = offset
    for name, meta in var_iter(m) do
        if meta.type == "aux" and meta.gridx_init == -1 then
            local place_high = true
            if not keep_natural then
                if F.valve_for[name] or F.outvalve_for[name]
                                     or F.between_valve[name] then
                    place_high = false
                end
            end
            if place_high then
                if wrap and cursor >= max_gridx then
                    shift_up_at_or_above(m, 1)
                    cursor = 0
                end
                cursor = next_free(cursor, 1)
                set_layout(m, name, cursor, 1, "aux")
                occupy(m, cursor, 1, name)
                cursor = cursor + 1
            end
        end
    end

    -- 3. Stocks + valves on gridy=0.  Right-aligned relative to the
    -- constants row when wrapping is off; left-anchored when wrap is
    -- active.  Stocks linked by a between-flow are placed together as
    -- one chain so the continuous between-flow arrow stays straight.
    offset = wrap and 0 or (math.max(const_count, stock_count) - stock_count)
    cursor = offset
    local function place_stock(s)
        local sv = F.stock_valve[s] or F.stock_phantom_valve[s]
        if sv then
            cursor = next_free(cursor, 0)
            occupy(m, cursor, 0, s .. "__sv")
            local L = m.layout[s] or {}
            L.sv_gridx = cursor
            m.layout[s] = L
            cursor = cursor + 1
        else
            local ifv = F.inflow[s]
            if ifv and valve_unplaced(m, keep_natural, ifv) then
                cursor = next_free(cursor, 0)
                set_valve_pos(m, keep_natural, ifv, cursor)
                cursor = cursor + 1
            end
        end
        cursor = next_free(cursor, 0)
        set_layout(m, s, cursor, 0, "stock")
        occupy(m, cursor, 0, s)
        cursor = cursor + 1
        local ofv = F.outflow[s]
        if ofv and valve_unplaced(m, keep_natural, ofv) then
            -- For a shared outflow, only the designated primary
            -- source places the valve (so it lands to the right of
            -- the last-declared source).  Extras leave it for the
            -- primary's place_stock call to handle.
            local is_primary = (F.outvalve_for[ofv] == s)
                            or  F.between_valve[ofv] == s
                            or (F.outvalve_for[ofv] == nil
                                and F.between_valve[ofv] == nil)
            if is_primary then
                cursor = next_free(cursor, 0)
                set_valve_pos(m, keep_natural, ofv, cursor)
                cursor = cursor + 1
            end
        end
    end
    local placed_stocks = {}
    -- True when the previous chain on this row ended with a non-between
    -- outflow valve.  When the next chain starts with an inflow / sv
    -- valve the two adjacent valves would visually merge into a
    -- between-flow, so we insert one empty grid cell between them.
    local last_outflow = false
    for name, meta in var_iter(m) do
        if meta.gridx_init == -1 and meta.type == "stock"
           and not placed_stocks[name] then
            local chain   = build_chain(chain_head(name))
            local total_w = chain_width(chain)
            local s1      = chain[1]
            local has_prefix =
                F.stock_valve[s1] ~= nil
             or F.stock_phantom_valve[s1] ~= nil
             or (F.inflow[s1] ~= nil
                 and valve_unplaced(m, keep_natural, F.inflow[s1]))
            local gap = (last_outflow and has_prefix and cursor > 0)
                        and 1 or 0
            if wrap and cursor + gap + total_w > max_gridx then
                if total_w > max_gridx then
                    warn_oversized_chain(chain, total_w)
                end
                shift_up_at_or_above(m, 0)
                cursor = 0
                gap = 0
                last_outflow = false
            end
            cursor = cursor + gap
            for _, s in ipairs(chain) do
                place_stock(s)
                placed_stocks[s] = true
            end
            local sn  = chain[#chain]
            local ofv = F.outflow[sn]
            -- Only the chain that actually placed the outflow valve
            -- (= the chain whose tail owns it in outvalve_for) needs
            -- a gap before a following chain.  Shared outflows where
            -- this chain was an extra source leave the valve cell to
            -- the primary's chain and add no trailing valve here.
            last_outflow = ofv ~= nil
                       and F.between_valve[ofv] == nil
                       and (F.outvalve_for[ofv] == sn
                            or F.outvalve_for[ofv] == nil)
        end
    end

    -- 4. Valves for stocks with manual gridx.
    for name, meta in var_iter(m) do
        if meta.type == "stock" and meta.gridx_init ~= -1 then
            local stock_gx = m.layout[name].gridx
            local stock_gy = m.layout[name].gridy
            local sv = F.stock_valve[name] or F.stock_phantom_valve[name]
            if sv then
                local gx = stock_gx - 1
                occupy(m, gx, stock_gy, name .. "__sv")
                local L = m.layout[name] or {}
                L.sv_gridx = gx
                L.sv_gridy = stock_gy
                m.layout[name] = L
            else
                local ifv = F.inflow[name]
                if ifv and valve_unplaced(m, keep_natural, ifv) then
                    set_valve_pos(m, keep_natural, ifv,
                                  stock_gx - 1, stock_gy)
                end
            end
            local ofv = F.outflow[name]
            if ofv then
                local gx = stock_gx + 1
                if F.between_valve[ofv] then
                    if valve_unplaced(m, keep_natural, ofv) then
                        set_valve_pos(m, keep_natural, ofv, gx, stock_gy)
                    end
                else
                    if valve_unplaced(m, keep_natural, ofv) then
                        set_valve_pos(m, keep_natural, ofv, gx, stock_gy)
                    end
                end
            end
        end
    end

    -- Annotate roles on flow-classified vars (regardless of placement).
    for name, _ in var_iter(m) do
        local L = m.layout[name]; if not L then goto continue end
        if F.valve_for[name]      then L.role = "inflow-valve"
        elseif F.outvalve_for[name]  then L.role = "outflow-valve"
        elseif F.between_valve[name] then L.role = "between-valve"
        end
        ::continue::
    end
end

-- --- causals ---------------------------------------------------------
-- causal_bend: mirror \__numodel_check_obstacle.  Iterates occupied in
-- declaration order (we look up varlist members rather than the table
-- itself, so the result is deterministic regardless of hash order).

local function causal_bend(m, src, tgt)
    local L1 = m.layout[src]; local L2 = m.layout[tgt]
    if not (L1 and L2) then return "none" end
    local x1, y1, x2, y2 = L1.gridx, L1.gridy, L2.gridx, L2.gridy
    if not (x1 and y1 and x2 and y2) then return "none" end
    local lo_x, hi_x = math.min(x1,x2), math.max(x1,x2)
    local lo_y, hi_y = math.min(y1,y2), math.max(y1,y2)
    local function obstacle_bend(px, py)
        if (px == x1 and py == y1) or (px == x2 and py == y2) then
            return nil
        end
        if (px - x1) * (y2 - y1) == (py - y1) * (x2 - x1)
           and px >= lo_x and px <= hi_x
           and py >= lo_y and py <= hi_y
        then
            if 2 * py > y1 + y2 then return "right" else return "left" end
        end
        return nil
    end
    -- Walk all occupied cells in declaration order.
    for name, _ in var_iter(m) do
        local L = m.layout[name]
        if L and L.gridx and L.gridy and name ~= src and name ~= tgt then
            local b = obstacle_bend(L.gridx, L.gridy)
            if b then return b end
        end
    end
    -- Phantom-valve cells (cloud->valve slot adjacent to a stock with
    -- stock_phantom_valve) are virtual obstacles: they aren't in the
    -- varlist but do occupy a grid cell.  Iterate the owning stocks in
    -- declaration order so the bend choice stays deterministic.  Skip
    -- the phantom valve when its owning stock is the src or tgt of the
    -- causal — the same exemption the regular pass applies to endpoints.
    local F = m.flows or {}
    local pv = F.stock_phantom_valve
    if pv then
        for name, _ in var_iter(m) do
            if pv[name] and name ~= src and name ~= tgt then
                local L = m.layout[name]
                if L and L.sv_gridx then
                    local sy = L.sv_gridy or L.gridy
                    if sy then
                        local b = obstacle_bend(L.sv_gridx, sy)
                        if b then return b end
                    end
                end
            end
        end
    end
    return "none"
end

function M.causals(p, diagram_style)
    diagram_style = diagram_style or "tight"
    local m = ensure_meta(p)
    local F = m.flows
    m.causals = {}
    -- Iterate deps in declaration order of the *target*.
    for tgt, _ in var_iter(m) do
        local deplist = m.deps[tgt]
        if deplist then
            local tmeta = m.meta[tgt]
            local tL    = m.layout[tgt]
            local tgt_ok = tmeta and tmeta.type ~= "system"
                       and tL and tL.gridx and tL.gridx ~= -1
            if tgt_ok then
                for _, src in ipairs(deplist) do
                    local sm = m.meta[src]
                    local sL = m.layout[src]
                    local skip = false
                    if not sm or sm.type == "system" then skip = true end
                    if not skip and (not sL or sL.gridx == nil
                                            or sL.gridx == -1) then
                        skip = true
                    end
                    if not skip and F.inflow[tgt] == src then skip = true end
                    if not skip and F.outflow[tgt] == src then skip = true end
                    if not skip then
                        local bend = causal_bend(m, src, tgt)
                        local tgt_is_valve =
                            (F.valve_for[tgt] ~= nil)
                         or (F.outvalve_for[tgt] ~= nil)
                         or (F.between_valve[tgt] ~= nil)
                        -- In tight style a causal from a stock to its
                        -- own valve runs along the flow-arrow path; the
                        -- straight causal would be hidden by the flow.
                        -- Force a bend so it stays visible.  Only when
                        -- the stock and the valve sit on the *same*
                        -- row — when the gridmaxx wrap (or a manual
                        -- gridy) puts them on different rows the
                        -- causal goes vertical and never runs along
                        -- the flow pipe, so a straight arrow is fine.
                        -- Forrester and edu keep the aux node separate,
                        -- so the straight arrow there is fine too.
                        if bend == "none" and diagram_style == "tight"
                           and sm.type == "stock" and tgt_is_valve
                           and sL.gridy == tL.gridy
                           and (F.valve_for[tgt]      == src
                             or F.outvalve_for[tgt]   == src
                             or F.between_valve[tgt]  == src
                             or F.between_target[tgt] == src)
                        then
                            bend = "right"
                        end
                        m.causals[#m.causals + 1] = {
                            src = src, tgt = tgt,
                            bend = bend,
                            tgt_is_valve = tgt_is_valve,
                        }
                    end
                end
            end
        end
    end
end

function M.compute_layout(p, diagram_style, max_gridx)
    M.build_deps(p)
    M.classify_flows(p)
    M.populate_occupied(p)
    M.auto_layout(p, diagram_style, max_gridx)
    M.causals(p, diagram_style)
end

-- --- dump_layout (snapshot serializer) -------------------------------

local function sorted_keys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end
    table.sort(keys)
    return keys
end

local function fmt_int(v)
    if v == nil then return "" end
    return tostring(v)
end

function M.dump_layout(p)
    local m = M.models[p]
    if not m then return "(no model)\n" end
    local out = {}
    out[#out+1] = "prefix=" .. p
    out[#out+1] = "vars:"
    for name, meta in var_iter(m) do
        local L = m.layout and m.layout[name] or {}
        out[#out+1] = string.format(
            "  %s: type=%s text=%s gridx=%s gridy=%s role=%s vpos_x=%s vpos_y=%s",
            name, meta.type, meta.text,
            fmt_int(L.gridx), fmt_int(L.gridy),
            L.role or "",
            fmt_int(L.vpos_x), fmt_int(L.vpos_y))
    end
    local F = m.flows or {}
    local function dump_map(label, t)
        out[#out+1] = label .. ":"
        for _, k in ipairs(sorted_keys(t or {})) do
            out[#out+1] = "  " .. k .. " -> " .. tostring(t[k])
        end
    end
    dump_map("flows.inflow",              F.inflow)
    dump_map("flows.outflow",             F.outflow)
    dump_map("flows.valve_for",           F.valve_for)
    dump_map("flows.outvalve_for",        F.outvalve_for)
    dump_map("flows.between_valve",       F.between_valve)
    dump_map("flows.between_target",      F.between_target)
    dump_map("flows.stock_valve",         F.stock_valve)
    dump_map("flows.stock_phantom_valve", F.stock_phantom_valve)
    out[#out+1] = "flows.valve_extra_targets:"
    for _, k in ipairs(sorted_keys(F.valve_extra_targets or {})) do
        out[#out+1] = "  " .. k .. " -> " ..
            table.concat(F.valve_extra_targets[k], ",")
    end
    out[#out+1] = "flows.outvalve_extra_sources:"
    for _, k in ipairs(sorted_keys(F.outvalve_extra_sources or {})) do
        out[#out+1] = "  " .. k .. " -> " ..
            table.concat(F.outvalve_extra_sources[k], ",")
    end
    out[#out+1] = "deps:"
    for _, k in ipairs(sorted_keys(m.deps or {})) do
        out[#out+1] = "  " .. k .. " -> " .. table.concat(m.deps[k], ",")
    end
    out[#out+1] = "causals:"
    for _, c in ipairs(m.causals or {}) do
        out[#out+1] = string.format(
            "  %s -> %s bend=%s tgt_is_valve=%s",
            c.src, c.tgt, c.bend, tostring(c.tgt_is_valve))
    end
    out[#out+1] = ""
    return table.concat(out, "\n")
end

-- ====================================================================
-- Model export API
-- ====================================================================
-- The supported way for other packages (e.g. numodel-coach) to read a
-- model.  Returns a fresh copy, so callers may modify it freely:
--
--   {
--     prefix = "ball",
--     vars = {                         -- declaration order
--       { name = "ballV", short = "V", text = "v", type = "stock",
--         value = 0, value_expr = "0", unit = "\\m \\per \\s ",
--         sigfigs = 3, has_start = true,
--         axis_min = 0, axis_max = 100,    -- axis range, or nil
--         axis_source = "diagram" },       -- "diagram": as drawn by
--                                          -- \diagrammodel; "computed":
--                                          -- nice_range of the series
--       ...
--     },
--     program = {                      -- rows in \textmodel order
--       { kind = "calc",    target = "ballV", expr = "\\ballV + ..." },
--       { kind = "ternary", target = ..., expr = "c ? a : b",
--         starred = false },
--       { kind = "text",    text = "..." },     -- \mruletext
--       { kind = "stop",    expr = "\\ballY <= 2" },
--     },
--     stop = "\\ballY <= 2",          -- nil without \mstop
--     maxiter = 20000,                 -- \numodelsetup{maxiter}; also
--                                      -- the exported iteration count
--   }
--
-- Expressions and units are the detokenized user input: variables
-- appear as their full macro names (\ballV), units as siunitx macros.
-- Translating them is up to the exporter.  Returns nil for an unknown
-- prefix.

local function copy_row(r)
    local c = {}
    for k, v in pairs(r) do c[k] = v end
    return c
end

function M.get_model(p)
    local m = M.models[p]
    if not m then return nil end
    local out = { prefix = p, vars = {}, program = {}, stop = m.stop,
        maxiter = M.settings.maxiter }
    local seen = {}
    for name, meta in var_iter(m) do
        -- \mvar on an existing name registers it a second time; the
        -- export lists every variable once, at its first position.
        if meta and not seen[name] then
            seen[name] = true
            -- Axis range: as drawn by \diagrammodel, else what a
            -- diagram of the computed series would get.
            local amin, amax, asrc
            if m.axis and m.axis[name] then
                amin, amax, asrc = m.axis[name].min, m.axis[name].max, "diagram"
            else
                local data = m.steps and m.steps[name]
                if data and #data > 0 then
                    local lo, hi = math.huge, -math.huge
                    for _, x in ipairs(data) do
                        if x < lo then lo = x end
                        if x > hi then hi = x end
                    end
                    amin, amax = M.nice_range(lo, hi)
                    if amin then asrc = "computed" end
                end
            end
            out.vars[#out.vars + 1] = {
                name       = name,
                short      = name:sub(1, #p) == p and name:sub(#p + 1) or name,
                text       = meta.text,
                type       = meta.type,
                value      = meta.value,
                value_expr = meta.value_expr,
                unit       = meta.unit,
                sigfigs    = meta.sigfigs,
                has_start  = meta.value ~= nil,
                blank      = meta.blank,
                axis_min   = amin,
                axis_max   = amax,
                axis_source = asrc,
            }
        end
    end
    for i, r in ipairs(m.program or {}) do
        out.program[i] = copy_row(r)
    end
    return out
end

-- Human-readable dump of get_model(p), for tests and debugging.
function M.dump_model(p)
    local g = M.get_model(p)
    if not g then return "(no model)\n" end
    local out = { "prefix=" .. p, "vars:" }
    for _, v in ipairs(g.vars) do
        out[#out+1] = string.format(
            "  %s: short=%s type=%s text=%s value=%s value_expr=%s"
            .. " unit=%s sigfigs=%s",
            v.name, v.short, v.type, v.text, tostring(v.value),
            tostring(v.value_expr), tostring(v.unit), tostring(v.sigfigs))
        if v.blank then out[#out] = out[#out] .. " blank" end
        if v.axis_min then
            out[#out] = out[#out] .. string.format(" axis=[%s,%s](%s)",
                tostring(v.axis_min), tostring(v.axis_max), v.axis_source)
        end
    end
    out[#out+1] = "program:"
    for _, r in ipairs(g.program) do
        if r.kind == "text" then
            out[#out+1] = "  text: " .. r.text
        elseif r.kind == "stop" then
            out[#out+1] = "  stop" .. (r.blank and "[blank]" or "") .. ": "
                .. r.expr
        else
            out[#out+1] = string.format("  %s%s%s: %s := %s", r.kind,
                r.starred and "*" or "", r.blank and "[blank]" or "",
                r.target, r.expr)
        end
    end
    out[#out+1] = "stop=" .. tostring(g.stop)
    out[#out+1] = "maxiter=" .. tostring(g.maxiter)
    out[#out+1] = ""
    return table.concat(out, "\n")
end

-- ====================================================================
-- Plain-text rendering (Coachtaal and the English syllabus notation)
-- ====================================================================
-- Turns a model from get_model into plain text that can be typed into
-- modelling software: model rules and initial values, without math
-- mode.  Used by exporters such as numodel-coach; usable on its own
-- for a .txt per model (write_plaintext).
--
--   numodel.plain_name(text)           TeX display name -> plain name
--   numodel.plain_unit(unit)           siunitx input    -> "m/s^2"
--   numodel.plain_expr(expr, names, D) l3fp expression  -> plain text
--   numodel.plaintext(p, opts)         { body, init, names, warnings }
--   numodel.write_plaintext(p, path, opts)
--
-- opts.dialect is "NL" (Coachtaal, the default) or "EN".  The keyword
-- tables below mirror numodel-NL.def / numodel-EN.def; keep them in
-- sync.  They are separate because an export follows the target
-- software, not the syntax the document typesets.

M.dialects = {
    NL = {
        ["if"] = "Als", ["then"] = "Dan", ["else"] = "Anders",
        endif = "EindAls", ["and"] = "EN", ["or"] = "OF",
        ["not"] = "NIET", stop = "Stop",
        sign = "Teken", abs = "Abs", sqrt = "Sqrt", exp = "Exp",
        ln = "Ln", sin = "Sin", cos = "Cos", tan = "Tan",
        asin = "Arcsin", acos = "Arccos", atan = "Arctan",
        min = "Min", max = "Max", floor = "Entier", round = "Round",
        pi = "Pi",
        decimal = ",", argsep = ";", comment = "'",
        th_model = "Modelregels", th_initvals = "Startwaarden",
    },
    EN = {
        ["if"] = "IF", ["then"] = "THEN", ["else"] = "ELSE",
        endif = "ENDIF", ["and"] = "AND", ["or"] = "OR",
        ["not"] = "NOT", stop = "STOP",
        sign = "SIGN", abs = "ABS", sqrt = "SQRT", exp = "EXP",
        ln = "LN", sin = "SIN", cos = "COS", tan = "TAN",
        asin = "ARCSIN", acos = "ARCCOS", atan = "ARCTAN",
        min = "MIN", max = "MAX", floor = "INT", round = "ROUND",
        pi = "PI",
        decimal = ".", argsep = ",", comment = "'",
        th_model = "Model rules", th_initvals = "Initial values",
    },
}

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
-- Length in characters (UTF-8), for aligning comments after Δt or [ω].
local function ulen(s) return utf8.len(s) or #s end

-- --- names ------------------------------------------------------------

local greek = {
    alpha = "α", beta = "β", gamma = "γ", delta = "δ",
    epsilon = "ε", varepsilon = "ε", zeta = "ζ", eta = "η",
    theta = "θ", vartheta = "θ", iota = "ι", kappa = "κ",
    lambda = "λ", mu = "μ", nu = "ν", xi = "ξ", pi = "π",
    rho = "ρ", varrho = "ρ", sigma = "σ", tau = "τ",
    upsilon = "υ", phi = "φ", varphi = "φ", chi = "χ", psi = "ψ",
    omega = "ω",
    Gamma = "Γ", Delta = "Δ", Theta = "Θ", Lambda = "Λ", Xi = "Ξ",
    Pi = "Π", Sigma = "Σ", Upsilon = "Υ", Phi = "Φ", Psi = "Ψ",
    Omega = "Ω",
}
-- Public: also used by numodel-coach for instruction texts.
M.greek = greek

-- Wrappers whose argument is kept as-is: \text{res} -> res.
local name_wrappers = {
    text = true, mathrm = true, mathit = true, mathbf = true,
    mathsf = true, mathtt = true, textrm = true, textit = true,
    textbf = true, textnormal = true, operatorname = true,
    boldsymbol = true, mathnormal = true,
}
-- Spacing commands: dropped.
local name_spacing = { [","] = true, [";"] = true, [":"] = true,
    ["!"] = true, [" "] = true, quad = true, qquad = true }

-- CoachTaal reserved words (Coach 7 handleiding, "Gereserveerde
-- woorden"); compared case-insensitively.  A variable with such a name
-- is put in brackets.
local reserved = {}
for w in ([[Aan Abs Afgeleide AfgeleideGlad Als Anders ArcCos ArcSin
    ArcTan Bezier Bit Cos Dan Delta DeltaFil Doe Domein DrukAf
    EenheidStap EindAls EindDoe EindFunctie EindProcedure En Entier Exp
    Fac Filter Functie Geluid Herhaal Histogram Index Integraal Kolom Ln
    Log LoopTijd Max Min Niet Niveau Of Pi Procedure Puls PulsHerhaald
    Rand Repeteer ResetTellers Round Sin SlaOp Som Spline Sqr Sqrt Stop
    Stopwatch Tan Teken Tel Teller TotDat TotHier TussenTijd
    TweedeAfgeleide TweedeAfgeleideGlad Uit Wacht WasBitHoog WasBitLaag
    WisData Wordt ZetAan ZetAanAbsoluut ZetNiveau ZetUit ZetUitAbsoluut
    Zodra Zolang]]):gmatch("%a+") do
    reserved[w:lower()] = true
end

-- TeX display name -> plain name, e.g. F_{\text{res}} -> F_res,
-- \Delta t -> Δt.  CoachTaal allows bare names of ASCII letters,
-- digits and _ (not starting with a digit), plus Δt for the time
-- step; anything else -- other Greek letters, spaces, reserved
-- words -- is put in brackets, as Coach itself does: [ω], [Max].
-- Returns the name and, for unknown control sequences, a warning.
function M.plain_name(text)
    local warn
    local s = (text or ""):gsub("\\(%a+)%s*", function(cs)
        if greek[cs] then return greek[cs] end
        if name_wrappers[cs] then return "" end
        if name_spacing[cs] then return "" end
        warn = "unknown control sequence \\" .. cs .. " in name '"
            .. text .. "'"
        return cs
    end)
    s = s:gsub("\\([^%a])", function(c)
        return name_spacing[c] and "" or c
    end)
    s = s:gsub("[{}%s$]", "")
    if s == "" then return "[]", "empty name for '" .. tostring(text) .. "'" end
    if s == "Δt" then return s, warn end
    if s:find("^[%a_][%w_]*$") and not reserved[s:lower()] then
        return s, warn
    end
    return "[" .. s .. "]", warn
end

-- --- units ------------------------------------------------------------

local unit_symbols = {
    metre = "m", meter = "m", m = "m", second = "s", s = "s",
    gram = "g", g = "g", kilogram = "kg", kg = "kg",
    ampere = "A", A = "A", kelvin = "K", K = "K", mole = "mol",
    mol = "mol", candela = "cd", cd = "cd",
    newton = "N", N = "N", joule = "J", J = "J", watt = "W", W = "W",
    pascal = "Pa", Pa = "Pa", hertz = "Hz", Hz = "Hz",
    coulomb = "C", C = "C", volt = "V", V = "V", ohm = "Ohm",
    farad = "F", F = "F", tesla = "T", T = "T", weber = "Wb",
    Wb = "Wb", henry = "H", H = "H", siemens = "S", S = "S",
    becquerel = "Bq", Bq = "Bq", gray = "Gy", Gy = "Gy",
    sievert = "Sv", Sv = "Sv", lumen = "lm", lux = "lx",
    litre = "L", liter = "L", L = "L", l = "L",
    minute = "min", hour = "h", h = "h", day = "d",
    degreeCelsius = "°C", celsius = "°C", degree = "°",
    percent = "%", bar = "bar", electronvolt = "eV", eV = "eV",
    astronomicalunit = "au", au = "au", dalton = "Da", Da = "Da",
    tonne = "t", hectare = "ha", angstrom = "Å", bel = "B",
    decibel = "dB", dB = "dB", neper = "Np", radian = "rad",
    steradian = "sr", arcminute = "'", arcsecond = "''",
}
local unit_prefixes = {
    quecto = "q", ronto = "r", yocto = "y", zepto = "z", atto = "a",
    femto = "f", pico = "p", nano = "n", micro = "u", milli = "m",
    centi = "c", deci = "d", deca = "da", deka = "da", hecto = "h",
    kilo = "k", mega = "M", giga = "G", tera = "T", peta = "P",
    exa = "E", zetta = "Z", yotta = "Y", ronna = "R", quetta = "Q",
}
-- siunitx abbreviations with a prefix built in (\km, \mA, ...).
local unit_abbrev = {
    fg = "fg", pg = "pg", ng = "ng", ug = "ug", mg = "mg",
    pm = "pm", nm = "nm", um = "um", mm = "mm", cm = "cm",
    dm = "dm", km = "km", as = "as", fs = "fs", ps = "ps",
    ns = "ns", us = "us", ms = "ms", fmol = "fmol", pmol = "pmol",
    nmol = "nmol", umol = "umol", mmol = "mmol", kmol = "kmol",
    pA = "pA", nA = "nA", uA = "uA", mA = "mA", kA = "kA",
    ul = "uL", ml = "mL", hl = "hL", uL = "uL", mL = "mL",
    hL = "hL", mHz = "mHz", kHz = "kHz", MHz = "MHz", GHz = "GHz",
    mN = "mN", kN = "kN", MN = "MN", kPa = "kPa", MPa = "MPa",
    GPa = "GPa", mohm = "mOhm", kohm = "kOhm", Mohm = "MOhm",
    pV = "pV", nV = "nV", uV = "uV", mV = "mV", kV = "kV",
    nW = "nW", uW = "uW", mW = "mW", kW = "kW", MW = "MW",
    GW = "GW", uJ = "uJ", mJ = "mJ", kJ = "kJ", MJ = "MJ",
    GJ = "GJ", meV = "meV", keV = "keV", MeV = "MeV", GeV = "GeV",
    TeV = "TeV", kWh = "kWh", fF = "fF", pF = "pF", nF = "nF",
    uF = "uF", mF = "mF", nH = "nH", uH = "uH", mH = "mH",
    mT = "mT", uT = "uT", nT = "nT",
}

local function fmt_power(sym, e)
    if e == 1 then return sym end
    return sym .. "^" .. tostring(e)
end

-- siunitx unit input -> Coach-style plain unit: \m\per\s\squared ->
-- m/s^2, \kilo\gram\metre\per\second\squared -> kg*m/s^2,
-- \mole\per\litre\per\second -> mol/(L*s), \per\second -> 1/s.
-- Literal input (m/s, kg.m) is passed through without braces/spaces.
-- Returns the unit and, for unknown macros, a warning.
function M.plain_unit(unit)
    unit = unit or ""
    if not unit:find("\\") then
        local lit = unit:gsub("[{}%s~]", "")
        return lit, nil
    end
    local factors, warn = {}, nil
    local prefix, pre_power, per = "", nil, false
    local i, n = 1, #unit
    local function add(sym)
        local e = pre_power or 1
        factors[#factors + 1] = { sym = prefix .. sym, e = per and -e or e }
        prefix, pre_power, per = "", nil, false
    end
    local function last_power(k)
        local f = factors[#factors]
        if f then f.e = f.e * k end
    end
    local function read_group()
        local j = unit:find("%S", i)
        if not j or unit:sub(j, j) ~= "{" then return nil end
        local k = unit:find("}", j, true)
        if not k then return nil end
        i = k + 1
        return tonumber(trim(unit:sub(j + 1, k - 1)))
    end
    while i <= n do
        local c = unit:sub(i, i)
        if c == "\\" then
            local cs = unit:match("^%a+", i + 1) or ""
            i = i + 1 + #cs
            if cs == "per" then per = true
            elseif cs == "square" then pre_power = 2
            elseif cs == "cubic" then pre_power = 3
            elseif cs == "squared" then last_power(2)
            elseif cs == "cubed" then last_power(3)
            elseif cs == "tothe" then
                local k = read_group(); if k then last_power(k) end
            elseif cs == "raiseto" then pre_power = read_group()
            elseif unit_prefixes[cs] then prefix = unit_prefixes[cs]
            elseif unit_symbols[cs] then add(unit_symbols[cs])
            elseif unit_abbrev[cs] then add(unit_abbrev[cs])
            elseif cs ~= "" then
                warn = "unknown unit macro \\" .. cs .. " in '"
                    .. trim(unit) .. "'"
                add(cs)
            end
        elseif c:match("[%a%%°]") then
            -- Literal symbol mixed with macros (\kilo m): take a run.
            local run = unit:match("^[%a%%°\128-\255]+", i)
            i = i + #run
            add(run)
        else
            i = i + 1
        end
    end
    local num, den = {}, {}
    for _, f in ipairs(factors) do
        if f.e > 0 then num[#num + 1] = fmt_power(f.sym, f.e)
        elseif f.e < 0 then den[#den + 1] = fmt_power(f.sym, -f.e) end
    end
    local s = #num > 0 and table.concat(num, "*") or (#den > 0 and "1" or "")
    if #den == 1 then s = s .. "/" .. den[1]
    elseif #den > 1 then s = s .. "/(" .. table.concat(den, "*") .. ")" end
    return s, warn
end

-- --- expressions ------------------------------------------------------
-- An l3fp expression is parsed into a tree with l3fp's precedence and
-- printed with CoachTaal's.  The two differ, which is why a token-level
-- rewrite is not enough (Coach 7 handleiding, "Expressies"):
--   * Coach gives unary minus and ^ the same priority and evaluates
--     left to right, so l3fp's -x^2 = -(x^2) and a^b^c = a^(b^c) need
--     explicit parentheses.
--   * Relational expressions combined with En/Of/Niet must be in
--     parentheses: (x > 1) En (x < 2).
--   * l3fp binds juxtaposition tighter than / (1/2pi = 1/(2pi)); Coach
--     needs an explicit, parenthesised product.
-- Parentheses the user wrote are kept; others are added only where
-- needed.

local two_char_ops = {
    ["<="] = true, [">="] = true, ["!="] = true, ["=="] = true,
    ["&&"] = true, ["||"] = true, ["**"] = true,
}

local function tokenize(expr)
    local toks, i, n = {}, 1, #expr
    while i <= n do
        local c = expr:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c == "\\" then
            local cs = expr:match("^%a+", i + 1)
            if cs then
                toks[#toks + 1] = { t = "var", s = cs }
                i = i + 1 + #cs
            else
                i = i + 2      -- control symbol (\, etc.): ignore
            end
        elseif expr:match("^%.?%d", i) then
            local num = expr:match("^%d*%.?%d*", i)
            local ex = expr:match("^[eE][+-]?%d+", i + #num)
            if ex then num = num .. ex end
            toks[#toks + 1] = { t = "num", s = num }
            i = i + #num
        elseif c:match("%a") then
            local id = expr:match("^%a+", i)
            toks[#toks + 1] = { t = "id", s = id }
            i = i + #id
        elseif two_char_ops[expr:sub(i, i + 1)] then
            local op = expr:sub(i, i + 1)
            toks[#toks + 1] = { t = "op", s = op == "**" and "^" or op }
            i = i + 2
        elseif c == "{" or c == "(" then
            toks[#toks + 1] = { t = "(" }; i = i + 1
        elseif c == "}" or c == ")" then
            toks[#toks + 1] = { t = ")" }; i = i + 1
        elseif c == "," then
            toks[#toks + 1] = { t = "," }; i = i + 1
        else
            toks[#toks + 1] = { t = "op", s = c }; i = i + 1
        end
    end
    return toks
end

-- l3fp binding powers (higher binds tighter).
local infix_bp = {
    ["?"] = 1, ["||"] = 2, ["&&"] = 3,
    ["<"] = 4, [">"] = 4, ["<="] = 4, [">="] = 4, ["="] = 4,
    ["=="] = 4, ["!="] = 4,
    ["+"] = 5, ["-"] = 5, ["*"] = 6, ["/"] = 6,
    imul = 7, ["^"] = 9,
}
local PREFIX_BP = 8      -- unary +, -, !

local function starts_operand(tk)
    return tk and (tk.t == "num" or tk.t == "var" or tk.t == "id"
        or tk.t == "(")
end

-- Pratt parser over the token list.  Nodes:
--   {k="num",s} {k="var",s} {k="id",s} {k="call",s,args}
--   {k="paren",e} {k="neg",e} {k="pos",e} {k="not",e}
--   {k="bin",op,a,b} {k="tern",c,a,b}
local function parse(toks, W)
    local pos = 1
    local function peek() return toks[pos] end
    local function take() pos = pos + 1; return toks[pos - 1] end
    local expr
    local function nud()
        local tk = take()
        if not tk then
            W[#W + 1] = "incomplete expression"
            return { k = "num", s = "0" }
        end
        if tk.t == "num" then return { k = "num", s = tk.s } end
        if tk.t == "var" then return { k = "var", s = tk.s } end
        if tk.t == "id" then
            local nx = peek()
            if nx and nx.t == "(" then
                take()
                local args = {}
                if peek() and peek().t ~= ")" then
                    args[1] = expr(0)
                    while peek() and peek().t == "," do
                        take(); args[#args + 1] = expr(0)
                    end
                end
                if peek() and peek().t == ")" then take() end
                return { k = "call", s = tk.s, args = args }
            end
            return { k = "id", s = tk.s }
        end
        if tk.t == "(" then
            local e = expr(0)
            if peek() and peek().t == ")" then take() end
            return { k = "paren", e = e }
        end
        if tk.t == "op" and (tk.s == "-" or tk.s == "+" or tk.s == "!") then
            local e = expr(PREFIX_BP)
            return { k = tk.s == "-" and "neg" or tk.s == "+" and "pos"
                or "not", e = e }
        end
        W[#W + 1] = "unexpected '" .. (tk.s or tk.t) .. "' in expression"
        return nud()
    end
    expr = function(rbp)
        local left = nud()
        while true do
            local tk = peek()
            if not tk then break end
            local op, bp
            if tk.t == "op" and infix_bp[tk.s] then
                op, bp = tk.s, infix_bp[tk.s]
            elseif starts_operand(tk) then
                op, bp = "imul", infix_bp.imul
            else
                break        -- ")", ",", ":" or junk: let the caller see it
            end
            if bp <= rbp then break end
            if op ~= "imul" then take() end
            if op == "?" then
                local a = expr(0)
                if peek() and peek().t == "op" and peek().s == ":" then take() end
                local b = expr(bp - 1)          -- right associative
                left = { k = "tern", c = left, a = a, b = b }
            elseif op == "^" then
                left = { k = "bin", op = "^", a = left, b = expr(bp - 1) }
            else
                left = { k = "bin", op = op, a = left, b = expr(bp) }
            end
        end
        return left
    end
    local tree = expr(0)
    if pos <= #toks then
        W[#W + 1] = "trailing input ignored in expression"
    end
    return tree
end

local function fmt_number(s, D)
    if s:sub(1, 1) == "." then s = "0" .. s end
    s = s:gsub("[eE]", "E")
    if D.decimal ~= "." then s = s:gsub("%.", D.decimal) end
    return s
end

local relational = { ["<"] = true, [">"] = true, ["<="] = true,
    [">="] = true, ["="] = true, ["=="] = true, ["!="] = true }

-- CoachTaal printing strength (higher binds tighter).
local function strength(n)
    if n.k == "bin" then
        local op = n.op
        if op == "^" then return 60 end
        if op == "*" or op == "/" or op == "imul" then return 50 end
        if op == "+" or op == "-" then return 40 end
        if relational[op] then return 30 end
        if op == "&&" then return 20 end
        if op == "||" then return 10 end
    elseif n.k == "neg" or n.k == "pos" then return 60
    elseif n.k == "not" then return 25
    elseif n.k == "tern" then return 0 end
    return 100      -- num, var, id, call, paren
end

local print_node

local function paren(s) return "(" .. s .. ")" end

-- Function call -> plain text.  Rewrites that produce an operator
-- expression come back parenthesised, so they stay correct in any
-- context (x/cot(y) -> x/(1/Tan(y))).
local function print_call(n, ctx)
    local D, W = ctx.D, ctx.W
    local args = {}
    for i, a in ipairs(n.args) do args[i] = print_node(a, ctx) end
    local a1 = args[1] or ""
    -- Argument as a factor: parenthesised unless atomic.
    local f1 = n.args[1] and strength(n.args[1]) >= 100 and a1 or paren(a1)
    local function call(f, s) return f .. "(" .. s .. ")" end
    local deg = D.pi .. "/180*" .. f1
    local rad = "180/" .. D.pi .. "*"
    local direct = {
        sign = D.sign, abs = D.abs, sqrt = D.sqrt, exp = D.exp,
        ln = D.ln, sin = D.sin, cos = D.cos, tan = D.tan,
        asin = D.asin, acos = D.acos, floor = D.floor,
        min = D.min, max = D.max,
    }
    local name = n.s
    if direct[name] then
        return call(direct[name], table.concat(args, D.argsep))
    elseif name == "round" then
        if #args >= 2 then
            local p = "10^" .. (strength(n.args[2]) >= 100 and args[2]
                or paren(args[2]))
            return paren(call(D.round, f1 .. "*" .. p) .. "/" .. p)
        end
        return call(D.round, a1)
    elseif name == "trunc" then
        return call(D.sign, a1) .. "*" .. call(D.floor, call(D.abs, a1))
    elseif name == "atan" then
        if #args == 2 then
            W[#W + 1] = "atan(y,x) exported as " .. D.atan
                .. "(y/x): the quadrant is lost"
            local y = strength(n.args[1]) >= 100 and args[1] or paren(args[1])
            local x = strength(n.args[2]) >= 100 and args[2] or paren(args[2])
            return call(D.atan, y .. "/" .. x)
        end
        return call(D.atan, a1)
    elseif name == "ceil" then
        return paren("-" .. call(D.floor, "-" .. f1))
    elseif name == "cot" then return paren("1/" .. call(D.tan, a1))
    elseif name == "csc" then return paren("1/" .. call(D.sin, a1))
    elseif name == "sec" then return paren("1/" .. call(D.cos, a1))
    elseif name == "acot" then return call(D.atan, "1/" .. f1)
    elseif name == "acsc" then return call(D.asin, "1/" .. f1)
    elseif name == "asec" then return call(D.acos, "1/" .. f1)
    elseif name == "sind" then return call(D.sin, deg)
    elseif name == "cosd" then return call(D.cos, deg)
    elseif name == "tand" then return call(D.tan, deg)
    elseif name == "cotd" then return paren("1/" .. call(D.tan, deg))
    elseif name == "cscd" then return paren("1/" .. call(D.sin, deg))
    elseif name == "secd" then return paren("1/" .. call(D.cos, deg))
    elseif name == "asind" then return paren(rad .. call(D.asin, a1))
    elseif name == "acosd" then return paren(rad .. call(D.acos, a1))
    elseif name == "atand" then return paren(rad .. call(D.atan, a1))
    elseif name == "acotd" then return paren(rad .. call(D.atan, "1/" .. f1))
    elseif name == "acscd" then return paren(rad .. call(D.asin, "1/" .. f1))
    elseif name == "asecd" then return paren(rad .. call(D.acos, "1/" .. f1))
    end
    W[#W + 1] = "function " .. name .. "() has no plain-text equivalent;"
        .. " exported unchanged"
    return call(name, table.concat(args, D.argsep))
end

print_node = function(n, ctx)
    local D, W = ctx.D, ctx.W
    local k = n.k
    if k == "num" then return fmt_number(n.s, D)
    elseif k == "var" then
        local nm = ctx.names[n.s]
        if not nm then
            W[#W + 1] = "unknown variable \\" .. n.s
            nm = n.s
        end
        return nm
    elseif k == "id" then
        local s = n.s
        if s == "pi" then return D.pi
        elseif s == "deg" then return paren(D.pi .. "/180")
        elseif s == "true" then return "1"
        elseif s == "false" then return "0" end
        W[#W + 1] = "unknown identifier '" .. s .. "'"
        return s
    elseif k == "call" then return print_call(n, ctx)
    elseif k == "paren" then return paren(print_node(n.e, ctx))
    elseif k == "neg" or k == "pos" then
        -- Coach: -x^2 = (-x)^2, so a power operand needs parentheses.
        local e = n.e
        local s = print_node(e, ctx)
        if strength(e) < 100 then s = paren(s) end
        return (k == "neg" and "-" or "+") .. s
    elseif k == "not" then
        -- Niet x, Niet(x > 1)
        local s = print_node(n.e, ctx)
        if n.e.k == "paren" then return D["not"] .. s end
        if strength(n.e) < 100 then return D["not"] .. paren(s) end
        return D["not"] .. " " .. s
    elseif k == "tern" then
        W[#W + 1] = "nested conditional (?:) cannot be exported"
        return paren(print_node(n.c, ctx) .. " ? " .. print_node(n.a, ctx)
            .. " : " .. print_node(n.b, ctx))
    end
    -- Binary operator.
    local op, a, b = n.op, n.a, n.b
    local s = strength(n)
    local sa, sb = print_node(a, ctx), print_node(b, ctx)
    local la, lb = strength(a), strength(b)
    local wrap_a, wrap_b
    if op == "&&" or op == "||" then
        -- Relational operands of En/Of must be parenthesised.
        wrap_a = (a.k == "bin" and relational[a.op]) or la < s
        wrap_b = (b.k == "bin" and relational[b.op]) or lb < s
    elseif op == "^" then
        -- Coach evaluates ^ left to right, at the priority of unary
        -- minus: both operands must be atomic, except that a negated
        -- atom may stand in the exponent (A^-B).
        wrap_a = la <= 60
        wrap_b = lb < 60 or (b.k == "bin" and b.op == "^")
            or ((b.k == "neg" or b.k == "pos") and strength(b.e) < 100)
    elseif relational[op] then
        wrap_a = la <= s
        wrap_b = lb <= s
    else
        wrap_a = la < s
        -- Left to right: a-(b+c), a/(b*c) and a/(2pi) keep their group.
        wrap_b = lb < s or (lb == s and (op == "-" or op == "/"
            or op == "imul"))
    end
    if wrap_a then sa = paren(sa) end
    if wrap_b then sb = paren(sb) end
    local sym
    if op == "&&" then sym = " " .. D["and"] .. " "
    elseif op == "||" then sym = " " .. D["or"] .. " "
    elseif op == "==" then sym = " = "
    elseif op == "!=" then sym = " <> "
    elseif relational[op] or op == "+" or op == "-" then
        sym = " " .. op .. " "
    elseif op == "imul" then sym = "*"
    else sym = op end
    return sa .. sym .. sb
end

-- l3fp expression -> plain text in dialect D (a table from M.dialects
-- or a dialect name).  names maps control-word names (without the
-- backslash) to plain names.  Returns the text and a list of warnings.
function M.plain_expr(expr, names, D)
    if type(D) ~= "table" then D = M.dialects[D or "NL"] end
    local W = {}
    local tree = parse(tokenize(expr or ""), W)
    return print_node(tree, { D = D, W = W, names = names or {} }), W
end

-- Split a top-level conditional "c ? a : b" (as in \mrule).  Returns
-- the printed condition and branches, or nil when expr is not one.
local function plain_ternary(expr, names, D, W)
    local tree = parse(tokenize(expr or ""), W)
    if tree.k ~= "tern" then return nil end
    local ctx = { D = D, W = W, names = names }
    return print_node(tree.c, ctx), print_node(tree.a, ctx),
        print_node(tree.b, ctx)
end

-- Whole model -> { body = rules text, init = initial values text,
-- names = { fullname -> plain name }, warnings = { ... } }.
function M.plaintext(p, opts)
    opts = opts or {}
    local D = M.dialects[opts.dialect or "NL"]
    if not D then error("numodel: unknown dialect " .. tostring(opts.dialect)) end
    local g = M.get_model(p)
    if not g then return nil end
    -- blanks=open (pupil's version): [blank] rules, stop conditions and
    -- start values become comments "' lhs := ..."; filled: in full.
    local open = (opts.blanks or M.settings.blanks) ~= "filled"
    local W, names, used = {}, {}, {}
    local function note(w) if w then W[#W + 1] = w end end
    for _, v in ipairs(g.vars) do
        local nm, w = M.plain_name(v.text)
        note(w)
        if used[nm] then
            note("variables " .. used[nm] .. " and " .. v.name
                .. " both export as '" .. nm .. "'; using '" .. v.short
                .. "' for " .. v.name)
            nm = v.short
        end
        used[nm] = v.name
        names[v.name] = nm
    end
    local function expr(e)
        local s, ws = M.plain_expr(e, names, D)
        for _, w in ipairs(ws) do W[#W + 1] = w end
        return s
    end
    local body = {}
    for _, r in ipairs(g.program) do
        if open and r.blank and (r.kind == "calc" or r.kind == "ternary") then
            body[#body + 1] = D.comment .. " " .. names[r.target] .. " := ..."
        elseif open and r.blank and r.kind == "stop" then
            body[#body + 1] = D.comment .. " " .. D["if"] .. " ... "
                .. D["then"] .. " " .. D.stop .. " " .. D.endif
        elseif r.kind == "calc" then
            body[#body + 1] = names[r.target] .. " := " .. expr(r.expr)
        elseif r.kind == "ternary" then
            local c, a, b = plain_ternary(r.expr, names, D, W)
            local lhs = names[r.target]
            if not c then
                body[#body + 1] = lhs .. " := " .. expr(r.expr)
            elseif r.starred then
                body[#body + 1] = D["if"] .. " " .. c .. " " .. D["then"]
                body[#body + 1] = "  " .. lhs .. " := " .. a
                body[#body + 1] = D["else"]
                body[#body + 1] = "  " .. lhs .. " := " .. b
                body[#body + 1] = D.endif
            else
                body[#body + 1] = D["if"] .. " " .. c .. " " .. D["then"]
                    .. " " .. lhs .. " := " .. a .. " " .. D["else"]
                    .. " " .. lhs .. " := " .. b .. " " .. D.endif
            end
        elseif r.kind == "stop" then
            body[#body + 1] = D["if"] .. " " .. expr(r.expr) .. " "
                .. D["then"] .. " " .. D.stop .. " " .. D.endif
        elseif r.kind == "text" then
            -- Free TeX: keep its words as a comment.
            local t = r.text:gsub("\\%a+%s*", " "):gsub("[{}$\\]", "")
            t = trim(t:gsub("%s+", " "))
            note("free-text row exported as a comment: " .. t)
            body[#body + 1] = D.comment .. " " .. t
        end
    end
    -- Initial values: name := value, unit as an aligned comment.
    local rows, width = {}, 0
    for _, v in ipairs(g.vars) do
        if v.has_start and open and v.blank then
            rows[#rows + 1] = { D.comment .. " " .. names[v.name] .. " := ...", "" }
        elseif v.has_start then
            local lhs = names[v.name] .. " := " .. expr(v.value_expr)
            local u, w = M.plain_unit(v.unit)
            note(w)
            rows[#rows + 1] = { lhs, u }
            if ulen(lhs) > width then width = ulen(lhs) end
        end
    end
    local init = {}
    for _, r in ipairs(rows) do
        if r[2] ~= "" then
            init[#init + 1] = r[1] .. string.rep(" ", width - ulen(r[1]) + 2)
                .. D.comment .. r[2]
        else
            init[#init + 1] = r[1]
        end
    end
    return {
        body = table.concat(body, "\n") .. "\n",
        init = table.concat(init, "\n") .. "\n",
        names = names,
        warnings = W,
    }
end

-- Write model rules and initial values to one text file, each part
-- under a comment header.  Returns the plaintext table.
function M.write_plaintext(p, path, opts)
    local r = M.plaintext(p, opts)
    if not r then return nil end
    local D = M.dialects[(opts and opts.dialect) or "NL"]
    local f = assert(io.open(path, "w"))
    f:write(D.comment, " ", D.th_model, "\n", r.body, "\n",
            D.comment, " ", D.th_initvals, "\n", r.init)
    f:close()
    return r
end

-- --- thin TeX-side getters (called via \directlua) -------------------

local function meta_field(p, name, field)
    local m = M.models[p]; if not m or not m.meta then return "" end
    local meta = m.meta[name]; if not meta then return "" end
    return meta[field] or ""
end

local function layout_field(p, name, field)
    local m = M.models[p]; if not m or not m.layout then return "" end
    local L = m.layout[name]; if not L then return "" end
    return L[field]
end

function M.role_of(p, name)
    local r = layout_field(p, name, "role"); tex.sprint(r or "")
end
function M.gridx_of(p, name)
    local v = layout_field(p, name, "gridx")
    tex.sprint(v == nil and "-1" or tostring(v))
end
function M.gridy_of(p, name)
    local v = layout_field(p, name, "gridy")
    tex.sprint(v == nil and "-1" or tostring(v))
end
function M.vpos_x_of(p, name)
    local v = layout_field(p, name, "vpos_x")
    tex.sprint(v == nil and "" or tostring(v))
end
function M.vpos_y_of(p, name)
    local v = layout_field(p, name, "vpos_y")
    tex.sprint(v == nil and "" or tostring(v))
end

-- ====================================================================
-- TeX-side state writeback after compute_layout.
-- ====================================================================
-- Emits expl3 statements that fill the TeX-side cache the emitters
-- (place_node, flow-builders, emit_natural_and_phantom,
-- emit_stock_valve) still read.  After this call:
--   * \<name>gridx / \<name>gridy hold the auto-placed coordinates
--   * \l__numodel_valve_for_prop / outvalve_for_prop / between_valve_prop
--     / between_target_prop / stock_valve_prop are populated 1:1 from
--     numodel.models[p].flows
--   * \l__numodel_vpos_x_prop holds the phantom-valve gridx
--     (forrester / edu only); vpos_y is implicit (always 0)
--
-- Caller side (\__numodel_lua_layout_writeback:) clears the props
-- before invoking this so we always render from a clean slate.

function M.tex_writeback(p)
    local m = M.models[p]
    if not m then return end
    local lines = {}
    local function emit(s) lines[#lines+1] = s end

    -- 1. gridx / gridy per var.
    for _, name in ipairs(m.varlist) do
        local L = m.layout and m.layout[name] or {}
        local gx = L.gridx == nil and -1 or L.gridx
        local gy = L.gridy == nil and -1 or L.gridy
        emit(string.format(
            "\\cs_gset:cpe { %s gridx } { %d }", name, gx))
        emit(string.format(
            "\\cs_gset:cpe { %s gridy } { %d }", name, gy))
    end

    -- 2. vpos_x / vpos_y props (only when set — diagram-style=forrester|edu).
    for _, name in ipairs(m.varlist) do
        local L = m.layout and m.layout[name] or {}
        if L.vpos_x then
            emit(string.format(
                "\\prop_put:Nnn \\l__numodel_vpos_x_prop {%s} {%d}",
                name, L.vpos_x))
        end
        if L.vpos_y then
            emit(string.format(
                "\\prop_put:Nnn \\l__numodel_vpos_y_prop {%s} {%d}",
                name, L.vpos_y))
        end
    end

    -- 3. flow props — match the maps that classify_flows builds.
    local F = m.flows or {}
    local function dump_prop(propname, t)
        for k, v in pairs(t or {}) do
            emit(string.format(
                "\\prop_put:Nnn \\%s {%s} {%s}",
                propname, k, v))
        end
    end
    dump_prop("l__numodel_valve_for_prop",           F.valve_for)
    dump_prop("l__numodel_outvalve_for_prop",        F.outvalve_for)
    dump_prop("l__numodel_between_valve_prop",       F.between_valve)
    dump_prop("l__numodel_between_target_prop",      F.between_target)
    dump_prop("l__numodel_stock_valve_prop",         F.stock_valve)
    dump_prop("l__numodel_stock_phantom_valve_prop", F.stock_phantom_valve)

    -- valve_extra_targets: one entry per shared inflow valve.  The
    -- prop value is a comma-list of secondary stock names; the
    -- renderer iterates it to draw a curved branch per extra target.
    for fv, list in pairs(F.valve_extra_targets or {}) do
        if #list > 0 then
            emit(string.format(
                "\\prop_put:Nnn \\l__numodel_valve_extras_prop {%s} {%s}",
                fv, table.concat(list, ",")))
        end
    end
    -- outvalve_extra_sources: mirror of valve_extra_targets for shared
    -- outflow valves.  Value = comma-list of extra source stocks
    -- (primary lives in outvalve_for[fv]).
    for fv, list in pairs(F.outvalve_extra_sources or {}) do
        if #list > 0 then
            emit(string.format(
                "\\prop_put:Nnn \\l__numodel_outvalve_extras_prop {%s} {%s}",
                fv, table.concat(list, ",")))
        end
    end

    -- stock_valve / stock_phantom_valve also store the virtual valve-slot
    -- coordinates as "<stock>__svgx" / "<stock>__svgy" -> N.  The y-slot
    -- is non-zero only when the auto layout had to wrap (gridmaxx),
    -- pushing the stock row up — without that the emitter's hardcoded
    -- y=0 would render the phantom valve at row 0 instead of next to
    -- the shifted stock.
    for stock, _ in pairs(F.stock_valve or {}) do
        local L = m.layout and m.layout[stock] or {}
        if L.sv_gridx then
            emit(string.format(
                "\\prop_put:Nnn \\l__numodel_stock_valve_prop {%s__svgx} {%d}",
                stock, L.sv_gridx))
            emit(string.format(
                "\\prop_put:Nnn \\l__numodel_stock_valve_prop {%s__svgy} {%d}",
                stock, L.sv_gridy or L.gridy or 0))
        end
    end
    for stock, _ in pairs(F.stock_phantom_valve or {}) do
        local L = m.layout and m.layout[stock] or {}
        if L.sv_gridx then
            emit(string.format(
                "\\prop_put:Nnn \\l__numodel_stock_phantom_valve_prop {%s__svgx} {%d}",
                stock, L.sv_gridx))
            emit(string.format(
                "\\prop_put:Nnn \\l__numodel_stock_phantom_valve_prop {%s__svgy} {%d}",
                stock, L.sv_gridy or L.gridy or 0))
        end
    end

    -- tex.print injects under the *caller*'s catcodes, so wrap with
    -- \ExplSyntaxOn/Off so `_`/`:` are letters when the cs-names get
    -- tokenized.  (Caller is user-document scope.)
    table.insert(lines, 1, "\\ExplSyntaxOn")
    lines[#lines+1] = "\\ExplSyntaxOff"
    tex.print(lines)
end

-- ====================================================================
-- A2 — Causal-arrow emitter.
-- ====================================================================
-- Emits one \draw line per causal in numodel.models[p].causals.
-- Causals targeting a valve are pushed to \l__numodel_late_causals_tl
-- (rendered after the white-filled valve overlay layer); the rest go
-- to \g__numodel_graphic_tl directly.  Mirrors the demux that the
-- expl3 \prop_map_inline:Nn \g_numodel_deps_prop loop did before A2.

function M.emit_causals(p)
    local m = M.models[p]
    if not m or not m.causals then return end
    local lines = {}
    for _, c in ipairs(m.causals) do
        -- Use ~ (expl3 letter-cat space) instead of literal spaces so
        -- pgfkeys sees `bend~left=30` with the space preserved when
        -- the tokens are scanned inside \ExplSyntaxOn.  Without this,
        -- expl3-mode scanning drops the literal space → `bendleft=30`
        -- → "unknown key" pgfkeys error.
        local edge
        if c.bend == "left" then
            edge = string.format("(%s)~to[bend~left=30]~(%s)", c.src, c.tgt)
        elseif c.bend == "right" then
            edge = string.format("(%s)~to[bend~right=30]~(%s)", c.src, c.tgt)
        else
            edge = string.format("(%s)~--~(%s)", c.src, c.tgt)
        end
        local target_tl = c.tgt_is_valve
            and "\\l__numodel_late_causals_tl"
            or  "\\g__numodel_graphic_tl"
        local mode = c.tgt_is_valve and "put" or "gput"
        lines[#lines+1] = string.format(
            "\\tl_%s_right:Nn %s { \\draw~[causal]~%s~; }",
            mode, target_tl, edge)
    end
    table.insert(lines, 1, "\\ExplSyntaxOn")
    lines[#lines+1] = "\\ExplSyntaxOff"
    tex.print(lines)
end
