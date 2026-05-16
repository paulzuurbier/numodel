-- lift_between — open2-positive between-flow from showcase.tex.
-- Two stocks (EZ, Esys) coupled by a single flow term `dMGV*Dt`:
--   EZ   = EZ   - dMGV * Dt        (outflow term)
--   Esys = Esys - Pout * Dt + dMGV * Dt   (outflow Pout, inflow dMGV)
-- Term-aware classifier matches the `dMGV*Dt` outflow on EZ against
-- the same `dMGV*Dt` inflow on Esys → between(EZ → Esys, fv=dMGV).

return {
    prefix = "lift",
    vars = {
        { name = "liftT",    type = "system", text = "t"    },
        { name = "liftDt",   type = "system", text = "dt"   },
        { name = "liftEZ",   type = "stock",  text = "E_Z"  },
        { name = "liftEsys", type = "stock",  text = "Esys" },
        { name = "liftPout", type = "aux",    text = "Pout" },
        { name = "liftdMGV", type = "aux",    text = "dMGV" },
    },
    rules = {
        { target = "liftEZ",
          expr = "\\liftEZ - \\liftdMGV * \\liftDt" },
        { target = "liftEsys",
          expr = "\\liftEsys - \\liftPout * \\liftDt + \\liftdMGV * \\liftDt" },
        { target = "liftT",
          expr = "\\liftT + \\liftDt" },
    },
}
