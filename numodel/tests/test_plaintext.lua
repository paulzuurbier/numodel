-- test_plaintext.lua — plain-text rendering (Coachtaal / EN).
-- Expressions, names and units in isolation, then whole models.  The
-- expected Coachtaal follows the Coach 7 handleiding (chapter 12):
-- unary minus and ^ share a priority and run left to right,
-- relational operands of En/Of need parentheses, ; separates
-- function arguments, names outside [A-Za-z0-9_] go in brackets.

local names = { x = "x", y = "y", a = "a", b = "b", c = "c" }

local expr_cases = {
    -- precedence differences between l3fp and Coach
    { "-\\x ^2",                  "-(x^2)" },
    { "(-\\x )^2",                "(-x)^2" },
    { "\\a ^\\b ^\\c ",           "a^(b^c)" },
    { "\\a ^-\\b ",               "a^-b" },
    { "\\x ^(1/3)",               "x^(1/3)" },
    { "1/2pi",                    "1/(2*Pi)" },
    { "2pi/3",                    "2*Pi/3" },
    { "3\\x ",                    "3*x" },
    { "\\x (\\a + \\b )",         "x*(a + b)" },
    { "\\a /(\\b *\\c )",         "a/(b*c)" },
    { "\\a - (\\b + \\c )",       "a - (b + c)" },
    { "-\\a * \\b ",              "-a*b" },
    { "\\a * -\\b ",              "a*-b" },
    -- logic and comparison
    { "\\x > 1 && \\x < 2",       "(x > 1) EN (x < 2)" },
    { "\\x < 1 || \\x > 3 && \\y = 0", "(x < 1) OF (x > 3) EN (y = 0)" },
    { "!(\\x > 1)",               "NIET(x > 1)" },
    { "!\\x ",                    "NIET x" },
    { "\\x != 0",                 "x <> 0" },
    { "\\x == 0",                 "x = 0" },
    -- numbers
    { "0.05",                     "0,05" },
    { ".5",                       "0,5" },
    { "1.5e-3",                   "1,5E-3" },
    -- functions
    { "sign(\\x ) * 0.5 * \\x ^2", "Teken(x)*0,5*x^2" },
    { "max(\\a , \\b , 1)",       "Max(a;b;1)" },
    { "abs(\\x )^0.5",            "Abs(x)^0,5" },
    { "sind(\\x + 1)",            "Sin(Pi/180*(x + 1))" },
    { "asind(\\x )",              "(180/Pi*Arcsin(x))" },
    { "\\a / cot(\\x )",          "a/(1/Tan(x))" },
    { "ceil(\\x - 0.5)",          "(-Entier(-(x - 0,5)))" },
    { "round(\\x )",              "Round(x)" },
    { "round(\\x , 2)",           "(Round(x*10^2)/10^2)" },
    { "floor(\\x )",              "Entier(x)" },
}

local function free_fall()
    local p = "ball"
    numodel.models[p] = nil
    numodel.init_prefix(p)
    for _, v in ipairs({
        { "ballT",  "system",   "t",  "0",     "\\s " },
        { "ballDt", "system",   "dt", "0.05",  "\\s " },
        { "ballV",  "stock",    "v",  "0",     "\\m \\per \\s " },
        { "ballY",  "stock",    "y",  "100",   "\\m " },
        { "ballG",  "constant", "g",  "-9.81", "\\m \\per \\s \\squared " },
    }) do
        numodel.register(p, v[1])
        numodel.set_meta(p, v[1], { type = v[2], text = v[3], value = v[4],
            value_expr = v[4], unit = v[5], sigfigs = "3" })
    end
    numodel.add_rule(p, "ballV", "\\ballV + \\ballG * \\ballDt ", "calc", false)
    numodel.add_rule(p, "ballY", "\\ballY + \\ballV * \\ballDt ", "calc", false)
    numodel.add_rule(p, "ballT", "\\ballT + \\ballDt ", "calc", false)
    numodel.set_stop(p, "\\ballY <= 2")
    return p
end

-- Greek names, a computed start value referring to other variables,
-- starred and unstarred conditionals, a free-text row, a name clash.
local function oscillator()
    local p = "osc"
    numodel.models[p] = nil
    numodel.init_prefix(p)
    for _, v in ipairs({
        { "oscT",  "system",   "t",          "0",    "0",    "\\s " },
        { "oscDt", "system",   "\\Delta t ", "0.01", "0.01", "\\s " },
        { "oscM",  "constant", "m",          "0.5",  "0.5",  "\\kilo \\gram " },
        { "oscK",  "constant", "k",          "6",    "2*3",  "\\newton \\per \\m " },
        { "oscF",  "aux",      "F_{\\text {res}}", "", "",   "\\newton " },
        { "oscV",  "stock",    "v",          "0",    "0",    "\\m \\per \\s " },
        { "oscX",  "stock",    "x",          "0.1",  "0.1",  "\\m " },
        { "oscW",  "aux",      "\\omega ",   "3.46", "sqrt(\\oscK /\\oscM )", "\\per \\s " },
        { "oscX2", "aux",      "x",          "",     "",     "\\m " },
    }) do
        numodel.register(p, v[1])
        numodel.set_meta(p, v[1], { type = v[2], text = v[3], value = v[4],
            value_expr = v[5], unit = v[6], sigfigs = "3" })
    end
    numodel.add_rule(p, "oscF", "-\\oscK * \\oscX ", "calc", false)
    numodel.add_rule(p, "oscV",
        "\\oscT < 1 && \\oscX > 0 ? \\oscV + \\oscF / \\oscM * \\oscDt : \\oscV ",
        "ternary", true)
    numodel.add_rule(p, "oscX2", "\\oscX >= 0 ? \\oscX : -\\oscX ",
        "ternary", false)
    numodel.add_ruletext(p, "\\text {(demping weggelaten)}")
    numodel.add_rule(p, "oscX", "\\oscX + \\oscV * \\oscDt ", "calc", false)
    numodel.add_rule(p, "oscT", "\\oscT + \\oscDt ", "calc", false)
    numodel.set_stop(p, "\\oscT >= 10")
    return p
end

local function full(p, dialect)
    local r = numodel.plaintext(p, { dialect = dialect })
    return "body:\n" .. r.body .. "init:\n" .. r.init .. "warnings:\n"
        .. table.concat(r.warnings, "\n") .. "\n"
end

return {
    name = "plaintext",
    run = function(ctx)
        for _, c in ipairs(expr_cases) do
            local s = numodel.plain_expr(c[1], names, "NL")
            ctx.assert_eq("expr " .. c[1], c[2], s)
        end
        ctx.assert_eq("expr EN", "(x > 1) AND (x < 2.5)",
            (numodel.plain_expr("\\x > 1 && \\x < 2.5", names, "EN")))
        ctx.assert_eq("expr EN argsep", "MAX(a,b)",
            (numodel.plain_expr("max(\\a ,\\b )", names, "EN")))
        local _, w = numodel.plain_expr("atan(\\y , \\x )", names, "NL")
        ctx.assert_eq("atan2 warns", 1, #w)
        _, w = numodel.plain_expr("\\q + 1", names, "NL")
        ctx.assert_eq("unknown variable warns", 1, #w)

        for _, c in ipairs({
            { "F_{\\text {res}}",      "F_res" },
            { "T_{\\mathrm {koffie}}", "T_koffie" },
            { "\\Delta t",             "Δt" },
            { "\\Delta x",             "[Δx]" },
            { "\\omega ",              "[ω]" },
            { "v_{k}",                 "v_k" },
            { "Max",                   "[Max]" },
            { "stop",                  "[stop]" },
            { "2r",                    "[2r]" },
        }) do
            ctx.assert_eq("name " .. c[1], c[2], (numodel.plain_name(c[1])))
        end

        for _, c in ipairs({
            { "\\m \\per \\s \\squared ",                  "m/s^2" },
            { "\\kilo \\gram \\metre \\per \\second \\squared ", "kg*m/s^2" },
            { "\\mole \\per \\litre \\per \\second ",      "mol/(L*s)" },
            { "\\per \\second ",                           "1/s" },
            { "\\micro \\gram ",                           "ug" },
            { "\\ohm ",                                    "Ohm" },
            { "\\square \\metre ",                         "m^2" },
            { "\\metre \\tothe{-1}",                       "1/m" },
            { "\\kWh ",                                    "kWh" },
            { "m/s",                                       "m/s" },
            { "",                                          "" },
        }) do
            ctx.assert_eq("unit " .. c[1], c[2], (numodel.plain_unit(c[1])))
        end

        ctx.assert_snapshot("plaintext_free_fall_NL", full(free_fall(), "NL"))
        ctx.assert_snapshot("plaintext_free_fall_EN", full(free_fall(), "EN"))
        ctx.assert_snapshot("plaintext_oscillator_NL", full(oscillator(), "NL"))
    end,
}
