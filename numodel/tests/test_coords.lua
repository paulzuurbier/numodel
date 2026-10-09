-- test_coords.lua — numodel.get_coords and its thinning for plots.
-- get_coords writes "(x,y) (x,y) ..." with tex.sprint; the runner's
-- stub collects that in tex._sprint_sink.

local function coords(p, x, y, maxpoints)
    local sink = tex._sprint_sink
    for k in pairs(sink) do sink[k] = nil end
    numodel.get_coords(p, x, y, maxpoints)
    local pts = {}
    for a, b in (sink[1] or ""):gmatch("%(([^,]+),([^)]+)%)") do
        pts[#pts + 1] = { tonumber(a), tonumber(b) }
    end
    return pts
end

-- A series of n samples: flat at 1 with a jump to 0 at sample jump.
local function model(n, jump)
    local p = "cs"
    numodel.models[p] = nil
    numodel.init_prefix(p)
    numodel.register(p, "csT")
    numodel.register(p, "csY")
    for i = 1, n do
        numodel.record(p, "csT", (i - 1) * 0.01)
        numodel.record(p, "csY", (i < jump) and 1 or (i < jump + 5 and (jump + 5 - i) / 5 or 0))
        numodel.end_step(p)
    end
    return p
end

return {
    name = "coords",
    run = function(ctx)
        local p = model(50, 25)
        ctx.assert_eq("short series kept whole", 50, #coords(p, "csT", "csY", 1000))
        ctx.assert_eq("maxpoints 0 keeps all", 50, #coords(p, "csT", "csY", 0))

        p = model(8000, 4000)
        local all = coords(p, "csT", "csY", 0)
        local thin = coords(p, "csT", "csY", 1000)
        ctx.assert_eq("all points without limit", 8000, #all)
        ctx.assert_eq("thinned to at most about the limit", true,
            #thin <= 1100 and #thin >= 500)
        ctx.assert_eq("first point kept", 0, thin[1][1])
        ctx.assert_eq("last point kept", all[#all][1], thin[#thin][1])
        -- The five samples of the drop (y = 1, 0.8 ... 0.2, 0) all stay.
        local drop = 0
        for _, pt in ipairs(thin) do
            if pt[2] > 0.01 and pt[2] < 0.99 then drop = drop + 1 end
        end
        ctx.assert_eq("every step of a fast change kept", 4, drop)
    end,
}
