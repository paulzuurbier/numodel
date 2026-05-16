-- test_flow.lua — flow classification per fixture.
-- Asserts inflow/outflow/between/stock_valve maps on each fixture by
-- inspecting numodel.models[p].flows directly (no layout, no causals).

local fixtures = {
    "free_fall",
    "oscillator",
    "projectile",
    "eel_q_doorstroom",
    "eel_q_factor_mismatch",
    "lift_between",
    "a_v_geen_doorstroom",
}

local function flow_summary(p)
    local m = numodel.models[p]
    local out = {}
    local function dump(label, t)
        out[#out+1] = label .. ":"
        local keys = {}
        for k in pairs(t or {}) do keys[#keys+1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            out[#out+1] = "  " .. k .. " -> " .. tostring(t[k])
        end
    end
    dump("inflow",         m.flows.inflow)
    dump("outflow",        m.flows.outflow)
    dump("valve_for",      m.flows.valve_for)
    dump("outvalve_for",   m.flows.outvalve_for)
    dump("between_valve",  m.flows.between_valve)
    dump("between_target", m.flows.between_target)
    dump("stock_valve",         m.flows.stock_valve)
    dump("stock_phantom_valve", m.flows.stock_phantom_valve)
    out[#out+1] = ""
    return table.concat(out, "\n")
end

return {
    name = "flow",
    run = function(ctx)
        for _, fname in ipairs(fixtures) do
            local fx = ctx.load_fixture(fname)
            local p  = ctx.apply_fixture(fx)
            numodel.build_deps(p)
            numodel.classify_flows(p)
            ctx.assert_snapshot("flow_" .. fname, flow_summary(p))
        end
    end,
}
