-- free_fall — single-stock free fall (free-fall.tex).
-- Variables prefixed with "ball" (the modelprefix in the .tex).
-- Expected layout: T,Dt,G are constants on gridy=2; V,Y stocks on
-- gridy=0; G is the inflow valve of V (so it gets relocated next to V).

return {
    prefix = "ball",
    vars = {
        { name = "ballT",  type = "system",   text = "t"  },
        { name = "ballDt", type = "system",   text = "dt" },
        { name = "ballV",  type = "stock",    text = "v"  },
        { name = "ballY",  type = "stock",    text = "y"  },
        { name = "ballG",  type = "constant", text = "g"  },
    },
    rules = {
        { target = "ballV", expr = "\\ballV + \\ballG * \\ballDt" },
        { target = "ballY", expr = "\\ballY + \\ballV * \\ballDt" },
        { target = "ballT", expr = "\\ballT + \\ballDt" },
    },
}
