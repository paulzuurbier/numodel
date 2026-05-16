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
        -- find_flow_var walks declaration order, skips target eg3V,
        -- skips system (eg3Dt) and dt-display, picks first match.
        -- Order: eg3X first (declared after eg3V).
        ctx.assert_eq("parenthesised outflow", "eg3X", F3.outflow.eg3V)

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
            -- Outflow on V; expression contains sign(V) and \eg4A.
            -- First var in declaration order after eg4V is eg4A → that's
            -- the picked flow var.
            { target = "eg4V",
              expr = "\\eg4V - sign(\\eg4V) * \\eg4K * \\eg4A * \\eg4Dt" },
        })
        ctx.assert_eq("function-call: first non-target var wins",
            "eg4A", F4.outflow.eg4V)
    end,
}
