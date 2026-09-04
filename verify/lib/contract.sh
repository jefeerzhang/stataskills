#!/usr/bin/env bash
# ============================================================
# VERIFY CONTRACT + data locator（#21 / #25 / parent #18）
#
# 统一解析 verify-*.do 头部契约，并把 data 声明/字面 use 读入规范化为
# facts。data_locate 保留三类仓库数据治理差异（ADR-0003 / ADR-0006）：
#   agis6     —— data/manifest.txt + data/agis6/
#   external  —— manifest-extra + data/<subdir>/ 且含 download_*.sh
#   generated —— manifest-extra + data/<subdir>/ 且含 build*.do
# 非仓库：sysuse: / sim:
#
# #25：穷尽 data contract —— contract_data_report 报告
#   missing_declaration / stale_declaration / missing_file /
#   unlisted_file / ambiguous_basename；runner 与 claims 只经此 seam。
#
# CONTRACT_REPO_ROOT 可覆盖仓库根（供 test-contract 造假布局）。
# ============================================================

_contract_root() {
  printf '%s\n' "${CONTRACT_REPO_ROOT:-}"
}

# 若未设 CONTRACT_REPO_ROOT，从本文件位置推仓库根。
_contract_default_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s\n' "$here"
}

_contract_repo() {
  local r
  r="$(_contract_root)"
  if [ -n "$r" ]; then
    printf '%s\n' "$r"
  else
    _contract_default_root
  fi
}

# contract_parse <dofile>
# 向 stdout 打印可 eval 的 KEY=value：
#   CONTRACT_SKILL / CONTRACT_CHAPTER / CONTRACT_DATA / CONTRACT_CHECKS
contract_parse() {
  local dofile="$1"
  local block skill chapter data checks
  block=$(head -20 "$dofile" | sed -n '/^\* ==== VERIFY CONTRACT ====$/,/^\* ============================$/p')
  skill=$(echo "$block" | sed -n 's/^\* skill:[[:space:]]*//p' | head -1 | tr -d '[:space:]')
  chapter=$(echo "$block" | sed -n 's/^\* chapter:[[:space:]]*//p' | head -1 | tr -d '[:space:]')
  data=$(echo "$block" | sed -n 's/^\* data:[[:space:]]*//p' | head -1 | tr -d '[:space:]')
  checks=$(echo "$block" | sed -n 's/^\* checks:[[:space:]]*//p' | head -1 | tr -d '[:space:]')
  printf "CONTRACT_SKILL=%q\n" "$skill"
  printf "CONTRACT_CHAPTER=%q\n" "$chapter"
  printf "CONTRACT_DATA=%q\n" "$data"
  printf "CONTRACT_CHECKS=%q\n" "$checks"
}

# contract_data_declared <dofile>：每行一个声明项（保留 .dta / 前缀）
contract_data_declared() {
  local dofile="$1" data
  # shellcheck disable=SC2034
  eval "$(contract_parse "$dofile")"
  data="${CONTRACT_DATA:-}"
  [ -z "$data" ] && return 0
  local IFS=';'
  # shellcheck disable=SC2086
  set -- $data
  local item
  for item in "$@"; do
    [ -n "$item" ] && printf '%s\n' "$item"
  done
}

# 规范化仓库数据集 token → 可比对的基名（去路径、去 .dta）
_contract_basename() {
  local t="$1"
  t="${t%.dta}"
  t="${t##*/}"
  printf '%s\n' "$t"
}

# contract_literal_repo_reads <dofile>
# 提取字面仓库数据读取（use …），每行一个可比对基名或 relative path token。
# 跳过 sysuse / webuse / 注释行；`../subdir/file` 保留 subdir/file.dta 形式。
contract_literal_repo_reads() {
  local dofile="$1" line trimmed path rest base
  while IFS= read -r line || [ -n "$line" ]; do
    # 内联 ltrim：避免 Windows 上每行一次函数调用开销
    trimmed="${line#"${line%%[![:space:]]*}"}"
    case "$trimmed" in
      ''|'#'*|'*'*|'//'*) continue ;;
    esac
    # bash case 的 * 不跨非空白；用 [[ =~ ]] 锚定 use 命令
    if [[ ! "$trimmed" =~ ^use[[:space:]]+ ]]; then
      continue
    fi
    path="${trimmed#use}"
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%%,*}"
    path="${path%%[[:space:]]*}"
    path="${path//\"/}"
    path="${path//\'/}"
    [ -z "$path" ] && continue
    case "$path" in
      ../*)
        rest="${path#../}"
        printf '%s\n' "${rest%.dta}.dta"
        ;;
      /*|./*) ;; # 忽略绝对/奇怪路径
      *)
        base="${path%.dta}"
        printf '%s\n' "${base}.dta"
        ;;
    esac
  done <"$dofile"
}

# 声明集合是否覆盖某 literal token（基名或路径）
# 用法：_contract_declared_covers <needle> <decl_file>
_contract_declared_covers() {
  local needle="$1" decl_file="$2" decl nbase dbase
  nbase="$(_contract_basename "$needle")"
  while IFS= read -r decl || [ -n "$decl" ]; do
    [ -z "$decl" ] && continue
    case "$decl" in
      sysuse:*|sim:*) continue ;;
    esac
    dbase="$(_contract_basename "$decl")"
    if [ "$dbase" = "$nbase" ]; then
      return 0
    fi
    if [ "$decl" = "$needle" ] || [ "${decl#data/}" = "$needle" ] || [ "data/$needle" = "$decl" ]; then
      return 0
    fi
  done <"$decl_file"
  return 1
}

# 字面 read 集合是否覆盖某声明 token
# 用法：_contract_literal_covers <decl> <lit_file>
_contract_literal_covers() {
  local decl="$1" lit_file="$2" lit dbase lbase
  case "$decl" in
    sysuse:*|sim:*) return 0 ;; # 非仓库：不参与 stale
  esac
  dbase="$(_contract_basename "$decl")"
  while IFS= read -r lit || [ -n "$lit" ]; do
    [ -z "$lit" ] && continue
    lbase="$(_contract_basename "$lit")"
    if [ "$lbase" = "$dbase" ]; then
      return 0
    fi
    if [ "$decl" = "$lit" ] || [ "${decl#data/}" = "$lit" ] || [ "data/$lit" = "$decl" ]; then
      return 0
    fi
  done <"$lit_file"
  return 1
}

# contract_exhaustive_gaps <dofile>
# 列出「字面仓库 read 未出现在 data: 声明」的项（空格分隔一行）；完整则空。
contract_exhaustive_gaps() {
  local dofile="$1" gaps="" lit
  local decl_file
  decl_file="$(mktemp)"
  contract_data_declared "$dofile" >"$decl_file"
  while IFS= read -r lit || [ -n "$lit" ]; do
    [ -z "$lit" ] && continue
    if ! _contract_declared_covers "$lit" "$decl_file"; then
      gaps="${gaps:+$gaps }$lit"
    fi
  done < <(contract_literal_repo_reads "$dofile")
  rm -f "$decl_file"
  printf '%s\n' "$gaps"
}

# contract_stale_declarations <dofile>
# 列出「仓库声明未出现在任何字面 use」的项（空格分隔一行）；无 stale 则空。
contract_stale_declarations() {
  local dofile="$1" stale="" decl
  local lit_file
  lit_file="$(mktemp)"
  contract_literal_repo_reads "$dofile" >"$lit_file"
  while IFS= read -r decl || [ -n "$decl" ]; do
    [ -z "$decl" ] && continue
    case "$decl" in
      sysuse:*|sim:*) continue ;;
    esac
    if ! _contract_literal_covers "$decl" "$lit_file"; then
      stale="${stale:+$stale }$decl"
    fi
  done < <(contract_data_declared "$dofile")
  rm -f "$lit_file"
  printf '%s\n' "$stale"
}

# manifest 行：去空白、去 CR
_contract_manifest_lines() {
  local file="$1"
  [ -f "$file" ] || return 0
  # shellcheck disable=SC2001
  sed 's/\r$//' "$file" | sed 's/[[:space:]]*$//' | grep -vE '^[[:space:]]*(#|$)' || true
}

_contract_manifest_count() {
  local file="$1" base="$2" n=0 line
  [ -f "$file" ] || { printf '0\n'; return 0; }
  # 单次 sed，避免双重管道
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="${line%"${line##*[![:space:]]}"}"
    case "$line" in
      ''|'#'*) continue ;;
    esac
    [ "$line" = "$base" ] && n=$((n + 1))
  done <"$file"
  printf '%s\n' "$n"
}

# data_locate <spec>
# 打印可 eval 的：
#   DATA_KIND=agis6|external|generated|sysuse|sim|missing|unlisted|duplicate
#   DATA_PATH=...
#   DATA_BASENAME=...
#   DATA_LISTED=0|1
#   DATA_DUPLICATE=0|1
data_locate() {
  local spec="$1"
  local root kind path base listed=0 dup=0
  root="$(_contract_repo)"
  kind=""
  path=""
  base=""

  case "$spec" in
    sysuse:*)
      printf "DATA_KIND=%q\n" "sysuse"
      printf "DATA_PATH=%q\n" ""
      printf "DATA_BASENAME=%q\n" "${spec#sysuse:}"
      printf "DATA_LISTED=%q\n" "0"
      printf "DATA_DUPLICATE=%q\n" "0"
      return 0
      ;;
    sim:*)
      printf "DATA_KIND=%q\n" "sim"
      printf "DATA_PATH=%q\n" ""
      printf "DATA_BASENAME=%q\n" "${spec#sim:}"
      printf "DATA_LISTED=%q\n" "0"
      printf "DATA_DUPLICATE=%q\n" "0"
      return 0
      ;;
  esac

  # 规范化路径/基名
  local rel="$spec"
  rel="${rel#./}"
  case "$rel" in
    data/agis6/*)
      base="$(_contract_basename "$rel")"
      path="$root/data/agis6/${base}.dta"
      ;;
    data/*/*)
      # data/<subdir>/<file>
      local rest subdir
      rest="${rel#data/}"
      subdir="${rest%%/*}"
      base="$(_contract_basename "$rest")"
      path="$root/data/${subdir}/${base}.dta"
      ;;
    */*)
      # subdir/file.dta（无 data/ 前缀）
      subdir="${rel%%/*}"
      base="$(_contract_basename "$rel")"
      path="$root/data/${subdir}/${base}.dta"
      ;;
    *)
      base="$(_contract_basename "$rel")"
      path="$root/data/agis6/${base}.dta"
      ;;
  esac

  local man="$root/data/manifest.txt"
  local man_x="$root/data/manifest-extra.txt"
  local cnt

  # 优先看是否落在额外子目录
  if [[ "$path" == *"/data/agis6/"* ]]; then
    cnt="$(_contract_manifest_count "$man" "$base")"
    if [ ! -f "$path" ]; then
      kind="missing"
      listed=0
    elif [ "$cnt" -gt 1 ]; then
      kind="duplicate"
      listed=1
      dup=1
    elif [ "$cnt" -eq 1 ]; then
      kind="agis6"
      listed=1
    else
      kind="unlisted"
      listed=0
    fi
  else
    # extra 子目录
    local subdir
    subdir=$(echo "$path" | sed -n "s|^$root/data/\([^/]*\)/.*|\1|p")
    cnt="$(_contract_manifest_count "$man_x" "$base")"
    if [ ! -f "$path" ]; then
      kind="missing"
      listed=0
    elif [ "$cnt" -gt 1 ]; then
      kind="duplicate"
      listed=1
      dup=1
    elif [ "$cnt" -eq 0 ]; then
      kind="unlisted"
      listed=0
    else
      listed=1
      if compgen -G "$root/data/${subdir}/download_*.sh" >/dev/null 2>&1; then
        kind="external"
      elif compgen -G "$root/data/${subdir}/build*.do" >/dev/null 2>&1; then
        kind="generated"
      else
        # 有登记但治理脚本形态未知——仍算 external 扩展面
        kind="external"
      fi
    fi
  fi

  printf "DATA_KIND=%q\n" "$kind"
  printf "DATA_PATH=%q\n" "$path"
  printf "DATA_BASENAME=%q\n" "$base"
  printf "DATA_LISTED=%q\n" "$listed"
  printf "DATA_DUPLICATE=%q\n" "$dup"
}

# contract_data_report <dofile>
# 每行 KIND:TOKEN —— KIND ∈ missing_declaration|stale_declaration|
# missing_file|unlisted_file|ambiguous_basename。干净则无输出。
# 单次扫描声明/字面集合，避免重复 mktemp + 进程替换（Windows 易卡住）。
contract_data_report() {
  local dofile="$1"
  local decl_file lit_file seen_file
  local item b
  decl_file="$(mktemp "${TMPDIR:-/tmp}/contract-decl.XXXXXX")"
  lit_file="$(mktemp "${TMPDIR:-/tmp}/contract-lit.XXXXXX")"
  seen_file="$(mktemp "${TMPDIR:-/tmp}/contract-seen.XXXXXX")"
  contract_data_declared "$dofile" >"$decl_file"
  contract_literal_repo_reads "$dofile" >"$lit_file"

  while IFS= read -r item || [ -n "$item" ]; do
    [ -z "$item" ] && continue
    if ! _contract_declared_covers "$item" "$decl_file"; then
      printf 'missing_declaration:%s\n' "$item"
    fi
  done <"$lit_file"

  while IFS= read -r item || [ -n "$item" ]; do
    [ -z "$item" ] && continue
    case "$item" in
      sysuse:*|sim:*) continue ;;
    esac
    if ! _contract_literal_covers "$item" "$lit_file"; then
      printf 'stale_declaration:%s\n' "$item"
    fi
  done <"$decl_file"

  # 对声明 ∪ 字面仓库 token 做 locate（同一基名只报一次）
  local union_file
  union_file="$(mktemp "${TMPDIR:-/tmp}/contract-union.XXXXXX")"
  cat "$decl_file" "$lit_file" >"$union_file"
  while IFS= read -r item || [ -n "$item" ]; do
    [ -z "$item" ] && continue
    case "$item" in
      sysuse:*|sim:*) continue ;;
    esac
    b="$(_contract_basename "$item")"
    if grep -qxF "$b" "$seen_file" 2>/dev/null; then
      continue
    fi
    printf '%s\n' "$b" >>"$seen_file"
    # shellcheck disable=SC2034
    eval "$(data_locate "$item")"
    case "${DATA_KIND:-}" in
      missing)
        printf 'missing_file:%s\n' "$item"
        ;;
      unlisted)
        printf 'unlisted_file:%s\n' "$item"
        ;;
      duplicate)
        printf 'ambiguous_basename:%s\n' "$item"
        ;;
    esac
  done <"$union_file"

  rm -f "$decl_file" "$lit_file" "$seen_file" "$union_file"
}
