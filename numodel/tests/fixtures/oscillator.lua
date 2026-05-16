-- oscillator — undamped mass-spring (oscillator.tex).
-- Two stocks (X, V) coupled through F = -k X.  Notable: the rule for
-- V is `\oscV - (\oscK / \oscM) * \oscX * \oscDt` — a `-` after the
-- stock, so the current detect_flow regex matches it as an outflow
-- and find_flow_var picks `K` (first non-target/non-system/non-dt
-- variable in declaration order whose CS appears in the expression).
-- Stock-V's outflow var (K) is type=constant, so it ends up in
-- outvalve_for[K] = V.

return {
    prefix = "osc",
    vars = {
        { name = "oscT",  type = "system",   text = "t"  },
        { name = "oscDt", type = "system",   text = "dt" },
        { name = "oscX",  type = "stock",    text = "x"  },
        { name = "oscV",  type = "stock",    text = "v"  },
        { name = "oscM",  type = "constant", text = "m"  },
        { name = "oscK",  type = "constant", text = "k"  },
    },
    rules = {
        { target = "oscV", expr = "\\oscV - (\\oscK / \\oscM) * \\oscX * \\oscDt" },
        { target = "oscX", expr = "\\oscX + \\oscV * \\oscDt" },
        { target = "oscT", expr = "\\oscT + \\oscDt" },
    },
}
