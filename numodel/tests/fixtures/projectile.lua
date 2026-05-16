-- projectile — two parallel state evolutions (projectile.tex).
-- Three stocks (X, Y, Vy) plus Vx as a "constant" velocity component
-- (declared as voorraad in the .tex but in any case acts as inflow
-- valve of X here).  G is inflow valve of Vy.

return {
    prefix = "proj",
    vars = {
        { name = "projT",  type = "system",   text = "t"   },
        { name = "projDt", type = "system",   text = "dt"  },
        { name = "projX",  type = "stock",    text = "x"   },
        { name = "projY",  type = "stock",    text = "y"   },
        { name = "projVx", type = "stock",    text = "v_x" },
        { name = "projVy", type = "stock",    text = "v_y" },
        { name = "projG",  type = "constant", text = "g"   },
    },
    rules = {
        { target = "projVy", expr = "\\projVy + \\projG * \\projDt"  },
        { target = "projX",  expr = "\\projX + \\projVx * \\projDt"  },
        { target = "projY",  expr = "\\projY + \\projVy * \\projDt"  },
        { target = "projT",  expr = "\\projT + \\projDt"             },
    },
}
