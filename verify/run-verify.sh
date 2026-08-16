#!/usr/bin/env bash
# ============================================================
# 验证 harness：为 5 个 skill 的验证脚本统一提供
# cd / 版本政策校验 / 批处理执行 / 结果判定 / 汇总。
#
# 用法：
#   bash verify/run-verify.sh            # 全量（五个 skill）
#   bash verify/run-verify.sh advanced   # 单个（basics/descriptives/regression/advanced/coefplot）
#   bash verify/run-verify.sh --static   # 静态层（无需 Stata，供 CI 使用）：
#                                        # 版本政策 + 数据集存在 + manifest 登记
#                                        # + manifest 与实际 .dta 双向一致性
#
# 判定标准（与 demo/REPORT.md 一致）：日志恰好一次 "end of do-file"
# 且无 Stata 错误码 r(NN) 且无静默错误（variable not found /
# option not allowed / invalid syntax / no observations 等）→ PASS；
# 任一失败以非零退出码结束。
# 错误码匹配用整行锚定 ^[[:space:]]*r\([0-9]+\);[[:space:]]*$：Stata 报错时
# 错误码独占一行（形如 "    r(111);"），既能捕获个位数错误码（如 assert
# 失败的 r(9)，旧版 {2,} 正则漏判），又不会误吃命令行内嵌的合法子串
# 如 power(0.90) / star(5) 中的 r(...)。
#
# 平台二进制路径唯一来源：verify/stata.conf（macOS / Windows 双平台）。
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- 静态模式（CI：runner 无 Stata，只跑不需要执行的检查层）----
STATIC_ONLY=0
if [ "${1:-}" = "--static" ]; then
  STATIC_ONLY=1
  shift
fi

# ---- 平台二进制路径（唯一来源：verify/stata.conf）----
# shellcheck disable=SC1091
. "$VERIFY_DIR/stata.conf"

# ---- 解析 Stata 可执行文件（macOS：PATH 优先；Windows：config 直取）----
# 静态模式不执行 do-file，无需 Stata（CI runner 上也没有）
if [ "$STATIC_ONLY" -eq 0 ]; then
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
fi

DATA_DIR="$(cd "$VERIFY_DIR/../data/agis6" && pwd)"
MANIFEST="$VERIFY_DIR/../data/manifest.txt"

# ---- 目标：全部或指定一个 ----
if [ $# -ge 1 ]; then
  TARGETS=("verify-$1")
else
  TARGETS=(verify-basics verify-descriptives verify-regression verify-advanced verify-coefplot)
fi

pass=0
fail=0

# ---- 全局：manifest 与实际 .dta 双向一致性（静态模式前置检查）----
if [ "$STATIC_ONLY" -eq 1 ]; then
  manifest_drift=""
  # shellcheck disable=SC2013  # manifest 每行一个基名，无空格，词分割即行分割
  for ds in $(grep -vE '^#|^[[:space:]]*$' "$MANIFEST"); do
    [ -f "$DATA_DIR/$ds.dta" ] || manifest_drift="${manifest_drift} 清单有但文件缺: ${ds}.dta; "
  done
  for f in "$DATA_DIR"/*.dta; do
    ds="$(basename "$f" .dta)"
    grep -qE "^${ds}[[:space:]]*$" "$MANIFEST" || manifest_drift="${manifest_drift} 文件有但清单缺: ${ds}.dta; "
  done
  if [ -n "$manifest_drift" ]; then
    echo "FAIL  manifest 一致性（${manifest_drift}）"
    fail=$((fail+1))
  else
    echo "PASS  manifest 一致性（清单与 data/agis6/*.dta 双向吻合）"
    pass=$((pass+1))
  fi
fi

for name in "${TARGETS[@]}"; do
  dofile="$VERIFY_DIR/$name.do"

  if [ ! -f "$dofile" ]; then
    echo "FAIL  ${name}（找不到 ${dofile}）"
    fail=$((fail+1))
    continue
  fi

  # 版本政策：每份叶子首行必须是 version 19.5（Stata 的 version 是 session 内指令，
  # 只能逐 do-file 声明；harness 在此校验它以钉住 policy）
  if [ "$(head -n 1 "$dofile")" != "version 19.5" ]; then
    echo "FAIL  ${name}（首行缺 version 19.5，版本政策未钉住）"
    fail=$((fail+1))
    continue
  fi

  # data readiness：该 skill 引用的数据集必须存在，且必须在
  # data/manifest.txt 清单内（单一来源：新增数据集先改清单）
  missing_data=""
  unlisted_data=""
  # shellcheck disable=SC2013  # 数据集基名无空格，词分割即行分割
  for ds in $(grep -oE '^use[[:space:]]+[A-Za-z0-9_-]+' "$dofile" | awk '{print $2}'); do
    if [ ! -f "$DATA_DIR/$ds.dta" ]; then
      missing_data="${missing_data} ${ds}.dta"
    elif ! grep -qE "^${ds}[[:space:]]*$" "$MANIFEST"; then
      unlisted_data="${unlisted_data} ${ds}.dta"
    fi
  done
  if [ -n "$missing_data" ]; then
    echo "FAIL  ${name}（缺数据集：${missing_data}，见 data/manifest.txt）"
    fail=$((fail+1))
    continue
  fi
  if [ -n "$unlisted_data" ]; then
    echo "FAIL  ${name}（数据集未登记入 data/manifest.txt：${unlisted_data}）"
    fail=$((fail+1))
    continue
  fi

  # 静态模式到 data readiness 为止；执行层需要本机 Stata（见 stata.conf）
  if [ "$STATIC_ONLY" -eq 1 ]; then
    echo "PASS  ${name}（static：version 政策 + data readiness）"
    pass=$((pass+1))
    continue
  fi

  echo "==> 运行 ${name}（${STATA_BIN}）..."
  # shellcheck disable=SC1010  # "do" 是 stata -b 的子命令，非 bash 关键字
  (cd "$DATA_DIR" && "$STATA_BIN" -b do "$dofile")

  log="$DATA_DIR/$name.log"
  if [ ! -f "$log" ]; then
    echo "FAIL  ${name}（无 log 生成，批处理未执行）"
    fail=$((fail+1))
    continue
  fi

  ends=$(grep -c "end of do-file" "$log")
  errs=$(grep -cE '^[[:space:]]*r\([0-9]+\);[[:space:]]*$' "$log")
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
