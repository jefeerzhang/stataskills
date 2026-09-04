#!/usr/bin/env bash
# ============================================================
# 回归测试：VERIFY CONTRACT + data locator（verify/lib/contract.sh）
#
# Issue #21 / #25 / parent #18：table-driven 覆盖
#   - metadata 解析
#   - 穷尽 data 声明缺口（partial declaration → 非空 gaps）
#   - stale declaration
#   - contract_data_report 五类 KIND
#   - missing / unlisted / duplicate basename / CRLF manifest
#   - 三类仓库路径（agis6 / external / generated）+ sysuse / sim
#   - 生产 verify-*.do 穷尽 report 为空
#
# 用法：bash verify/test-contract.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$VERIFY_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh" 2>/dev/null || true

fail=0
pass() { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; fail=$((fail + 1)); }

# shellcheck disable=SC1091
if ! . "$VERIFY_DIR/lib/contract.sh" 2>/dev/null; then
  bad "无法 source verify/lib/contract.sh"
  echo "结果：${fail} 失败"
  exit 1
fi

for fn in contract_parse contract_data_declared contract_literal_repo_reads \
          contract_exhaustive_gaps contract_stale_declarations \
          contract_data_report data_locate; do
  if ! declare -F "$fn" >/dev/null 2>&1; then
    bad "缺少函数 $fn（#21/#25 contract / data locator）"
  fi
done
if [ "$fail" -gt 0 ]; then
  echo "结果：${fail} 失败"
  exit 1
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/stataskills-contract.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ---- fixture helpers ----
write_do() {
  local path="$1"
  shift
  printf '%s\n' "$@" >"$path"
}

# ---- 1. metadata 解析 ----
write_do "$WORKDIR/meta.do" \
  'version 19.5' \
  '* ==== VERIFY CONTRACT ====' \
  '* skill:    stata-basics' \
  '* chapter:  ch1' \
  '* data:     relate.dta;sim:10x2' \
  '* checks:   use+describe' \
  '* ============================' \
  'use relate, clear'

eval "$(contract_parse "$WORKDIR/meta.do")"
if [ "${CONTRACT_SKILL:-}" = "stata-basics" ] && \
   [ "${CONTRACT_CHAPTER:-}" = "ch1" ] && \
   [ "${CONTRACT_DATA:-}" = "relate.dta;sim:10x2" ] && \
   [ "${CONTRACT_CHECKS:-}" = "use+describe" ]; then
  pass "contract_parse 读取 4 字段 metadata"
else
  bad "contract_parse metadata 错误：skill=${CONTRACT_SKILL:-} chapter=${CONTRACT_CHAPTER:-} data=${CONTRACT_DATA:-} checks=${CONTRACT_CHECKS:-}"
fi

# ---- 2. 穷尽声明：多次 literal read、只声明部分 → gaps 非空（红 fixture）----
write_do "$WORKDIR/partial.do" \
  'version 19.5' \
  '* ==== VERIFY CONTRACT ====' \
  '* skill:    stata-basics' \
  '* chapter:  ch1' \
  '* data:     relate.dta' \
  '* checks:   use' \
  '* ============================' \
  'use relate, clear' \
  'use firstsurvey_chapter4, clear'

gaps=$(contract_exhaustive_gaps "$WORKDIR/partial.do")
case "$gaps" in
  *firstsurvey_chapter4*) pass "穷尽声明缺口列出未声明 literal read（firstsurvey_chapter4）" ;;
  *) bad "穷尽声明缺口未捕获 partial fixture：gaps=[$gaps]" ;;
esac

# 补全声明后 gaps 应空（绿）
write_do "$WORKDIR/full.do" \
  'version 19.5' \
  '* ==== VERIFY CONTRACT ====' \
  '* skill:    stata-basics' \
  '* chapter:  ch1' \
  '* data:     relate.dta;firstsurvey_chapter4.dta' \
  '* checks:   use' \
  '* ============================' \
  'use relate, clear' \
  'use firstsurvey_chapter4, clear'

gaps=$(contract_exhaustive_gaps "$WORKDIR/full.do")
if [ -z "$gaps" ]; then
  pass "穷尽声明完整时 gaps 为空"
else
  bad "完整声明仍有 gaps：[$gaps]"
fi

# ---- 3. 三类仓库路径 + sysuse/sim（真实 repo 资产）----
# agis6
eval "$(data_locate "relate.dta")"
if [ "${DATA_KIND:-}" = "agis6" ] && [ "${DATA_LISTED:-}" = "1" ] && [ -n "${DATA_PATH:-}" ] && [ -f "${DATA_PATH}" ]; then
  pass "data_locate agis6：relate.dta"
else
  bad "data_locate agis6 失败：kind=${DATA_KIND:-} listed=${DATA_LISTED:-} path=${DATA_PATH:-}"
fi

# external（synth：有 download_*.sh）
eval "$(data_locate "data/synth/synth_smoking.dta")"
if [ "${DATA_KIND:-}" = "external" ] && [ "${DATA_LISTED:-}" = "1" ]; then
  pass "data_locate external：synth_smoking"
else
  bad "data_locate external 失败：kind=${DATA_KIND:-} listed=${DATA_LISTED:-}"
fi

# generated（selection：有 build-*.do）
eval "$(data_locate "selection/teaching-treatment.dta")"
if [ "${DATA_KIND:-}" = "generated" ] && [ "${DATA_LISTED:-}" = "1" ]; then
  pass "data_locate generated：teaching-treatment"
else
  bad "data_locate generated 失败：kind=${DATA_KIND:-} listed=${DATA_LISTED:-}"
fi

# sysuse / sim
eval "$(data_locate "sysuse:auto")"
[ "${DATA_KIND:-}" = "sysuse" ] && pass "data_locate sysuse" || bad "data_locate sysuse → ${DATA_KIND:-}"
eval "$(data_locate "sim:200x10")"
[ "${DATA_KIND:-}" = "sim" ] && pass "data_locate sim" || bad "data_locate sim → ${DATA_KIND:-}"

# ---- 4. missing / unlisted ----
eval "$(data_locate "no_such_dataset_xyz.dta")"
if [ "${DATA_KIND:-}" = "missing" ] || [ "${DATA_LISTED:-}" = "0" -a ! -f "${DATA_PATH:-/nonexistent}" ]; then
  # prefer explicit missing kind
  if [ "${DATA_KIND:-}" = "missing" ]; then
    pass "data_locate missing：不存在的 agis6 基名"
  else
    bad "data_locate missing 应用 kind=missing，得 kind=${DATA_KIND:-}"
  fi
else
  bad "data_locate missing 未识别"
fi

# unlisted：文件存在于临时 data 树但不在 manifest —— 用 locator 对「假想基名」
# 已存在于磁盘但未登记的情况：造一个临时 REPO 布局太重；改测
# data_locate_unlisted_probe 或对真实文件强制 listed=0。
# 约定：若 path 在 data/agis6 存在但基名不在 manifest → kind=unlisted
# 造临时：复制 locate 逻辑用 CONTRACT_REPO_ROOT override
export CONTRACT_REPO_ROOT="$WORKDIR/fake_repo"
mkdir -p "$CONTRACT_REPO_ROOT/data/agis6"
printf 'only_listed\n' >"$CONTRACT_REPO_ROOT/data/manifest.txt"
printf '# empty extra\n' >"$CONTRACT_REPO_ROOT/data/manifest-extra.txt"
: >"$CONTRACT_REPO_ROOT/data/agis6/only_listed.dta"
: >"$CONTRACT_REPO_ROOT/data/agis6/orphan_file.dta"

eval "$(data_locate "orphan_file.dta")"
if [ "${DATA_KIND:-}" = "unlisted" ]; then
  pass "data_locate unlisted：文件在 agis6 但未入 manifest"
else
  bad "data_locate unlisted 失败：kind=${DATA_KIND:-}"
fi

# ---- 5. duplicate basename（manifest 重复行）----
printf 'dup_base\ndup_base\n' >"$CONTRACT_REPO_ROOT/data/manifest.txt"
: >"$CONTRACT_REPO_ROOT/data/agis6/dup_base.dta"
eval "$(data_locate "dup_base.dta")"
if [ "${DATA_KIND:-}" = "duplicate" ] || [ "${DATA_DUPLICATE:-}" = "1" ]; then
  pass "data_locate duplicate basename：manifest 重复登记"
else
  bad "data_locate duplicate 失败：kind=${DATA_KIND:-} dup=${DATA_DUPLICATE:-}"
fi

# ---- 6. CRLF manifest ----
printf 'crlf_ds\r\n' >"$CONTRACT_REPO_ROOT/data/manifest.txt"
: >"$CONTRACT_REPO_ROOT/data/agis6/crlf_ds.dta"
eval "$(data_locate "crlf_ds.dta")"
if [ "${DATA_KIND:-}" = "agis6" ] && [ "${DATA_LISTED:-}" = "1" ]; then
  pass "data_locate CRLF manifest：剥离 \\r 后仍 listed"
else
  bad "data_locate CRLF 失败：kind=${DATA_KIND:-} listed=${DATA_LISTED:-}"
fi

unset CONTRACT_REPO_ROOT

# ---- 7. contract_data_declared / literal reads 形状 ----
decl=$(contract_data_declared "$WORKDIR/full.do" | tr '\n' ' ')
case " $decl " in
  *" relate.dta "*|*" relate "*) ;;
  *) bad "contract_data_declared 缺 relate：[$decl]"; decl=__bad__ ;;
esac
[ "$decl" != "__bad__" ] && pass "contract_data_declared 列出声明项"

reads=$(contract_literal_repo_reads "$WORKDIR/partial.do" | tr '\n' ' ')
case " $reads " in
  *"firstsurvey_chapter4"*) pass "contract_literal_repo_reads 捕获 use 语句" ;;
  *) bad "contract_literal_repo_reads 失败：[$reads]" ;;
esac

# ---- 8. stale declaration + contract_data_report 五类 KIND ----
write_do "$WORKDIR/stale.do" \
  'version 19.5' \
  '* ==== VERIFY CONTRACT ====' \
  '* skill:    stata-basics' \
  '* chapter:  ch1' \
  '* data:     relate.dta;firstsurvey_chapter4.dta' \
  '* checks:   use' \
  '* ============================' \
  'use relate, clear'

stale=$(contract_stale_declarations "$WORKDIR/stale.do")
case "$stale" in
  *firstsurvey_chapter4*) pass "stale declaration 列出未使用声明" ;;
  *) bad "stale declaration 未捕获：[$stale]" ;;
esac

report=$(contract_data_report "$WORKDIR/partial.do")
case "$report" in
  *missing_declaration:firstsurvey_chapter4*) pass "report：missing_declaration" ;;
  *) bad "report 缺 missing_declaration：[$report]" ;;
esac

report=$(contract_data_report "$WORKDIR/stale.do")
case "$report" in
  *stale_declaration:firstsurvey_chapter4*) pass "report：stale_declaration" ;;
  *) bad "report 缺 stale_declaration：[$report]" ;;
esac

# missing_file / unlisted / ambiguous 经 data_locate fixture 布局
export CONTRACT_REPO_ROOT="$WORKDIR/loc"
mkdir -p "$CONTRACT_REPO_ROOT/data/agis6"
printf 'relate\n' >"$CONTRACT_REPO_ROOT/data/manifest.txt"
: >"$CONTRACT_REPO_ROOT/data/manifest-extra.txt"
: >"$CONTRACT_REPO_ROOT/data/agis6/relate.dta"
write_do "$WORKDIR/missing-file.do" \
  'version 19.5' \
  '* ==== VERIFY CONTRACT ====' \
  '* skill:    stata-basics' \
  '* chapter:  ch1' \
  '* data:     ghost_xyz.dta' \
  '* checks:   use' \
  '* ============================' \
  'use ghost_xyz, clear'
report=$(contract_data_report "$WORKDIR/missing-file.do")
case "$report" in
  *missing_file:ghost_xyz*) pass "report：missing_file" ;;
  *) bad "report 缺 missing_file：[$report]" ;;
esac

: >"$CONTRACT_REPO_ROOT/data/agis6/orphan_only.dta"
write_do "$WORKDIR/unlisted.do" \
  'version 19.5' \
  '* ==== VERIFY CONTRACT ====' \
  '* skill:    stata-basics' \
  '* chapter:  ch1' \
  '* data:     orphan_only.dta' \
  '* checks:   use' \
  '* ============================' \
  'use orphan_only, clear'
report=$(contract_data_report "$WORKDIR/unlisted.do")
case "$report" in
  *unlisted_file:orphan_only*) pass "report：unlisted_file" ;;
  *) bad "report 缺 unlisted_file：[$report]" ;;
esac

printf 'dup_base\ndup_base\n' >"$CONTRACT_REPO_ROOT/data/manifest.txt"
: >"$CONTRACT_REPO_ROOT/data/agis6/dup_base.dta"
write_do "$WORKDIR/dup.do" \
  'version 19.5' \
  '* ==== VERIFY CONTRACT ====' \
  '* skill:    stata-basics' \
  '* chapter:  ch1' \
  '* data:     dup_base.dta' \
  '* checks:   use' \
  '* ============================' \
  'use dup_base, clear'
report=$(contract_data_report "$WORKDIR/dup.do")
case "$report" in
  *ambiguous_basename:dup_base*) pass "report：ambiguous_basename" ;;
  *) bad "report 缺 ambiguous_basename：[$report]" ;;
esac
unset CONTRACT_REPO_ROOT

# ---- 9. 生产 verify-*.do 穷尽 report 为空；caller 无平行 use 解析 ----
prod_bad=0
for vdo in "$REPO_ROOT"/verify/verify-*.do; do
  [ -f "$vdo" ] || continue
  report=$(contract_data_report "$vdo")
  if [ -n "$report" ]; then
    bad "生产 $(basename "$vdo") 穷尽 report 非空：$(printf '%s' "$report" | tr '\n' ' ')"
    prod_bad=1
  fi
done
[ "$prod_bad" -eq 0 ] && pass "生产 verify-*.do 穷尽 data contract 全部干净"

if grep -nE 'grep -oE .*\^use|awk.*print \$2' "$VERIFY_DIR/run-verify.sh" >/dev/null 2>&1; then
  bad "run-verify.sh 仍保留平行 use 路径解析（#25）"
else
  pass "run-verify.sh 已收缩到 contract_data_report"
fi
if grep -nE 'contract_data_report' "$VERIFY_DIR/check-claims.sh" >/dev/null 2>&1; then
  pass "check-claims.sh 经 contract_data_report 做穷尽校验"
else
  bad "check-claims.sh 未调用 contract_data_report（#25）"
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "结果：全部通过"
  exit 0
fi
echo "结果：${fail} 失败"
exit 1
