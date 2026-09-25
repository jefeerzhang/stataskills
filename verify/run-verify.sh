#!/usr/bin/env bash
# ============================================================
# 验证 harness：为动态发现的 skill 验证脚本统一提供
# cd / 版本政策校验 / 批处理执行 / 结果判定 / 汇总。
#
# 用法：
#   bash verify/run-verify.sh                  # 全量（默认模式）
#   bash verify/run-verify.sh advanced         # 单个（basics/descriptives/regression/advanced/coefplot/did/did-community/rdd/selection/identification）
#   bash verify/run-verify.sh --static         # 静态层（无需 Stata，供 CI 使用）
#   bash verify/run-verify.sh --community      # 社区包强制模式（详见下方「社区包验证」段）
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
# 数据集双清单：
#   - data/manifest.txt        —— AGIS6 教材配套（data/agis6/）
#   - data/manifest-extra.txt  —— 项目级扩展（data/*-extra/，如 data/synth/）
#   脚本同时校验两份清单；任一缺数据或未登记即 BAD。
#
# 社区包验证（--community 模式）：
#   部分技能章节依赖 SSC 社区包（synth / synth_runner / sdid 等）。默认
#   模式下，脚本若检测到社区包未装，用 `cap which` 跳过关键命令并 PASS；
#   `--community` 模式下，这种"跳过"会被识别为 BAD（通过 sentinel 字符串
#   `__COMMUNITY_PACKAGE_MISSING__<pkg>__` 传递）。意图是：默认模式让
#   CI 不被网络/装包绑定，--community 模式让本地"我想真正验证社区包章节"
#   的需求显式可执行。详见 docs/adr/0003-community-packages-as-first-class-verifiable-subjects.md。
#
# 平台二进制路径唯一来源：verify/stata.conf（macOS / Windows / Linux）。
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- 参数解析 ----
STATIC_ONLY=0
COMMUNITY_MODE=0
TARGET_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --static)   STATIC_ONLY=1 ;;
    --community) COMMUNITY_MODE=1 ;;
    --help|-h)
      sed -n '2,/^set -u/p' "$0" | sed 's/^# \{0,1\}//' | head -25
      exit 0
      ;;
    *)
      TARGET_ARG="$1"   # 单个 skill 名
      ;;
  esac
  shift
done

# ---- 平台二进制路径（唯一来源：verify/stata.conf）----
# shellcheck disable=SC1091
. "$VERIFY_DIR/stata.conf"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/targets.sh"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/judge.sh"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/contract.sh"

# ---- 解析 Stata 可执行文件（macOS：PATH 优先；Windows：config 直取）----
# 静态模式不执行 do-file，无需 Stata（CI runner 上也没有）
if [ "$STATIC_ONLY" -eq 0 ]; then
  case "$(uname -s)" in
    Darwin)
      STATA_PLATFORM="macos"
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
      STATA_PLATFORM="windows"
      if [ -n "${STATA_WIN:-}" ]; then
        STATA_BIN="$STATA_WIN"
      else
        echo "ERROR: verify/stata.conf 缺少 STATA_WIN。" >&2
        exit 1
      fi
      ;;
    Linux)
      STATA_PLATFORM="linux"
      if command -v stata-mp >/dev/null 2>&1; then
        STATA_BIN="$(command -v stata-mp)"
      elif command -v stata >/dev/null 2>&1; then
        STATA_BIN="$(command -v stata)"
      elif [ -n "${STATA_LINUX:-}" ] && [ -x "$STATA_LINUX" ]; then
        STATA_BIN="$STATA_LINUX"
      else
        echo "ERROR: 找不到 Linux 的 stata-mp / stata。Linux 路径见 verify/stata.conf 的 STATA_LINUX。" >&2
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

# ---- 目标：全部或指定一个（按 skill 枚举入口；委托关系由 lib/targets.sh 解析）----
if [ -n "$TARGET_ARG" ]; then
  TARGETS=("verify-$TARGET_ARG")
else
  TARGETS=()
  for s in "$VERIFY_DIR"/../stata-*/SKILL.md; do
    [ -e "$s" ] || continue
    d="$(basename "$(dirname "$s")")"     # stata-<name>
    TARGETS+=("verify-${d#stata-}")
  done
fi

# ---- 全局：manifest 与实际 .dta 双向一致性（静态模式前置检查）----
# 两份清单（manifest.txt / manifest-extra.txt）与数据面的双向检查只经
# contract.sh 的 contract_manifest_report（#29 C3）；此处不再平行 grep 清单
# 或 find 数据树，格式规则（CRLF / 注释 / 子目录）由 seam 单点演进。
if [ "$STATIC_ONLY" -eq 1 ]; then
  manifest_drift="$(contract_manifest_report | tr '\n' ' ')"
  if [ -n "$manifest_drift" ]; then
    bad "manifest 一致性（${manifest_drift}）"
  else
    ok "manifest 一致性（agis6 + manifest-extra 与对应 .dta 双向吻合）"
  fi
fi

# ---- 阶段函数 ----

# 阶段 1：版本政策校验
check_version() {
  local name="$1" dofile="$2"
  if [ "$(head -n 1 "$dofile")" != "version 19.5" ]; then
    bad "${name}（首行缺 version 19.5，版本政策未钉住）"
    return 1
  fi
  return 0
}

# 阶段 2：data readiness —— 只经 contract_data_report（#25）；
# 不再平行解析 use 路径或自建查找顺序。
check_data_ready() {
  local name="$1" dofile="$2"
  local report
  report="$(contract_data_report "$dofile")"
  if [ -n "$report" ]; then
    # 压成单行便于 harness 摘要
    report=$(printf '%s' "$report" | tr '\n' ' ')
    bad "${name}（data contract：${report}）"
    return 1
  fi
  return 0
}

# 阶段 3：执行 Stata 批处理
run_stata() {
  local name="$1" dofile="$2"
  echo "==> 运行 ${name}（${STATA_BIN}）..."
  # cwd 切到 data/agis6/ 后，绝对路径调 do-file。dofile 已由主循环经
  # targets_plan_each_pair 展开（一个入口可委托多个 do-file，逐个调用本函数）。
  local run_dofile="$dofile"
  if [ "$STATA_PLATFORM" = "windows" ]; then
    # Stata for Windows 用 /e 运行并在完成后退出。仅排除 /e 的 MSYS 路径
    # 转换；run_dofile 仍需由 Git Bash 转成 Windows 路径。
    (cd "$DATA_DIR" && MSYS2_ARG_CONV_EXCL='/e' "$STATA_BIN" /e "do" "$run_dofile")
  else
    (cd "$DATA_DIR" && "$STATA_BIN" -b "do" "$run_dofile")
  fi
}

# 阶段 4-5：解析日志 + 判定 PASS/BAD —— 已抽取为纯函数 judge_raw_log，
# 见 verify/lib/judge.sh（无 Stata 依赖，可被 test-harness.sh 直接单元测试，
# 避免 CI 上因平台/缺 Stata 非零退出导致的假 PASS）。

# ---- 主循环 ----
for name in "${TARGETS[@]}"; do
  # 一个入口可委托多个 do-file；经 plan each_pair 按行展开（caller 不拆空格、
  # 不自行推日志名）。任一失败则该入口整体 BAD（judge_raw_log 非零 → overall_bad=1）。
  while IFS=$'\t' read -r base logbase; do
    [ -n "${base:-}" ] || continue
    dofile="$VERIFY_DIR/$base.do"

    if [ ! -f "$dofile" ]; then
      bad "${name}（找不到 ${dofile}）"
      overall_bad=1
      continue
    fi

    check_version "$base" "$dofile" || { overall_bad=1; continue; }
    check_data_ready "$base" "$dofile" || { overall_bad=1; continue; }

    # 静态模式到 data readiness 为止
    if [ "$STATIC_ONLY" -eq 1 ]; then
      ok "${name}（static：${base} version 政策 + data readiness）"
      continue
    fi

    run_stata "$base" "$dofile"
    raw_log="$DATA_DIR/${logbase}.log"
    judge_raw_log "$base" "$raw_log" "$COMMUNITY_MODE" || overall_bad=1
    # log 只留工作区供本机阅读，不再随仓库提交（ADR-0007，取代 ADR-0005）：
    # 证据由 .do 内的 assert 与 VERIFY_MARKERS_REQUIRED 标记承担，可重跑复现。
    if [ -f "$raw_log" ]; then
      cp "$raw_log" "$VERIFY_DIR/${logbase}.log"
      rm -f "$raw_log"
    fi
  done < <(targets_plan_each_pair "$name")
done

# 任何验证失败都以非零退出码结束（默认 / --static / --community 三模式一致；
# overall_bad 在上述三处检查中均无条件置位）
if [ "${overall_bad:-0}" -eq 1 ]; then
  exit 1
fi

summary
