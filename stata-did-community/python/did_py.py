#!/usr/bin/env python3
"""Python fallback estimators for DiD designs that Stata cannot fit.

Stata covers 22 of the 26 estimators that diff-diff ships (see
``references/python-fallback.md`` for the full mapping). The four below have no
Stata implementation, so this module runs them through ``diff-diff`` and writes
a Stata-loadable artifact.

Every subcommand takes the same panel contract:

    --data FILE      .dta or .csv
    --outcome NAME   numeric outcome
    --unit NAME      unit identifier
    --time NAME      integer time index
    --first-treat NAME  first treated period; never-treated units use 0
                        (DurationDiD instead takes --treatment, a 0/1 group flag)

Usage
-----
    python did_py.py continuous --data panel.dta --outcome y --unit id \
        --time t --first-treat g --dose dose
    python did_py.py dml --data panel.dta --outcome y --unit id --time t \
        --first-treat g --covariates x1 x2
    python did_py.py efficient --data panel.dta --outcome y --unit id --time t \
        --first-treat g
    python did_py.py duration --data spell.dta --outcome y --unit id --time t \
        --treatment treated --last-pre-period 4

``--format`` selects the result artifact: ``json`` (default), ``csv`` or
``dta``. With ``dta`` the headline row is written as a one-row dataset that
``use`` loads directly in Stata.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ERREXIT = 2


def _fail(message: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"did_py: {message}", file=sys.stderr)
    raise SystemExit(ERREXIT)


def load_frame(path: str) -> pd.DataFrame:
    p = Path(path)
    if not p.exists():
        _fail(f"data file not found: {path}")
    if p.suffix.lower() == ".dta":
        df = pd.read_stata(p)
    elif p.suffix.lower() == ".csv":
        df = pd.read_csv(p)
    else:
        _fail(f"unsupported data format: {p.suffix} (use .dta or .csv)")
    if df.empty:
        _fail(f"data file has no rows: {path}")
    return df


def require_columns(df: pd.DataFrame, names: list[str]) -> None:
    missing = [n for n in names if n not in df.columns]
    if missing:
        _fail(f"missing column(s): {', '.join(missing)}; available: {', '.join(map(str, df.columns))}")


def require_staggered_panel(df: pd.DataFrame, outcome: str, unit: str, time: str, first_treat: str) -> None:
    require_columns(df, [outcome, unit, time, first_treat])
    if df[[unit, time]].duplicated().any():
        _fail(f"panel not unique at ({unit}, {time})")
    never = df[first_treat].isin([0]) | df[first_treat].isna()
    if never.all():
        _fail(f"{first_treat} marks every unit never-treated; nothing to estimate")
    if not df[outcome].notna().all():
        _fail(f"outcome {outcome} has missing values; drop or impute them first")


def headline(result, estimator: str) -> dict:
    """Pull the headline ATT/SE block plus a coarse fit record into one dict.

    Fails closed when the estimator returns a non-finite ATT: a NaN headline is
    not a result, and writing one out would let a downstream report quote it.
    DurationDiD does this when its imputed counterfactual curve is non-monotone,
    which signals too few units still at risk rather than an arithmetic slip.
    """
    att = float(result.att)
    se = float(result.se)
    if not (np.isfinite(att) and np.isfinite(se)):
        _fail(
            f"{estimator} returned a non-finite headline (att={att}, se={se}); "
            "the design does not support this fit. DurationDiD reports this when the "
            "imputed counterfactual curve is non-monotone - shorten the horizon "
            "(lower --last-pre-period / fewer post periods) or use more units."
        )
    row = {
        "estimator": estimator,
        "att": att,
        "se": se,
        "t_stat": float(result.t_stat),
        "p_value": float(result.p_value),
        "ci_lower": float(result.conf_int[0]),
        "ci_upper": float(result.conf_int[1]),
        "n_obs": int(result.n_obs),
    }
    for key in ("n_treated_units", "n_control_units", "control_group", "anticipation"):
        if hasattr(result, key):
            value = getattr(result, key)
            row[key] = value if isinstance(value, (int, float, str)) else str(value)
    return row


def cmd_continuous(args) -> dict:
    import diff_diff as dd

    df = load_frame(args.data)
    require_staggered_panel(df, args.outcome, args.unit, args.time, args.first_treat)
    require_columns(df, [args.dose])

    # diff-diff requires a unit-invariant dose (continuous DiD is defined on the
    # unit's treatment intensity, not on a per-period varying amount).
    spread = df.groupby(args.unit)[args.dose].nunique()
    if (spread > 1).any():
        bad = spread[spread > 1].index[:5].tolist()
        _fail(f"dose must be time-invariant per unit; varying units: {bad}")

    est = dd.ContinuousDiD(alpha=args.alpha, n_bootstrap=args.bootstrap, seed=args.seed)
    res = est.fit(
        df,
        outcome=args.outcome,
        unit=args.unit,
        time=args.time,
        first_treat=args.first_treat,
        dose=args.dose,
    )
    row = headline(res, "ContinuousDiD")
    row["overall_acrt"] = float(res.overall_acrt)
    row["overall_acrt_se"] = float(res.overall_acrt_se)
    if res.reference_dose is not None:
        row["reference_dose"] = float(res.reference_dose)
    curve = res.dose_response_att.to_dataframe()
    curve["target"] = "att"
    return {"headline": row, "dose_response": curve}


def cmd_dml(args) -> dict:
    import diff_diff as dd

    df = load_frame(args.data)
    require_staggered_panel(df, args.outcome, args.unit, args.time, args.first_treat)
    if not args.covariates:
        _fail(
            "DMLDiD requires --covariates: Chang (2020) estimates an unconditional "
            "staggered DiD only through its nuisance functions, and diff-diff rejects "
            "the no-covariate case (use CallawaySantAnna instead)"
        )
    require_columns(df, args.covariates)

    est = dd.DMLDiD(
        propensity_learner=args.propensity_learner,
        outcome_learner=args.outcome_learner,
        n_folds=args.n_folds,
        alpha=args.alpha,
        n_bootstrap=args.bootstrap,
        seed=args.seed,
        panel=not args.repeated_cross_section,
    )
    res = est.fit(
        df,
        outcome=args.outcome,
        unit=args.unit,
        time=args.time,
        first_treat=args.first_treat,
        covariates=args.covariates,
    )
    row = headline(res, "DMLDiD")
    row["n_folds"] = int(res.n_folds)
    row["propensity_learner"] = str(res.propensity_learner)
    row["outcome_learner"] = str(res.outcome_learner)
    table = res.aggregate("event_study").to_dataframe()
    return {"headline": row, "event_study": table}


def cmd_efficient(args) -> dict:
    import diff_diff as dd

    df = load_frame(args.data)
    require_staggered_panel(df, args.outcome, args.unit, args.time, args.first_treat)
    if args.covariates:
        require_columns(df, args.covariates)

    est = dd.EfficientDiD(
        pt_assumption=args.pt_assumption,
        alpha=args.alpha,
        n_bootstrap=args.bootstrap,
        seed=args.seed,
    )
    res = est.fit(
        df,
        outcome=args.outcome,
        unit=args.unit,
        time=args.time,
        first_treat=args.first_treat,
        covariates=args.covariates,
    )
    row = headline(res, "EfficientDiD")
    row["pt_assumption"] = str(res.pt_assumption)
    row["estimation_path"] = str(res.estimation_path)
    table = res.aggregate("event_study").to_dataframe()
    return {"headline": row, "event_study": table}


def cmd_duration(args) -> dict:
    import diff_diff as dd

    df = load_frame(args.data)
    require_columns(df, [args.outcome, args.unit, args.time, args.treatment])

    observed = set(pd.unique(df[args.outcome].dropna()))
    if not observed <= {0, 1, 0.0, 1.0}:
        _fail(
            "DurationDiD needs a binary absorbing outcome (spell ended), "
            f"found values: {sorted(observed)[:5]}"
        )

    est = dd.DurationDiD(
        method=args.method,
        n_bootstrap=args.bootstrap,
        alpha=args.alpha,
        seed=args.seed,
    )
    res = est.fit(
        df,
        outcome=args.outcome,
        unit=args.unit,
        time=args.time,
        treatment=args.treatment,
        last_pre_period=args.last_pre_period,
    )
    row = headline(res, "DurationDiD")
    row["method"] = str(args.method)
    row["last_pre_period"] = args.last_pre_period
    return {"headline": row, "post_periods": res.to_dataframe()}


def emit_json(payload: dict, path: Path) -> None:
    def encode(value):
        if isinstance(value, pd.DataFrame):
            return value.to_dict(orient="records")
        if isinstance(value, np.generic):
            return value.item()
        return value

    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False, default=encode) + "\n",
        encoding="utf-8",
    )


def emit_csv(payload: dict, path: Path) -> None:
    frames = []
    for name, value in payload.items():
        if isinstance(value, pd.DataFrame):
            frame = value.copy()
        elif isinstance(value, dict):
            frame = pd.DataFrame([value])
        else:
            continue
        frame.insert(0, "block", name)
        frames.append(frame)
    if not frames:
        _fail("nothing to write: payload has no tabular block")
    pd.concat(frames, ignore_index=True).to_csv(path, index=False)


def emit_dta(payload: dict, path: Path) -> None:
    row = payload.get("headline")
    if not isinstance(row, dict):
        _fail("--format dta needs a headline block")
    frame = pd.DataFrame([row])
    for col in frame.columns:
        if frame[col].dtype == object:
            frame[col] = frame[col].astype(str)
    frame.to_stata(path, write_index=False, version=118)


def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--data", required=True, help=".dta or .csv panel")
    common.add_argument("--outcome", required=True, help="numeric outcome column")
    common.add_argument("--unit", required=True, help="unit identifier column")
    common.add_argument("--time", required=True, help="integer time index column")
    common.add_argument("--alpha", type=float, default=0.05, help="significance level")
    common.add_argument("--bootstrap", type=int, default=0, help="bootstrap replications (0 = analytic)")
    common.add_argument("--seed", type=int, default=20261021, help="bootstrap seed")
    common.add_argument("-o", "--output", required=True, help="output file path")
    common.add_argument("--format", choices=["json", "csv", "dta"], default="json")

    parser = argparse.ArgumentParser(
        prog="did_py.py",
        description="Run the four DiD estimators that have no Stata implementation.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("continuous", parents=[common], help="ContinuousDiD (Callaway-Goodman-Bacon-Sant'Anna)")
    p.add_argument("--first-treat", required=True, help="first treated period; 0 = never treated")
    p.add_argument("--dose", required=True, help="unit-invariant continuous dose column")
    p.set_defaults(func=cmd_continuous)

    p = sub.add_parser("dml", parents=[common], help="DMLDiD (Chang 2020)")
    p.add_argument("--first-treat", required=True, help="first treated period; 0 = never treated")
    p.add_argument("--covariates", nargs="+", default=None, help="covariate columns (required by the estimator)")
    p.add_argument("--propensity-learner", default="logit")
    p.add_argument("--outcome-learner", default="linear")
    p.add_argument("--n-folds", type=int, default=5)
    p.add_argument("--repeated-cross-section", action="store_true", help="declare repeated cross-sections")
    p.set_defaults(func=cmd_dml)

    p = sub.add_parser("efficient", parents=[common], help="EfficientDiD (Chen-Sant'Anna-Xie 2025)")
    p.add_argument("--first-treat", required=True, help="first treated period; 0 = never treated")
    p.add_argument("--covariates", nargs="*", default=None, help="optional covariate columns")
    p.add_argument("--pt-assumption", default="all", choices=["all", "post"])
    p.set_defaults(func=cmd_efficient)

    p = sub.add_parser("duration", parents=[common], help="DurationDiD (Deaner & Ku 2026)")
    p.add_argument("--treatment", required=True, help="0/1 treated-group flag")
    p.add_argument("--last-pre-period", required=True, type=int, help="last period before treatment")
    p.add_argument("--method", default="cd", choices=["cd", "ph"], help="cd = additive hazard gap, ph = ratio")
    p.set_defaults(func=cmd_duration)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        payload = args.func(args)
    except SystemExit:
        raise
    except Exception as exc:  # diff-diff raises ValueError/TypeError on bad designs
        _fail(f"{type(exc).__name__}: {exc}")

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    if args.format == "json":
        emit_json(payload, out)
    elif args.format == "csv":
        emit_csv(payload, out)
    else:
        emit_dta(payload, out)

    head = payload["headline"]
    print(
        f"{head['estimator']}: ATT = {head['att']:.6f} "
        f"(SE {head['se']:.6f}, p {head['p_value']:.4f}) -> {out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
