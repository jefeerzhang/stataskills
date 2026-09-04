#!/usr/bin/env bash
# ============================================================
# VERIFY CONTRACT + data locator（#21 / parent #18）
#
# 统一解析 verify-*.do 头部契约，并把 data 声明/字面 use 读入规范化为
# facts。data_locate 保留三类仓库数据治理差异（ADR-0003 / ADR-0006）：
#   agis6     —— data/manifest.txt + data/agis6/
#   external  —— manifest-extra + data/<subdir>/ 且含 download_*.sh
#   generated —— manifest-extra + data/<subdir>/ 且含 build*.do
# 非仓库：sysuse: / sim:
#
# CONTRACT_REPO_ROOT 可覆盖仓库根（供 test-contract 造假布局）。
# 旧 check_data_ready / check-claims 字段校验可继续独立工作；本 module
# 为 deep contract seam，#25 再迁移穷尽检查进生产断言。
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
  local dofile="$1" line path rest subdir base
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '#'*|'*'*) continue ;;
    esac
    # 仅匹配行首 use（可有前导空白）
    if ! echo "$line" | grep -qE '^[[:space:]]*use[[:space:]]+'; then
      continue
    fi
    path=$(echo "$line" | sed -E 's/^[[:space:]]*use[[:space:]]+//; s/["'\'']//g; s/,.*//; s/[[:space:]].*//;')
    [ -z "$path" ] && continue
    case "$path" in
      ../*)
        rest="${path#../}"
        # rest = subdir/file[.dta]
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
_contract_declared_covers() {
  local needle="$1" decl nbase dbase
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
    # 路径形式 data/subdir/file.dta
    if [ "$decl" = "$needle" ] || [ "${decl#data/}" = "$needle" ] || [ "data/$needle" = "$decl" ]; then
      return 0
    fi
  done
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
    if ! _contract_declared_covers "$lit" <"$decl_file"; then
      gaps="${gaps:+$gaps }$lit"
    fi
  done < <(contract_literal_repo_reads "$dofile")
  rm -f "$decl_file"
  printf '%s\n' "$gaps"
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
  while IFS= read -r line || [ -n "$line" ]; do
    [ "$line" = "$base" ] && n=$((n + 1))
  done < <(_contract_manifest_lines "$file")
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
