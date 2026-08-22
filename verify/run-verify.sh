#!/usr/bin/env bash
# ============================================================
# 验证 harness：为 7 个 skill 的验证脚本统一提供
# cd / 版本政策校验 / 批处理执行 / 结果判定 / 汇总。
#
# 用法：
#   bash verify/run-verify.sh                  # 全量（七个 skill，默认模式）
#   bash verify/run-verify.sh advanced         # 单个（basics/descriptives/regression/advanced/coefplot/did）
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
# 平台二进制路径唯一来源：verify/stata.conf（macOS / Windows 双平台）。
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- 参数解析 ----
STATIC_ONLY=0
COMMUNITY_MODE=0
TARGET_ARG=""
ARGS=()
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
MANIFEST_EXTRA="$VERIFY_DIR/../data/manifest-extra.txt"
DATA_EXTRA_DIR="$(cd "$VERIFY_DIR/../data" && pwd)"

# ---- extra 子目录枚举（每个 data/<name>-extra/ 子目录一个，名称=目录名，
# 例如 data/synth/ -> manifest-extra 中的"路径前缀"synth/）。当前 manifest-extra
# 实现是平铺（基名不分子目录），但允许脚本 use "../<subdir>/<file>" 写法 ----
# ---- 目标：全部或指定一个（glob 枚举，新增 skill 只需放入 verify-*.do）----
if [ -n "$TARGET_ARG" ]; then
  TARGETS=("verify-$TARGET_ARG")
else
  TARGETS=()
  for d in "$VERIFY_DIR"/verify-*.do; do
    [ -e "$d" ] || continue
    b="$(basename "$d" .do)"
    case "$b" in verify-zz*) continue ;; esac
    TARGETS+=("$b")
  done
fi

# ---- 全局：manifest 与实际 .dta 双向一致性（静态模式前置检查）----
if [ "$STATIC_ONLY" -eq 1 ]; then
  manifest_drift=""

  # ---- AGIS6 清单（data/agis6/ 下 .dta 文件）----
  # shellcheck disable=SC2013  # manifest 每行一个基名，无空格，词分割即行分割
  for ds in $(grep -vE '^#|^[[:space:]]*$' "$MANIFEST"); do
    [ -f "$DATA_DIR/$ds.dta" ] || manifest_drift="${manifest_drift} agis6 清单有但文件缺: ${ds}.dta;"
  done
  for f in "$DATA_DIR"/*.dta; do
    [ -f "$f" ] || continue
    ds="$(basename "$f" .dta)"
    grep -qE "^${ds}[[:space:]]*$" "$MANIFEST" || manifest_drift="${manifest_drift} agis6 文件有但清单缺: ${ds}.dta;"
  done

  # ---- 项目扩展清单（data/<subdir>/<file>.dta；路径在 do-file 里写 "../<subdir>/<file>"）----
  # 解析 do-file 中所有 `use "../<subdir>/<file>"` 形式（manifest-extra 登记基名，
  # do-file 里用 subdir 前缀），但纯静态模式（在 CI）我们只校验"清单登记的每个基名
  # 在 data/ 树下能找到对应 .dta 文件"
  if [ -f "$MANIFEST_EXTRA" ]; then
    while IFS= read -r ds; do
      # 跳过注释/空行
      case "$ds" in \#*|"") continue ;; esac
      # 在 data/<任意子目录>/ 下搜
      found=0
      while IFS= read -r f; do
        [ -f "$f" ] && found=1 && break
      done < <(find "$DATA_EXTRA_DIR" -maxdepth 2 -name "${ds}.dta" -not -path "*/agis6/*" 2>/dev/null)
      if [ "$found" -eq 0 ]; then
        manifest_drift="${manifest_drift} extra 清单有但文件缺: ${ds}.dta（应在 data/<subdir>/ 下）;"
      fi
    done < <(grep -vE '^#|^[[:space:]]*$' "$MANIFEST_EXTRA")

    # 反向：data/<子目录>/ 下所有 .dta 必须登记
    while IFS= read -r f; do
      ds="$(basename "$f" .dta)"
      grep -qE "^${ds}[[:space:]]*$" "$MANIFEST_EXTRA" || manifest_drift="${manifest_drift} extra 文件有但清单缺: ${ds}.dta;"
    done < <(find "$DATA_EXTRA_DIR" -maxdepth 2 -name "*.dta" -not -path "*/agis6/*" 2>/dev/null)
  fi

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

# 阶段 2：数据就绪检查（use 语句引用的数据集必须存在且在 manifest 内）
check_data_ready() {
  local name="$1" dofile="$2"
  local missing_data="" unlisted_data=""
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    path="${path%\"}"; path="${path#\"}"
    case "$path" in
      ../*)
        rest="${path#../}"
        subdir="${rest%%/*}"
        base="${rest##*/}"; base="${base%.dta}"
        if [ ! -f "$DATA_EXTRA_DIR/$subdir/$base.dta" ]; then
          missing_data="${missing_data} ${base}.dta（应位于 data/${subdir}/）"
        elif ! grep -qE "^${base}[[:space:]]*$" "$MANIFEST_EXTRA" 2>/dev/null; then
          unlisted_data="${unlisted_data} ${base}.dta（应在 data/manifest-extra.txt 登记）"
        fi
        ;;
      *)
        if [ ! -f "$DATA_DIR/$path.dta" ]; then
          missing_data="${missing_data} ${path}.dta（应位于 data/agis6/）"
        elif ! grep -qE "^${path}[[:space:]]*$" "$MANIFEST"; then
          unlisted_data="${unlisted_data} ${path}.dta（应在 data/manifest.txt 登记）"
        fi
        ;;
    esac
  done < <(grep -oE '^use[[:space:]]+[^,[:space:]]+' "$dofile" | awk '{gsub(/"/,""); print $2}')
  if [ -n "$missing_data" ]; then
    bad "${name}（缺数据集：${missing_data}）"
    return 1
  fi
  if [ -n "$unlisted_data" ]; then
    bad "${name}（数据集未登记入 manifest：${unlisted_data}）"
    return 1
  fi
  return 0
}

# 阶段 3：执行 Stata 批处理
run_stata() {
  local name="$1" dofile="$2"
  echo "==> 运行 ${name}（${STATA_BIN}）..."
  # cwd 切到 data/agis6/ 后，绝对路径调 do-file。
  # 特殊处理：verify-did-community.do 原本是 verify-synth-sdid.do 的中转脚本，
  # （直接调 verify-synth-sdid.do，因为验证逻辑一致），避免相对路径找不到的问题。
  if [ "$name" = "verify-did-community" ]; then
    (cd "$DATA_DIR" && "$STATA_BIN" -b do "$VERIFY_DIR/verify-synth-sdid.do")
  else
    (cd "$DATA_DIR" && "$STATA_BIN" -b do "$dofile")
  fi
}

# 阶段 4：解析日志（错误码、静默错误、社区包 sentinel）
parse_log() {
  local name="$1"
  # verify-did-community 是 verify-synth-sdid.do 的中转脚本，跑出来 log 是
  # verify-synth-sdid.log；解析时把它当 verify-did-community 看。
  local log_name="$name"
  if [ "$name" = "verify-did-community" ]; then
    log_name="verify-synth-sdid"
  fi
  local log="$DATA_DIR/$log_name.log"

  if [ ! -f "$log" ]; then
    echo "NO_LOG"
    return 1
  fi

  PARSE_ENDS=$(grep -c "end of do-file" "$log")
  PARSE_ERRS=$(grep -cE '^[[:space:]]*r\([0-9]+\);[[:space:]]*$' "$log")
  PARSE_SILENT=$(grep -cE "\(variable .* not found\)|option .* not allowed|invalid syntax|no observations|(^|[^0-9])0 observations|insufficient observations|not sorted" "$log")
  PARSE_EXIT1=$(grep -cE '^[[:space:]]*r\(1\);[[:space:]]*$' "$log")
  # sentinel 匹配：Stata batch mode 下 `display "SENTINEL"` 被 echo 为 `.     display "SENTINEL"`
  # （带点号和命令前缀），且若后跟 exit 1 会被合并。不要求单独成行，
  # 用 -oE 抓所有 sentinel 字符串，再 set -u 兼容地过滤空结果。
  PARSE_COMMUNITY_REQ="$(grep -oE '__COMMUNITY_PACKAGE_MISSING__[a-zA-Z0-9_]+__' "$log" 2>/dev/null | sort -u | tr '\n' ' ' || true)"
  PARSE_COMMUNITY_OPT="$(grep -oE '__COMMUNITY_PACKAGE_OPTIONAL_MISSING__[a-zA-Z0-9_]+__' "$log" 2>/dev/null | sort -u | tr '\n' ' ' || true)"
  # sentinel 触发时的 r(1) 视为缺包触发的 exit，不算错误
  if [ -n "$PARSE_COMMUNITY_REQ" ] || [ -n "$PARSE_COMMUNITY_OPT" ]; then
    PARSE_ERRS=$((PARSE_ERRS - PARSE_EXIT1))
    [ "$PARSE_ERRS" -lt 0 ] && PARSE_ERRS=0
  fi
  return 0
}

# 阶段 5：判定 PASS/BAD
evaluate() {
  local name="$1"
  # verify-did-community 特殊：log 是 verify-synth-sdid.log
  local log_name="$name"
  if [ "$name" = "verify-did-community" ]; then
    log_name="verify-synth-sdid"
  fi
  local log="$DATA_DIR/$log_name.log"
  local local_bad=0

  if [ "$PARSE_ENDS" -eq 1 ] && [ "$PARSE_ERRS" -eq 0 ] && [ "$PARSE_SILENT" -eq 0 ]; then
    if [ -n "$PARSE_COMMUNITY_REQ" ] && [ "$COMMUNITY_MODE" -eq 1 ]; then
      bad "${name}（--community 模式下缺必需包：${PARSE_COMMUNITY_REQ}，请 ssc install 后重跑）"
      local_bad=1
    elif [ -n "$PARSE_COMMUNITY_REQ" ]; then
      ok "${name}（end of do-file x1；必需社区包未装已 cap 跳过：${PARSE_COMMUNITY_REQ}；用 --community 强制验证）"
    elif [ -n "$PARSE_COMMUNITY_OPT" ]; then
      ok "${name}（end of do-file x1；可选社区包未装已跳过：${PARSE_COMMUNITY_OPT}）"
    else
      ok "${name}（end of do-file x1，无错误码，无静默错误）"
    fi
  else
    bad "${name}（end of do-file x${PARSE_ENDS}，r(错误 x${PARSE_ERRS}，静默错误 x${PARSE_SILENT}）→ 见 ${log}"
    local_bad=1
  fi

  # log 原地更新，保持随 repo 提交（.log = 最近一次验证状态）
  cp "$log" "$VERIFY_DIR/$name.log"
  rm -f "$log"

  return $local_bad
}

# ---- 主循环 ----
for name in "${TARGETS[@]}"; do
  dofile="$VERIFY_DIR/$name.do"

  if [ ! -f "$dofile" ]; then
    bad "${name}（找不到 ${dofile}）"
    continue
  fi

  check_version "$name" "$dofile" || continue
  check_data_ready "$name" "$dofile" || continue

  # 静态模式到 data readiness 为止
  if [ "$STATIC_ONLY" -eq 1 ]; then
    ok "${name}（static：version 政策 + data readiness）"
    continue
  fi

  run_stata "$name" "$dofile"
  parse_log "$name" || { bad "${name}（无 log 生成，批处理未执行）"; continue; }
  evaluate "$name" || overall_bad=1
done

# verify-did-community 特殊：原本是 verify-synth-sdid.do 的中转脚本，
# 跑出来 log 名是 verify-synth-sdid.log，但对外技能名是 verify-did-community。
# 主循环结束后复制一份 verify-did-community.log 让 check-claims.sh 的
# demo→verify 配对断言能找到它。
if [ -f "$VERIFY_DIR/verify-synth-sdid.log" ] && [ ! -f "$VERIFY_DIR/verify-did-community.log" ]; then
  cp "$VERIFY_DIR/verify-synth-sdid.log" "$VERIFY_DIR/verify-did-community.log"
fi

# --community 模式下任何验证失败都让 harness 以非零退出码结束
if [ "${overall_bad:-0}" -eq 1 ]; then
  exit 1
fi

summary
