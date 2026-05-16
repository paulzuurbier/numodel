-- a_v_geen_doorstroom — open2-NEGATIVE: no flow from a to v.
--
--   a = a + j*dt    -- jerk j drives acceleration a
--   v = v + a*dt    -- a drives v
--
-- A between-flow only exists when the increase of one stock is
-- caused by the decrease of another.  Here the rule for `a` has no
-- `-a*dt` term, so the term-aware detector rejects both the
-- between-flow classification and the stock-as-flow classification:
-- `\avA` appears in v's RHS but no matching outflow term in a's own
-- rule, so a is not a real flow source for v.  The result is a
-- regular causal arrow a → v emitted by build_deps.

return {
    prefix = "av",
    vars = {
        { name = "avT",   type = "system",   text = "t"   },
        { name = "avDt",  type = "system",   text = "dt"  },
        { name = "avA",   type = "stock",    text = "a"   },
        { name = "avV",   type = "stock",    text = "v"   },
        { name = "avJ",   type = "constant", text = "j"   },
    },
    rules = {
        { target = "avA", expr = "\\avA + \\avJ * \\avDt" },
        { target = "avV", expr = "\\avV + \\avA * \\avDt" },
        { target = "avT", expr = "\\avT + \\avDt"         },
    },
}
