-- eel_q_factor_mismatch — open2-NEGATIVE: factor differs on each side.
--   Eel = Eel - P*dt        (outflow term: P*dt)
--   Q   = Q   + 3 * P*dt    (inflow term: 3*P*dt — different factor)
-- Variable-based detect_flow would still flag P as both inflow and
-- outflow valve and call this a between-flow; the term-aware detector
-- compares full term-strings, sees `\eeP*\eeDt` ≠ `3*\eeP*\eeDt`, and
-- keeps the two as separate flows.

return {
    prefix = "ee",
    vars = {
        { name = "eeT",   type = "system",   text = "t"   },
        { name = "eeDt",  type = "system",   text = "dt"  },
        { name = "eeEel", type = "stock",    text = "Eel" },
        { name = "eeQ",   type = "stock",    text = "Q"   },
        { name = "eeP",   type = "aux",      text = "P"   },
        { name = "eeR",   type = "constant", text = "R"   },
        { name = "eeI",   type = "constant", text = "I"   },
    },
    rules = {
        { target = "eeP",   expr = "\\eeI * \\eeI * \\eeR"          },
        { target = "eeEel", expr = "\\eeEel - \\eeP * \\eeDt"       },
        { target = "eeQ",   expr = "\\eeQ + 3 * \\eeP * \\eeDt"     },
        { target = "eeT",   expr = "\\eeT + \\eeDt"                 },
    },
}
