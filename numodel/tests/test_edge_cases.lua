-- test_edge_cases.lua — detokenize / normalisation edge cases.
-- Per REFACTORNUMODEL.MD §1.3.1 and §A0 step 5.

local function classify(prefix, vars, rules)
    numodel.models[prefix] = nil
    numodel.init_prefix(prefix)
    for _, v in ipairs(vars) do
        numodel.register(prefix, v.name)
        numodel.set_meta(prefix, v.name, v)
    end
    for _, r in ipairs(rules) do
        numodel.add_rule(prefix, r.target, r.expr, r.kind or "calc")
    end
    numodel.build_deps(prefix)
    numodel.classify_flows(prefix)
    return numodel.models[prefix].flows
end

return {
    name = "edge_cases",
    run = function(ctx)
        ----------------------------------------------------------------
        -- 1. Word-boundary CS match: \modV must NOT match in \modVar.
        --    modVar is an aux flow var; the inflow term `\modVar *
        --    \modDt` is found via cs_in_expr without cross-matching
        --    `\modV`.  Using an aux (not a second stock) keeps the
        --    test focused on word boundary; the strict factor-aware
        --    stock-as-flow rule is exercised in fixtures.
        ----------------------------------------------------------------
        local F = classify("eg1", {
            { name = "modV",   type = "stock",  text = "v"   },
            { name = "modVar", type = "aux",    text = "Var" },
            { name = "modDt",  type = "system", text = "dt"  },
        }, {
            { target = "modV",
              expr = "\\modV + \\modVar * \\modDt" },
        })
        ctx.assert_eq("word boundary inflow",
            "modVar", F.inflow.modV)
        ctx.assert_eq("word boundary valve_for",
            "modV", F.valve_for.modVar)

        ----------------------------------------------------------------
        -- 2. Whitespace tolerance: extra spaces around operators must
        --    not change classification.
        ----------------------------------------------------------------
        local F2 = classify("eg2", {
            { name = "eg2A", type = "stock",    text = "a" },
            { name = "eg2B", type = "constant", text = "b" },
            { name = "eg2Dt", type = "system",  text = "dt" },
        }, {
            { target = "eg2A",
              expr = "\\eg2A   +   \\eg2B   *   \\eg2Dt" },
        })
        ctx.assert_eq("whitespace inflow", "eg2B", F2.inflow.eg2A)

        ----------------------------------------------------------------
        -- 3. Parentheses on the RHS: `\stock - (\K / \M) * \X * \Dt`
        --    (oscillator pattern).  detect_flow regex still matches
        --    `\stock\s*-`, find_flow_var picks the first var present.
        ----------------------------------------------------------------
        local F3 = classify("eg3", {
            { name = "eg3V",  type = "stock",    text = "v"  },
            { name = "eg3X",  type = "stock",    text = "x"  },
            { name = "eg3K",  type = "constant", text = "k"  },
            { name = "eg3M",  type = "constant", text = "m"  },
            { name = "eg3Dt", type = "system",   text = "dt" },
        }, {
            { target = "eg3V",
              expr = "\\eg3V - (\\eg3K / \\eg3M) * \\eg3X * \\eg3Dt" },
        })
        -- The rate uses x, k and m (the target v and dt do not count):
        -- no single flow variable, so an unnamed out-valve with all
        -- three as sources, in declaration order.
        ctx.assert_eq("parenthesised outflow", "eg3X,eg3K,eg3M",
            F3.stock_phantom_outvalve.eg3V)

        ----------------------------------------------------------------
        -- 4. Function-call protection: `sign(\modV) * \modA * \modDt`.
        --    `\modV` appears, but as a function argument — under the
        --    CURRENT (regex-based) detect_flow this still matches the
        --    target stock if the rule starts with `\modV`.  The rule
        --    below tests an outflow that contains sign() of a OTHER
        --    var: detect_flow should NOT pick the var inside sign() as
        --    *the* flow var if a non-function var is also present.
        --    With find_flow_var (declaration order, first match) the
        --    behaviour is "first var in expr wins" — including those
        --    inside sign().  Document that behaviour here.
        ----------------------------------------------------------------
        local F4 = classify("eg4", {
            { name = "eg4V",  type = "stock",    text = "v"  },
            { name = "eg4A",  type = "stock",    text = "a"  },
            { name = "eg4K",  type = "constant", text = "k"  },
            { name = "eg4Dt", type = "system",   text = "dt" },
        }, {
            -- Outflow on V; expression contains sign(V), \eg4K and
            -- \eg4A.  Several variables (V itself counts): no single
            -- flow variable, but an unnamed valve with all as sources.
            { target = "eg4V",
              expr = "\\eg4V - sign(\\eg4V) * \\eg4K * \\eg4A * \\eg4Dt" },
        })
        ctx.assert_eq("function-call: several vars give an unnamed valve",
            "eg4V,eg4A,eg4K", F4.stock_phantom_outvalve.eg4V)
        ctx.assert_eq("function-call: no named outflow",
            nil, F4.outflow.eg4V)

        ----------------------------------------------------------------
        -- 5. Flows the Coach export also makes (wish list K2, K3):
        --    an outflow whose rate is a stock (h := h - v*dt), a flow
        --    without a variable (n := n + 0.5*dt) and a sum
        --    ((r + i)*dt, one flow, not split).  Each an unnamed valve.
        ----------------------------------------------------------------
        local F5 = classify("eg5", {
            { name = "eg5H",  type = "stock",    text = "h"  },
            { name = "eg5V",  type = "stock",    text = "v"  },
            { name = "eg5N",  type = "stock",    text = "n"  },
            { name = "eg5S",  type = "stock",    text = "S"  },
            { name = "eg5R",  type = "constant", text = "r"  },
            { name = "eg5I",  type = "constant", text = "i"  },
            { name = "eg5B",  type = "stock",    text = "N"  },
            { name = "eg5G",  type = "constant", text = "g"  },
            { name = "eg5W",  type = "stock",    text = "W"  },
            { name = "eg5Dt", type = "system",   text = "dt" },
        }, {
            -- K5: the stock itself in the rate (growth, decay)
            { target = "eg5B", expr = "\\eg5B + \\eg5G * \\eg5B * \\eg5Dt" },
            { target = "eg5W", expr = "\\eg5W + 0.15 * \\eg5W * \\eg5Dt" },
            { target = "eg5H", expr = "\\eg5H - \\eg5V * \\eg5Dt" },
            { target = "eg5N", expr = "\\eg5N + 0.5 * \\eg5Dt" },
            { target = "eg5S", expr = "\\eg5S + (\\eg5R + \\eg5I) * \\eg5Dt" },
        })
        ctx.assert_eq("stock as outflow rate", "eg5V",
            F5.stock_phantom_outvalve.eg5H)
        ctx.assert_eq("stock as outflow rate: no named outflow", nil,
            F5.outflow.eg5H)
        ctx.assert_eq("number as inflow", "", F5.stock_phantom_valve.eg5N)
        ctx.assert_eq("sum as one inflow", "eg5R,eg5I",
            F5.stock_phantom_valve.eg5S)
        ctx.assert_eq("stock in its own rate: unnamed valve", "eg5B,eg5G",
            F5.stock_phantom_valve.eg5B)
        ctx.assert_eq("stock in its own rate: g is no valve", nil,
            F5.valve_for.eg5G)
        ctx.assert_eq("stock alone in its own rate", "eg5W",
            F5.stock_phantom_valve.eg5W)
    end,
}
