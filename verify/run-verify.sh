#!/usr/bin/env bash
# ============================================================
# 验证 harness：为 6 个 skill 的验证脚本统一提供
# cd / 版本政策校验 / 批处理执行 / 结果判定 / 汇总。
#
# 用法：
#   bash verify/run-verify.sh                  # 全量（六个 skill，默认模式）
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
#   的需求显式可执行。详见 docs/adr/（待写：ADR-0003）。
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

for name in "${TARGETS[@]}"; do
  dofile="$VERIFY_DIR/$name.do"

  if [ ! -f "$dofile" ]; then
    bad "${name}（找不到 ${dofile}）"
    continue
  fi

  # 版本政策：每份叶子首行必须是 version 19.5（Stata 的 version 是 session 内指令，
  # 只能逐 do-file 声明；harness 在此校验它以钉住 policy）
  if [ "$(head -n 1 "$dofile")" != "version 19.5" ]; then
    bad "${name}（首行缺 version 19.5，版本政策未钉住）"
    continue
  fi

  # data readiness：该 skill 引用的数据集必须存在，且必须在某份
  # manifest 清单内（AGIS6 用 manifest.txt；项目扩展用 manifest-extra.txt）。
  # 新增数据集先改对应清单。
  #
  # use 形式支持两种：
  #   use <basename>, clear               → 在 data/agis6/ 下查
  #   use "../<subdir>/<basename>", clear → 在 data/<subdir>/ 下查
  missing_data=""
  unlisted_data=""
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    # 去掉可能包裹的双引号
    path="${path%\"}"; path="${path#\"}"
    case "$path" in
      ../*)
        # 形式 "../<subdir>/<base>.dta" —— 切出 subdir 和 base（去掉 .dta）
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
    continue
  fi
  if [ -n "$unlisted_data" ]; then
    bad "${name}（数据集未登记入 manifest：${unlisted_data}）"
    continue
  fi

  # 静态模式到 data readiness 为止；执行层需要本机 Stata（见 stata.conf）
  if [ "$STATIC_ONLY" -eq 1 ]; then
    ok "${name}（static：version 政策 + data readiness）"
    continue
  fi

  echo "==> 运行 ${name}（${STATA_BIN}）..."
  # shellcheck disable=SC1010  # "do" 是 stata -b 的子命令，非 bash 关键字
  (cd "$DATA_DIR" && "$STATA_BIN" -b do "$dofile")

  log="$DATA_DIR/$name.log"
  if [ ! -f "$log" ]; then
    bad "${name}（无 log 生成，批处理未执行）"
    continue
  fi

  ends=$(grep -c "end of do-file" "$log")
  errs=$(grep -cE '^[[:space:]]*r\([0-9]+\);[[:space:]]*$' "$log")
  # 捕获 cap 掩盖不住的静默错误（reshape 错位、变量不存在等），
  # 避免只靠 end of do-file + r(NN) 漏掉 data-integrity 问题。
  silent=$(grep -cE "\(variable .* not found\)|option .* not allowed|invalid syntax|no observations|(^|[^0-9])0 observations|insufficient observations|not sorted" "$log")

  # 社区包缺失 sentinel（两种）：
  #   display "__COMMUNITY_PACKAGE_MISSING__<pkg>__"           —— 必需包；--community 模式下报告 BAD
  #   display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__<pkg>__" —— 可选包；仅警告，不影响 --community PASS
  # 默认模式两者都静默 PASS（cap which 风格），但 ok 信息提示用户。
  community_required=$(grep -oE '^[[:space:]]*__COMMUNITY_PACKAGE_MISSING__[a-zA-Z0-9_]+__[[:space:]]*$' "$log" | sort -u | tr "\n" " ")
  community_optional=$(grep -oE '^[[:space:]]*__COMMUNITY_PACKAGE_OPTIONAL_MISSING__[a-zA-Z0-9_]+__[[:space:]]*$' "$log" | sort -u | tr "\n" " ")

  local_bad=0
  if [ "$ends" -eq 1 ] && [ "$errs" -eq 0 ] && [ "$silent" -eq 0 ]; then
    if [ -n "$community_required" ] && [ "$COMMUNITY_MODE" -eq 1 ]; then
      bad "${name}（--community 模式下缺必需包：${community_required}，请 ssc install 后重跑）"
      local_bad=1
    elif [ -n "$community_required" ]; then
      ok "${name}（end of do-file x1；必需社区包未装已 cap 跳过：${community_required}；用 --community 强制验证）"
    elif [ -n "$community_optional" ]; then
      ok "${name}（end of do-file x1；可选社区包未装已跳过：${community_optional}）"
    else
      ok "${name}（end of do-file x1，无错误码，无静默错误）"
    fi
  else
    bad "${name}（end of do-file x${ends}，r(错误 x${errs}，静默错误 x${silent}）→ 见 ${log}"
    local_bad=1
  fi

  # log 原地更新，保持随 repo 提交（.log = 最近一次验证状态）
  cp "$log" "$VERIFY_DIR/$name.log"
  # 不留副本在数据目录（数据目录只放数据）
  rm -f "$log"

  if [ "$local_bad" -eq 1 ]; then
    overall_bad=1
  fi
done

# --community 模式下任何验证失败都让 harness 以非零退出码结束
if [ "${overall_bad:-0}" -eq 1 ]; then
  exit 1
fi

summary
