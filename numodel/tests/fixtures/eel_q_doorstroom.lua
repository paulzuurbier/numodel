-- eel_q_doorstroom — open2-positive between-flow.
-- Eel = Eel - P*dt   (outflow from electrical-energy stock)
-- Q   = Q   + P*dt   (inflow to heat stock)
-- Same flow variable P appears with - on Eel and + on Q, so the
-- current detect_flow correctly classifies P as a between-flow from
-- Eel to Q.  After the open2 fix we additionally require the factor
-- to match (here both terms are P*dt — factor 1 on each side, so the
-- between classification is preserved).

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
        { target = "eeQ",   expr = "\\eeQ + \\eeP * \\eeDt"         },
        { target = "eeT",   expr = "\\eeT + \\eeDt"                 },
    },
}
