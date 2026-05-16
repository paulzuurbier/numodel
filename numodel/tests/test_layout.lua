-- test_layout.lua — full compute_layout snapshot per fixture.

local fixtures = {
    "free_fall",
    "oscillator",
    "projectile",
    "eel_q_doorstroom",
    "eel_q_factor_mismatch",
    "lift_between",
    "a_v_geen_doorstroom",
}

return {
    name = "layout",
    run = function(ctx)
        for _, fname in ipairs(fixtures) do
            local fx = ctx.load_fixture(fname)
            local p  = ctx.apply_fixture(fx)
            numodel.compute_layout(p, fx.diagram_style or "tight")
            ctx.assert_snapshot("layout_" .. fname, numodel.dump_layout(p))
        end
    end,
}
