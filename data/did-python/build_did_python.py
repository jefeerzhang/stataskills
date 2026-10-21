#!/usr/bin/env python3
"""Build the project-generated panels for the Python fallback layer.

Deterministic: fixed seed, fixed generator, no external downloads. Re-running
reproduces both files byte-for-byte on the pinned pandas / numpy versions
recorded below.

    python data/did-python/build_did_python.py

Outputs
-------
data/did-python/panel_staggered.dta    staggered continuous-dose panel
                                       (180 units x 8 periods = 1440 obs)
data/did-python/spell_duration.dta     binary absorbing-spell panel
                                       (240 units x 10 periods = 2400 obs)

Pinned versions used to build the checked-in files: pandas 3.0.3,
numpy 2.4.6, Stata format version 118.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

SEED = 20261021
OUTDIR = Path(__file__).resolve().parent


def build_panel_staggered() -> pd.DataFrame:
    """Staggered adoption with a unit-invariant continuous dose.

    DGP: y_it = a_i + 0.3 t + 1.2 * dose_i * D_it + 0.5 x1_it + e_it
    Cohorts: never (0), 3, 5, 7. True ACRT = 1.2, so the estimator's
    overall_acrt should land near 1.2 given the power of this design.
    """
    rng = np.random.default_rng(SEED)
    rows = []
    for i in range(180):
        g = int(rng.choice([0, 0, 3, 5, 7]))
        a = rng.normal()
        x1 = rng.normal()
        x2 = rng.normal()
        dose = float(rng.uniform(0.5, 3.0)) if g > 0 else 0.0
        for t in range(1, 9):
            d = 0.0 if g == 0 else float(t >= g)
            y = a + 0.3 * t + 1.2 * dose * d + 0.5 * x1 + rng.normal(0, 0.3)
            rows.append((i, t, g, y, d, dose, x1, x2))
    return pd.DataFrame(
        rows, columns=["id", "t", "g", "y", "d", "dose", "x1", "x2"]
    )


def build_spell_duration() -> pd.DataFrame:
    """Binary absorbing outcome (spell ended), two groups, common timing.

    Every unit starts at risk and the panel is observed to period 10, with
    treatment starting at period 6. Base hazards stay low enough that a healthy
    share of each group is still at risk in the post window - DurationDiD
    imputes the treated counterfactual from the surviving controls, so a design
    that empties the control group produces a non-monotone imputed curve and no
    headline ATT. Treated units get a 60% higher hazard from period 6 on.
    """
    rng = np.random.default_rng(SEED + 1)
    rows = []
    for i in range(240):
        treat = int(i % 2 == 0)
        first = None
        for t in range(1, 11):
            h = 0.12 if (treat and t >= 6) else 0.05
            if first is None and rng.random() < h:
                first = t
            y = int(first is not None and t >= first)
            rows.append((i, t, treat, y))
    return pd.DataFrame(rows, columns=["id", "t", "treated", "y"])


def main() -> int:
    OUTDIR.mkdir(parents=True, exist_ok=True)
    targets = [
        ("panel_staggered.dta", build_panel_staggered()),
        ("spell_duration.dta", build_spell_duration()),
    ]
    for name, frame in targets:
        path = OUTDIR / name
        frame.to_stata(path, write_index=False, version=118)
        print(f"wrote {path} ({len(frame)} obs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
