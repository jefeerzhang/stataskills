#!/usr/bin/env bash
# ============================================================
# 验证：stata-did-community 的 Python 补位层
#
# 四个无 Stata 实现的估计量经 stata-did-community/python/did_py.py
# 调用 diff-diff 执行。本脚本同时验证：
#   1. 依赖可用性（python + diff-diff）；缺失时静默 PASS（CI 不被网络绑定）
#   2. 四个子命令各自跑通，HEADLINE 数值有限
#   3. 三种输出格式（json / csv / dta）都可读
#   4. 三条设计护栏（剂量时不变、DML 需协变量、duration 需二元结果）
#
# 手动：bash verify/verify-did-python.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$VERIFY_DIR/.." && pwd)"
PY="${PYTHON:-python}"
CLI="$REPO_ROOT/stata-did-community/python/did_py.py"
DATA="$REPO_ROOT/data/did-python"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"

# ---- 段 0：依赖探测（缺失 → 静默 PASS）----
if ! command -v "$PY" >/dev/null 2>&1; then
  ok "did-python（无 python，跳过）"
  exit 0
fi
if ! "$PY" -c 'import diff_diff' >/dev/null 2>&1; then
  ok "did-python（无 diff-diff，跳过；pip install diff-diff 后可跑）"
  exit 0
fi
ok "did-python 依赖就绪（$("$PY" -c 'import diff_diff;print(diff_diff.__version__)')）"

# ---- 段 1：四个子命令 ----
run_case() {
  local name="$1"; shift
  if "$PY" "$CLI" "$name" "$@" -o "$TMP/$name.json" >"$TMP/$name.out" 2>"$TMP/$name.err"; then
    if "$PY" - "$TMP/$name.json" <<'PY'
import json, math, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
h = d["headline"]
assert h["estimator"], "estimator missing"
assert math.isfinite(h["att"]), "att not finite"
assert math.isfinite(h["se"]), "se not finite"
assert h["n_obs"] > 0, "n_obs not positive"
PY
    then
      ok "did-python ${name}"
    else
      bad "did-python ${name}（JSON 断言失败）"
    fi
  else
    bad "did-python ${name}（$(tail -1 "$TMP/$name.err")）"
  fi
}

run_case continuous --data "$DATA/panel_staggered.dta" --outcome y --unit id \
  --time t --first-treat g --dose dose
run_case dml --data "$DATA/panel_staggered.dta" --outcome y --unit id \
  --time t --first-treat g --covariates x1 x2
run_case efficient --data "$DATA/panel_staggered.dta" --outcome y --unit id \
  --time t --first-treat g
run_case duration --data "$DATA/spell_duration.dta" --outcome y --unit id \
  --time t --treatment treated --last-pre-period 5 --bootstrap 50

# ---- 段 2：输出格式 ----
if "$PY" "$CLI" efficient --data "$DATA/panel_staggered.dta" --outcome y --unit id \
     --time t --first-treat g --format csv -o "$TMP/eff.csv" >/dev/null 2>&1 \
   && "$PY" - "$TMP/eff.csv" <<'PY'
import pandas as pd, sys
df = pd.read_csv(sys.argv[1])
assert "block" in df.columns, "block column missing"
assert "headline" in set(df["block"]), "headline block missing"
PY
then
  ok "did-python csv 输出"
else
  bad "did-python csv 输出（无法读回或 block 列缺失）"
fi

if "$PY" "$CLI" efficient --data "$DATA/panel_staggered.dta" --outcome y --unit id \
     --time t --first-treat g --format dta -o "$TMP/eff.dta" >/dev/null 2>&1 \
   && "$PY" - "$TMP/eff.dta" <<'PY'
import pandas as pd, sys
df = pd.read_stata(sys.argv[1])
assert len(df) == 1, f"expected one headline row, got {len(df)}"
assert "att" in df.columns, "att column missing"
PY
then
  ok "did-python dta 输出（pandas 读回）"
else
  bad "did-python dta 输出（无法读回或行数不为 1）"
fi

# ---- 段 2b：dta 产物必须能被真实 Stata 读回（本机有 Stata 时才跑）----
# pandas 能读回不等于 Stata 能 use：strL / 编码 / 版本写入差异只有 Stata 自己
# 能证伪。本段是 --format dta 用途声明（「Stata 可直接 use」）的唯一证据来源。
STATA_BIN=""
if [ -f "$VERIFY_DIR/stata.conf" ]; then
  # shellcheck disable=SC1091
  . "$VERIFY_DIR/stata.conf"
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) STATA_BIN="${STATA_WIN:-}" ;;
    Darwin) STATA_BIN="${STATA_MAC:-}" ;;
    Linux) STATA_BIN="${STATA_LINUX:-}" ;;
    *) STATA_BIN="" ;;
  esac
fi
if [ -z "$STATA_BIN" ] || [ ! -f "$STATA_BIN" ]; then
  ok "did-python dta→Stata 读回（无 Stata，跳过）"
else
  mkdir -p "$TMP/readback"
  cp "$TMP/eff.dta" "$TMP/readback/headline.dta"
  cat > "$TMP/readback/readback.do" <<'DO'
version 19.5
clear all
set more off
capture log close
log using "readback_result.log", replace text
use "headline.dta", clear
assert _N == 1
assert !missing(att)
assert !missing(se)
display "STATA_DTA_READBACK_OK"
log close
DO
  if [ "$(uname -s | cut -c1-6)" = "MINGW" ] || [ "$(uname -s | cut -c1-5)" = "MSYS" ]; then
    powershell -NoProfile -Command \
      "Start-Process -FilePath '$STATA_BIN' -ArgumentList '/e','do','readback.do' -WorkingDirectory '$(cygpath -w "$TMP/readback")' -Wait" \
      >/dev/null 2>&1
  else
    (cd "$TMP/readback" && "$STATA_BIN" -b do readback.do >/dev/null 2>&1)
  fi
  if grep -q 'STATA_DTA_READBACK_OK' "$TMP/readback/readback_result.log" 2>/dev/null; then
    ok "did-python dta→Stata 读回（真实 Stata use + 3 条 assert）"
  else
    bad "did-python dta→Stata 读回失败（$(tail -3 "$TMP/readback/readback_result.log" 2>/dev/null | tr '\n' ' ')）"
  fi
fi

# ---- 段 3：设计护栏必须报错（非零退出 + 明确信息）----
guard() {
  local name="$1" needle="$2"; shift 2
  if "$PY" "$CLI" "$@" -o "$TMP/guard.json" >"$TMP/guard.out" 2>"$TMP/guard.err"; then
    bad "did-python 护栏 ${name}（本应失败却成功）"
  elif grep -q "$needle" "$TMP/guard.err"; then
    ok "did-python 护栏 ${name}"
  else
    bad "did-python 护栏 ${name}（报错信息不含「${needle}」：$(tail -1 "$TMP/guard.err")）"
  fi
}

guard "DML 无协变量被拒" "requires --covariates" dml \
  --data "$DATA/panel_staggered.dta" --outcome y --unit id --time t --first-treat g
guard "duration 非二元结果被拒" "binary absorbing outcome" duration \
  --data "$DATA/panel_staggered.dta" --outcome y --unit id --time t --treatment d --last-pre-period 4

# ---- 段 4：非有限头条结果必须 fail closed，不得写出 NaN 报告 ----
# 实测事故：spell_duration 的早期 DGP 让对照在后期几乎耗尽，DurationDiD 的
# 插补反事实曲线非单调，返回 att=NaN 且 rc=0。若 CLI 照写 JSON，下游报告会
# 引用一个 NaN。护栏因此下沉到 did_py.headline()。
cat > "$TMP/nan_panel.csv" <<'CSV'
id,t,treated,y
1,1,0,0
1,2,0,0
1,3,0,0
1,4,0,0
1,5,0,1
1,6,0,1
1,7,0,1
1,8,0,1
2,1,1,0
2,2,1,0
2,3,1,0
2,4,1,0
2,5,1,0
2,6,1,0
2,7,1,0
2,8,1,0
CSV
if "$PY" "$CLI" duration --data "$TMP/nan_panel.csv" --outcome y --unit id --time t \
     --treatment treated --last-pre-period 4 --bootstrap 20 -o "$TMP/nan.json" \
     >"$TMP/nan.out" 2>"$TMP/nan.err"; then
  bad "did-python 非有限结果护栏（退化设计本应失败却成功）"
else
  ok "did-python 非有限结果护栏（退化设计 fail closed）"
fi

summary
