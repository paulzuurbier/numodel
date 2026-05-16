-- test_wrap.lua — gridmaxx wrap behaviour for auto_layout.

local function setup(prefix, vars, rules)
    numodel.models[prefix] = nil
    numodel.init_prefix(prefix)
    for _, v in ipairs(vars) do
        numodel.register(prefix, v.name)
        numodel.set_meta(prefix, v.name, v)
    end
    for _, r in ipairs(rules or {}) do
        numodel.add_rule(prefix, r.target, r.expr, r.kind or "calc")
    end
    return prefix
end

local function pos(p, name)
    local L = numodel.models[p].layout[name] or {}
    return string.format("(%s,%s)",
        tostring(L.gridx), tostring(L.gridy))
end

return {
    name = "wrap",
    run = function(ctx)
        ----------------------------------------------------------------
        -- 1. Constants row wraps; only constants shift up.
        --    Four standalone constants with gridmaxx=3.  Place
        --    K1,K2,K3 at row 2; before K4 the row is full → constants
        --    on row 2 shift to row 3, then K4 lands at (0,2).
        ----------------------------------------------------------------
        local p = setup("w1", {
            { name = "K1", type = "constant", text = "k1" },
            { name = "K2", type = "constant", text = "k2" },
            { name = "K3", type = "constant", text = "k3" },
            { name = "K4", type = "constant", text = "k4" },
        })
        numodel.compute_layout(p, "tight", 3)
        ctx.assert_eq("const wrap K1", "(0,3)", pos(p, "K1"))
        ctx.assert_eq("const wrap K2", "(1,3)", pos(p, "K2"))
        ctx.assert_eq("const wrap K3", "(2,3)", pos(p, "K3"))
        ctx.assert_eq("const wrap K4", "(0,2)", pos(p, "K4"))

        ----------------------------------------------------------------
        -- 2. Aux row wraps; aux + constants shift up, stocks stay.
        --    Two constants on row 2, four standalone aux on row 1,
        --    one stock on row 0.  gridmaxx=3 forces the aux row to
        --    wrap once.
        ----------------------------------------------------------------
        p = setup("w2", {
            { name = "K1", type = "constant", text = "k1" },
            { name = "K2", type = "constant", text = "k2" },
            { name = "A1", type = "aux",      text = "a1" },
            { name = "A2", type = "aux",      text = "a2" },
            { name = "A3", type = "aux",      text = "a3" },
            { name = "A4", type = "aux",      text = "a4" },
            { name = "S",  type = "stock",    text = "s"  },
        })
        numodel.compute_layout(p, "tight", 3)
        ctx.assert_eq("aux wrap K1", "(0,3)", pos(p, "K1"))
        ctx.assert_eq("aux wrap K2", "(1,3)", pos(p, "K2"))
        ctx.assert_eq("aux wrap A1", "(0,2)", pos(p, "A1"))
        ctx.assert_eq("aux wrap A2", "(1,2)", pos(p, "A2"))
        ctx.assert_eq("aux wrap A3", "(2,2)", pos(p, "A3"))
        ctx.assert_eq("aux wrap A4", "(0,1)", pos(p, "A4"))
        ctx.assert_eq("aux wrap S",  "(0,0)", pos(p, "S"))

        ----------------------------------------------------------------
        -- 3. Stocks row wraps; everything shifts up by one.  Three
        --    standalone stocks (no flows) plus one constant; gridmaxx=2
        --    forces the stocks row to wrap after S1,S2.
        ----------------------------------------------------------------
        p = setup("w3", {
            { name = "K",  type = "constant", text = "k"  },
            { name = "S1", type = "stock",    text = "s1" },
            { name = "S2", type = "stock",    text = "s2" },
            { name = "S3", type = "stock",    text = "s3" },
        })
        numodel.compute_layout(p, "tight", 2)
        ctx.assert_eq("stock wrap K",  "(0,3)", pos(p, "K"))
        ctx.assert_eq("stock wrap S1", "(0,1)", pos(p, "S1"))
        ctx.assert_eq("stock wrap S2", "(1,1)", pos(p, "S2"))
        ctx.assert_eq("stock wrap S3", "(0,0)", pos(p, "S3"))

        ----------------------------------------------------------------
        -- 4. gridmaxx=0 (off): default centring + right-align preserved.
        --    A constant K, an aux A and a stock S — auto layout puts
        --    the constant left, the aux centred and the stock right.
        ----------------------------------------------------------------
        p = setup("w4", {
            { name = "K", type = "constant", text = "k" },
            { name = "A", type = "aux",      text = "a" },
            { name = "S", type = "stock",    text = "s" },
        })
        numodel.compute_layout(p, "tight", 0)
        ctx.assert_eq("no-wrap K", "(0,2)", pos(p, "K"))
        ctx.assert_eq("no-wrap A", "(0,1)", pos(p, "A"))
        ctx.assert_eq("no-wrap S", "(0,0)", pos(p, "S"))

        ----------------------------------------------------------------
        -- 5. Stock + flow valve fits as a group: a stock with an
        --    inflow constant valve takes 2 cells (valve + stock).
        --    gridmaxx=3 with one constant + one stock-with-valve must
        --    keep them together; gridmaxx=2 forces the row 0 wrap
        --    before the stock group is placed because it would not fit.
        ----------------------------------------------------------------
        p = setup("w5", {
            { name = "G",  type = "constant", text = "g"  },
            { name = "Dt", type = "system",   text = "dt" },
            { name = "V",  type = "stock",    text = "v"  },
        }, {
            { target = "V", expr = "\\V + \\G * \\Dt" },
        })
        numodel.compute_layout(p, "tight", 3)
        -- G is the inflow valve of V (constant promoted to valve), so
        -- G ends up on row 0 at column 0 and V at column 1; nothing
        -- on row 2 (no standalone constants).  No wrap triggered.
        ctx.assert_eq("flow group fits G", "(0,0)", pos(p, "G"))
        ctx.assert_eq("flow group fits V", "(1,0)", pos(p, "V"))

        ----------------------------------------------------------------
        -- 6. Phantom valves shift up with their stock.  Two stock-as-
        --    flow chains (S1 -> S2 -> S3) without standalone vars: row
        --    0 holds S1, S2__sv, S2, S3__sv, S3 (5 cells).  gridmaxx=4
        --    forces a shift before S3's group is placed; the shift
        --    must move the *phantom valve markers* (S2__sv, S3__sv)
        --    along with the stocks, otherwise the emit-side renders
        --    them on row 0 and double-occupies cells.
        ----------------------------------------------------------------
        p = setup("w6", {
            { name = "Dt", type = "system",   text = "dt" },
            { name = "S1", type = "stock",    text = "s1" },
            { name = "S2", type = "stock",    text = "s2" },
            { name = "S3", type = "stock",    text = "s3" },
        }, {
            { target = "S2", expr = "\\S2 + \\S1 * \\Dt" },
            { target = "S3", expr = "\\S3 + \\S2 * \\Dt" },
        })
        numodel.compute_layout(p, "tight", 4)
        -- Expected after wrap: S1, S2 on row 1; S3 on row 0.  Phantom
        -- valves track their stock's row.
        local m = numodel.models[p]
        local function svy(name) return (m.layout[name] or {}).sv_gridy end
        ctx.assert_eq("phantom shift S1", "(0,1)", pos(p, "S1"))
        ctx.assert_eq("phantom shift S2 sv_gridy", 1, svy("S2"))
        ctx.assert_eq("phantom shift S2", "(2,1)", pos(p, "S2"))
        ctx.assert_eq("phantom shift S3", "(1,0)", pos(p, "S3"))
        -- S3 placed *after* the wrap: still on row 0, so sv_gridy was
        -- never bumped (implicit 0 — nil in the table).
        ctx.assert_eq("phantom shift S3 sv_gridy", nil, svy("S3"))
        -- Occupied map must not have double-occupied cells.
        local seen = {}
        for k, _ in pairs(m.occupied) do
            ctx.assert_eq("no double occupy " .. k,
                seen[k] or false, false)
            seen[k] = true
        end

        ----------------------------------------------------------------
        -- 7. Stock-to-its-own-valve causal: forced bend only when both
        --    sit on the same row.  In tight mode the bend keeps the
        --    causal visible against the flow pipe; on different rows
        --    the causal is vertical and the bend is unnecessary.
        ----------------------------------------------------------------
        p = setup("w7", {
            { name = "Dt", type = "system",   text = "dt" },
            { name = "X",  type = "stock",    text = "x"  },
            { name = "K",  type = "constant", text = "k", gridx = 0, gridy = 2 },
            { name = "S",  type = "stock",    text = "s", gridx = 1, gridy = 0 },
        }, {
            -- S has K as inflow factor; K is also placed manually
            -- one row above the stock.  K becomes the valve_for S, but
            -- because K is already at gy=2 it stays there and S sits
            -- at gy=0 — different rows.
            { target = "S", expr = "\\S + \\X * \\K * \\Dt" },
            { target = "X", expr = "\\X + \\Dt" },
        })
        numodel.compute_layout(p, "tight", 0)
        local mw = numodel.models[p]
        local found_bend = false
        for _, c in ipairs(mw.causals) do
            if c.src == "X" and c.tgt == "S" then
                -- not the forced-bend case (X is not S's valve)
            elseif mw.flows.valve_for[c.tgt] == c.src
                or mw.flows.outvalve_for[c.tgt] == c.src
                or mw.flows.between_valve[c.tgt] == c.src
                or mw.flows.between_target[c.tgt] == c.src
            then
                if c.bend ~= "none" then found_bend = true end
            end
        end
        ctx.assert_eq("no forced bend on cross-row causal",
            false, found_bend)

        ----------------------------------------------------------------
        -- 8. Between-flow chain stays on a single row.  EZ -> dMGV ->
        --    Esys is one shared between flow; together with Esys's
        --    outflow valve Pout the chain needs 4 cells.  With
        --    gridmaxx=4 plus a pre-placed standalone stock, the
        --    auto-layout must wrap *before* the chain so EZ/dMGV/Esys/
        --    Pout end up on the same row.
        ----------------------------------------------------------------
        p = setup("w8", {
            { name = "Dt",   type = "system",   text = "dt"  },
            { name = "Lone", type = "stock",    text = "L"   },
            { name = "EZ",   type = "stock",    text = "E_Z" },
            { name = "Esys", type = "stock",    text = "E_s" },
            { name = "Pout", type = "aux",      text = "P"   },
            { name = "dMGV", type = "aux",      text = "d"   },
        }, {
            { target = "EZ",   expr = "\\EZ - \\dMGV * \\Dt" },
            { target = "Esys", expr = "\\Esys + \\dMGV * \\Dt - \\Pout * \\Dt" },
        })
        numodel.compute_layout(p, "tight", 4)
        ctx.assert_eq("chain Lone",  "(0,1)", pos(p, "Lone"))
        ctx.assert_eq("chain EZ",    "(0,0)", pos(p, "EZ"))
        ctx.assert_eq("chain dMGV",  "(1,0)", pos(p, "dMGV"))
        ctx.assert_eq("chain Esys",  "(2,0)", pos(p, "Esys"))
        ctx.assert_eq("chain Pout",  "(3,0)", pos(p, "Pout"))

        ----------------------------------------------------------------
        -- 9. Gap between an outflow valve and a following inflow valve
        --    so they don't read as a single between-flow.  S1 has an
        --    outflow valve (Pout), S2 has an inflow valve (J): without
        --    a gap S1 would be at col 0, Pout at 1, J at 2, S2 at 3 —
        --    visually [S1][Pout][J][S2] looks like a between flow.
        --    With the gap we expect an empty col 2 and the second
        --    group shifted right by one cell.
        ----------------------------------------------------------------
        p = setup("w9", {
            { name = "Dt",   type = "system",   text = "dt" },
            { name = "Pout", type = "constant", text = "p"  },
            { name = "J",    type = "constant", text = "j"  },
            { name = "S1",   type = "stock",    text = "s_1" },
            { name = "S2",   type = "stock",    text = "s_2" },
        }, {
            { target = "S1", expr = "\\S1 - \\Pout * \\Dt" },
            { target = "S2", expr = "\\S2 + \\J * \\Dt"    },
        })
        numodel.compute_layout(p, "tight", 0)  -- wrap off, gap stays
        ctx.assert_eq("gap S1",   "(0,0)", pos(p, "S1"))
        ctx.assert_eq("gap Pout", "(1,0)", pos(p, "Pout"))
        ctx.assert_eq("gap J",    "(3,0)", pos(p, "J"))
        ctx.assert_eq("gap S2",   "(4,0)", pos(p, "S2"))
        -- Col 2 must be empty (the gap cell).
        ctx.assert_eq("gap empty col", nil,
            numodel.models[p].occupied["2,0"])
    end,
}
