-- test_causals.lua — causal-arrow list per fixture.
-- Specifically exercises the obstacle-detection bend logic.

local fixtures = {
    "free_fall",
    "oscillator",
    "projectile",
    "eel_q_doorstroom",
    "eel_q_factor_mismatch",
    "lift_between",
    "a_v_geen_doorstroom",
}

local function causal_summary(p)
    local m = numodel.models[p]
    local out = { "causals:" }
    for _, c in ipairs(m.causals) do
        out[#out+1] = string.format(
            "  %s -> %s bend=%s tgt_is_valve=%s",
            c.src, c.tgt, c.bend, tostring(c.tgt_is_valve))
    end
    out[#out+1] = ""
    return table.concat(out, "\n")
end

return {
    name = "causals",
    run = function(ctx)
        for _, fname in ipairs(fixtures) do
            local fx = ctx.load_fixture(fname)
            local p  = ctx.apply_fixture(fx)
            numodel.compute_layout(p, fx.diagram_style or "tight")
            ctx.assert_snapshot("causals_" .. fname, causal_summary(p))
        end
    end,
}
