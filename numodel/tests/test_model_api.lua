-- test_model_api.lua — numodel.get_model / dump_model.
-- Builds the models directly through the TeX-facing registration
-- calls (register, set_meta, add_rule, add_ruletext, set_stop), in the
-- form \mvar, \mrule, \mruletext and \mstop pass them: detokenized
-- strings, so control words carry a trailing space.

local function free_fall()
    local p = "ball"
    numodel.models[p] = nil
    numodel.init_prefix(p)
    local vars = {
        { "ballT",  "system",   "t",  "0",     "\\s ",                  "2" },
        { "ballDt", "system",   "dt", "0.05",  "\\s ",                  "2" },
        { "ballV",  "stock",    "v",  "0",     "\\m \\per \\s ",        "3" },
        { "ballY",  "stock",    "y",  "100",   "\\m ",                  "3" },
        { "ballG",  "constant", "g",  "-9.81", "\\m \\per \\s \\squared ", "3" },
    }
    for _, v in ipairs(vars) do
        numodel.register(p, v[1])
        numodel.set_meta(p, v[1], { type = v[2], text = v[3], gridx = -1,
            gridy = -1, value = v[4], value_expr = v[4], unit = v[5],
            sigfigs = v[6] })
    end
    numodel.add_rule(p, "ballV", "\\ballV + \\ballG * \\ballDt ", "calc", false)
    numodel.add_rule(p, "ballY", "\\ballY + \\ballV * \\ballDt ", "calc", false)
    numodel.add_rule(p, "ballT", "\\ballT + \\ballDt ", "calc", false)
    numodel.set_stop(p, "\\ballY <= 2")
    return p
end

-- No start value, a computed start value, a starred ternary, a
-- free-text row, no stop condition, and a redeclared variable.
local function mixed()
    local p = "osc"
    numodel.models[p] = nil
    numodel.init_prefix(p)
    local function var(name, typ, text, value, expr, unit)
        numodel.register(p, name)
        numodel.set_meta(p, name, { type = typ, text = text, gridx = -1,
            gridy = -1, value = value, value_expr = expr, unit = unit,
            sigfigs = "3" })
    end
    var("oscT",    "system",   "t",                 "0", "0",   "\\s ")
    var("oscFres", "aux",      "F_{\\text {res}}",  "",  "",    "\\newton ")
    var("oscK",    "constant", "k",                 "6", "2*3", "\\newton \\per \\m ")
    var("oscK",    "constant", "k",                 "7", "7",   "\\newton \\per \\m ")
    numodel.add_rule(p, "oscFres", "-\\oscK * \\oscT ", "calc", false)
    numodel.add_rule(p, "oscT", "\\oscT < 1 ? \\oscT + 1 : \\oscT - 1",
        "ternary", true)
    numodel.add_ruletext(p, "\\text {(rest weggelaten)}")
    return p
end

return {
    name = "model_api",
    run = function(ctx)
        local p = free_fall()
        ctx.assert_snapshot("model_api_free_fall", numodel.dump_model(p))

        local g = numodel.get_model(p)
        ctx.assert_eq("free_fall vars", 5, #g.vars)
        ctx.assert_eq("free_fall G value", -9.81, g.vars[5].value)
        ctx.assert_eq("free_fall G short", "G", g.vars[5].short)
        ctx.assert_eq("free_fall has_start", true, g.vars[1].has_start)
        ctx.assert_eq("free_fall program rows", 4, #g.program)
        ctx.assert_eq("free_fall stop row last", "stop", g.program[4].kind)
        ctx.assert_eq("free_fall stop", "\\ballY <= 2", g.stop)

        -- get_model returns a copy: changing it leaves the store intact.
        g.vars[1].text = "changed"
        g.program[1].expr = "changed"
        local g2 = numodel.get_model(p)
        ctx.assert_eq("copy vars", "t", g2.vars[1].text)
        ctx.assert_eq("copy program", "\\ballV + \\ballG * \\ballDt ",
            g2.program[1].expr)

        p = mixed()
        ctx.assert_snapshot("model_api_mixed", numodel.dump_model(p))
        g = numodel.get_model(p)
        ctx.assert_eq("mixed vars (redeclared once)", 3, #g.vars)
        ctx.assert_eq("mixed no start", false, g.vars[2].has_start)
        ctx.assert_eq("mixed redeclared value", 7, g.vars[3].value)
        ctx.assert_eq("mixed starred", true, g.program[2].starred)
        ctx.assert_eq("mixed no stop", nil, g.stop)

        ctx.assert_eq("unknown prefix", nil, numodel.get_model("nope"))
        -- The layout pipeline still sees only executable rules.
        ctx.assert_eq("rules untouched", 2, #numodel.models[p].rules)
    end,
}
