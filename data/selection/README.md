# `data/selection/` — project-generated teaching data

`teaching-treatment.dta` is a deterministic, project-internal teaching dataset for a selection-on-observables example. It is not an AGIS6 textbook dataset and is not downloaded from an external source.

## Provenance and reproducibility

- **Source:** generated in this repository by `data/selection/build-teaching.do`.
- **Rebuild command (from the repository root):**
  ```bat
  "C:\Program Files\StataNow19\StataMP-64.exe" /e do "data/selection/build-teaching.do"
  ```
  On another Windows installation, use the `STATA_WIN` path in `verify/stata.conf`; the platform-independent batch form is documented in `docs/run-stata.md`.
- **Determinism:** Stata 19.5, seed `20260825`, `N=2000`.
- **External download:** none.
- **License/provenance:** original project-generated synthetic data; repository license applies.

## Published schema

The release contains exactly these variables, in this order:

```text
id treat y x1 x2 x3 x4 x5 x6
```

`oracle` and all build-time variables (including `y0`, `y1`, `tau`, `eta`, `ps_true`, and `noise`) are intentionally excluded.

All variable labels are English:

- `id`: Observation identifier
- `treat`: Treatment indicator (true ATET = 0.5)
- `y`: Observed outcome
- `x1`–`x6`: Pretreatment covariates 1–6

## Design and invariants

The complete data-generating process is:

- `x1`, `x2`, `x4`, and `x6` are independently drawn from `N(0,1)`;
- `x3` and `x5` are independently drawn from `Uniform(0,1)`;
- `eta = -1.25 + 0.45*x1 + 0.55*x2 + 0.35*(x3 - 0.5) - 0.40*x4`;
- `ps_true = invlogit(eta)`;
- `treat` is Bernoulli with success probability `ps_true`;
- `noise ~ N(0,1)` and is independent of treatment assignment;
- `y0 = 1 + 0.70*x1 + 0.80*x2 + 0.50*x3 - 0.60*x4 + noise`;
- `tau = 0.5` for every observation, so the true ATET is fixed at `0.5`;
- `y = y0 + treat*0.5`.

Thus treatment and `y0` share the pretreatment observables `x1`–`x4`, while no unobserved variable jointly determines treatment and the potential outcomes.

The build script asserts:

- `N=2000` and no missing values in the generated or published variables;
- treatment rate in `[0.20, 0.30]`;
- binary treatment and constant `tau=0.5` before publication;
- IPWRA ATET within `abs(hat - 0.5) <= 0.15`;
- exact published varlist and absence of `oracle`.

The file is registered by basename `teaching-treatment` in `data/manifest-extra.txt`.

## Formal build evidence

On 2026-08-26, the formal `data/selection/build-teaching.do` was executed with Stata 19.5 from the repository root and exited without a Stata return-code error. The run reached `end of do-file` after all pre-save checks passed.

Observed outputs:

- Treatment rate: `0.254` (required range `[0.20, 0.30]`)
- Unadjusted treated-minus-control outcome difference: `1.461`
- IPWRA ATET: `0.5016781` (robust SE `0.06099`)
- ATET assertion: `abs(0.5016781 - 0.5) <= 0.15`
- Published schema and oracle-exclusion assertions: passed before `save`
