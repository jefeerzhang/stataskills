#!/usr/bin/env bash
# ============================================================
# 验证 harness：为 4 个 skill 的验证脚本统一提供
# cd / 版本政策校验 / 批处理执行 / 结果判定 / 汇总。
#
# 用法：
#   bash verify/run-verify.sh            # 全量（四个 skill）
#   bash verify/run-verify.sh advanced   # 单个（basics/descriptives/regression/advanced）
#
# 判定标准（与 demo/REPORT.md 一致）：日志恰好一次 "end of do-file"
# 且无 Stata 错误码 r(NN) 且无静默错误（variable not found /
# option not allowed / invalid syntax / no observations 等）→ PASS；
# 任一失败以非零退出码结束。
# 错误码匹配用 `r\([0-9]{2,}\)`（至少 2 位数字），避免误吃合法命令参数
# 如 power(0.90) / star(5) 中的 r(...) 子串。
#
# 平台二进制路径唯一来源：verify/stata.conf（macOS / Windows 双平台）。
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- 平台二进制路径（唯一来源：verify/stata.conf）----
# shellcheck disable=SC1091
. "$VERIFY_DIR/stata.conf"

# ---- 解析 Stata 可执行文件（macOS：PATH 优先；Windows：config 直取）----
case "$(uname -s)" in
  Darwin)
    if command -v stata-mp >/dev/null 2>&1; then
      STATA_BIN="$(command -v stata-mp)"
    elif [ -n "${STATA_MAC:-}" ] && [ -x "$STATA_MAC" ]; then
      STATA_BIN="$STATA_MAC"
    else
      echo "ERROR: 找不到 stata-mp。macOS 路径见 verify/stata.conf 的 STATA_MAC。" >&2
      exit 1
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    if [ -n "${STATA_WIN:-}" ]; then
      STATA_BIN="$STATA_WIN"
    else
      echo "ERROR: verify/stata.conf 缺少 STATA_WIN。" >&2
      exit 1
    fi
    ;;
  *)
    echo "ERROR: 未识别的平台 $(uname -s)，请在 verify/stata.conf 补充该平台路径。" >&2
    exit 1
    ;;
esac

DATA_DIR="$(cd "$VERIFY_DIR/../data/agis6" && pwd)"

# ---- 目标：全部或指定一个 ----
if [ $# -ge 1 ]; then
  TARGETS=("verify-$1")
else
  TARGETS=(verify-basics verify-descriptives verify-regression verify-advanced verify-coefplot)
fi

pass=0
fail=0
for name in "${TARGETS[@]}"; do
  dofile="$VERIFY_DIR/$name.do"

  if [ ! -f "$dofile" ]; then
    echo "FAIL  ${name}（找不到 ${dofile}）"
    fail=$((fail+1))
    continue
  fi

  # 版本政策：每份叶子首行必须是 version 19.5（Stata 的 version 是 session 内指令，
  # 只能逐 do-file 声明；harness 在此校验它以钉住 policy）
  if ! grep -q '^version 19.5$' "$dofile"; then
    echo "FAIL  ${name}（首行缺 version 19.5，版本政策未钉住）"
    fail=$((fail+1))
    continue
  fi

  # data readiness：该 skill 引用的数据集必须存在（清单见 data/manifest.txt）
  missing_data=""
  for ds in $(grep -oE '^use[[:space:]]+[A-Za-z0-9_-]+' "$dofile" | awk '{print $2}'); do
    if [ ! -f "$DATA_DIR/$ds.dta" ]; then
      missing_data="${missing_data} ${ds}.dta"
    fi
  done
  if [ -n "$missing_data" ]; then
    echo "FAIL  ${name}（缺数据集：${missing_data}，见 data/manifest.txt）"
    fail=$((fail+1))
    continue
  fi

  echo "==> 运行 ${name}（${STATA_BIN}）..."
  (cd "$DATA_DIR" && "$STATA_BIN" -b do "$dofile")

  log="$DATA_DIR/$name.log"
  if [ ! -f "$log" ]; then
    echo "FAIL  ${name}（无 log 生成，批处理未执行）"
    fail=$((fail+1))
    continue
  fi

  ends=$(grep -c "end of do-file" "$log")
  errs=$(grep -cE "r\([0-9]{2,}\)" "$log")
  # 捕获 cap 掩盖不住的静默错误（reshape 错位、变量不存在等），
  # 避免只靠 end of do-file + r(NN) 漏掉 data-integrity 问题。
  silent=$(grep -cE "\(variable .* not found\)|option .* not allowed|invalid syntax|no observations|(^|[^0-9])0 observations|insufficient observations|not sorted" "$log")
  if [ "$ends" -eq 1 ] && [ "$errs" -eq 0 ] && [ "$silent" -eq 0 ]; then
    echo "PASS  ${name}（end of do-file x1，无错误码，无静默错误）"
    pass=$((pass+1))
  else
    echo "FAIL  ${name}（end of do-file x${ends}，r(错误 x${errs}，静默错误 x${silent}）→ 见 ${log}"
    fail=$((fail+1))
  fi
  # log 原地更新，保持随 repo 提交（.log = 最近一次验证状态）
  cp "$log" "$VERIFY_DIR/$name.log"
  # 不留副本在数据目录（数据目录只放数据）
  rm -f "$log"
done

echo
echo "结果：${pass} 通过，${fail} 失败"
[ "$fail" -eq 0 ]
