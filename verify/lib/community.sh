#!/usr/bin/env bash
# ============================================================
# Community-package contract（#26 / ADR-0003）
#
# 单一来源：每个 (package, owner do-file) 的 required/optional 分类。
# claims 经此 seam 交叉验证：调用 ↔ 前置 probe ↔ sentinel 分类 ↔ ownership。
# judge.sh 只解释日志里观察到的 sentinel，不承载第二份 package 名单。
#
# 登记格式（空格分隔字段）：pkg owner_base class
#   class = required | optional
# ============================================================

# shellcheck disable=SC2034
_COMMUNITY_REGISTRY=$(cat <<'EOF'
avar verify-regression required
center verify-coefplot optional
coefplot verify-coefplot required
csdid verify-synth-sdid required
did_had verify-synth-sdid optional
did_imputation verify-synth-sdid required
drdid verify-synth-sdid optional
ebalance verify-selection optional
ftools verify-regression required
hdfe verify-synth-sdid optional
ivreg2 verify-regression required
ivreghdfe verify-regression required
jwdid verify-synth-sdid required
lpdensity verify-rdd optional
nprobust verify-trop required
psmatch2 verify-selection optional
ranktest verify-regression required
rdrobust verify-rdd required
rddensity verify-rdd required
reghdfe verify-power optional
reghdfe verify-regression required
reghdfe verify-synth-sdid optional
require verify-regression required
sdid verify-synth-sdid required
synth verify-synth-sdid required
synth_runner verify-synth-sdid optional
trop verify-trop required
weakivtest verify-regression required
EOF
)

# community_registry_each：每行 "pkg owner class"
community_registry_each() {
  printf '%s\n' "$_COMMUNITY_REGISTRY"
}

# community_class_for <pkg> <owner_base> → required|optional；未登记则空
community_class_for() {
  local pkg="$1" owner="$2" p o c
  while IFS=' ' read -r p o c; do
    [ -z "${p:-}" ] && continue
    if [ "$p" = "$pkg" ] && [ "$o" = "$owner" ]; then
      printf '%s\n' "$c"
      return 0
    fi
  done <<EOF
$_COMMUNITY_REGISTRY
EOF
  return 1
}

# community_owners_for <pkg>：空格分隔 owner 列表
community_owners_for() {
  local pkg="$1" p o c out=""
  while IFS=' ' read -r p o c; do
    [ -z "${p:-}" ] && continue
    [ "$p" = "$pkg" ] || continue
    case " $out " in
      *" $o "*) ;;
      *) out="${out:+$out }$o" ;;
    esac
  done <<EOF
$_COMMUNITY_REGISTRY
EOF
  printf '%s\n' "$out"
}

# community_unique_pkgs：有序唯一包名
community_unique_pkgs() {
  printf '%s\n' "$_COMMUNITY_REGISTRY" | awk 'NF{print $1}' | sort -u
}

# 首次「可执行调用」行号（排除 which 探测与注释）
_community_call_line() {
  local dofile="$1" pkg="$2"
  grep -nE "^[[:space:]]*(capture[[:space:]]+noisily[[:space:]]+|quietly[[:space:]]+)*${pkg}([[:space:]]|$)" "$dofile" \
    | grep -vE "^[0-9]+:[[:space:]]*(capture|cap)[[:space:]]+which[[:space:]]+" \
    | head -1 | cut -d: -f1
}

_community_probe_line() {
  local dofile="$1" pkg="$2"
  grep -nE "^[[:space:]]*(capture|cap)[[:space:]]+which[[:space:]]+${pkg}([[:space:]]|$)" "$dofile" \
    | head -1 | cut -d: -f1
}

# 文件内 sentinel 分类：required / optional / both / none
_community_sentinel_class() {
  local dofile="$1" pkg="$2"
  local has_req=0 has_opt=0
  grep -qE "__COMMUNITY_PACKAGE_MISSING__${pkg}__" "$dofile" && has_req=1
  grep -qE "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__${pkg}__" "$dofile" && has_opt=1
  if [ "$has_req" -eq 1 ] && [ "$has_opt" -eq 1 ]; then
    printf 'both\n'
  elif [ "$has_req" -eq 1 ]; then
    printf 'required\n'
  elif [ "$has_opt" -eq 1 ]; then
    printf 'optional\n'
  else
    printf 'none\n'
  fi
}

# community_check_dofile <dofile>
# 每行 KIND:detail；干净则无输出。
# KIND ∈ missing_probe|late_probe|undeclared_call|wrong_sentinel|ownership_drift
community_check_dofile() {
  local dofile="$1"
  local owner pkg call_ln probe_ln expect_class sent_class owners
  owner="$(basename "$dofile" .do)"

  # 1) 登记项：每个声明包必须有前置 probe；sentinel 与 class 一致
  while IFS=' ' read -r pkg o c; do
    [ -z "${pkg:-}" ] && continue
    [ "$o" = "$owner" ] || continue
    call_ln="$(_community_call_line "$dofile" "$pkg")"
    probe_ln="$(_community_probe_line "$dofile" "$pkg")"
    if [ -z "$probe_ln" ]; then
      printf 'missing_probe:%s@%s\n' "$pkg" "$owner"
    elif [ -n "$call_ln" ] && [ "$probe_ln" -gt "$call_ln" ]; then
      printf 'late_probe:%s@%s probe=%s call=%s\n' "$pkg" "$owner" "$probe_ln" "$call_ln"
    fi
    sent_class="$(_community_sentinel_class "$dofile" "$pkg")"
    case "$sent_class" in
      "$c") ;;
      none)
        printf 'wrong_sentinel:%s@%s expect=%s got=none\n' "$pkg" "$owner" "$c"
        ;;
      both)
        printf 'wrong_sentinel:%s@%s expect=%s got=both\n' "$pkg" "$owner" "$c"
        ;;
      *)
        printf 'wrong_sentinel:%s@%s expect=%s got=%s\n' "$pkg" "$owner" "$c" "$sent_class"
        ;;
    esac
  done <<EOF
$_COMMUNITY_REGISTRY
EOF

  # 2) 文件内实际调用的社区包命令：必须落在本 owner 的登记上
  #    （用 registry 全包名单扫描，避免第二份硬编码）
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    call_ln="$(_community_call_line "$dofile" "$pkg")"
    [ -z "$call_ln" ] && continue
    expect_class="$(community_class_for "$pkg" "$owner" 2>/dev/null || true)"
    if [ -z "$expect_class" ]; then
      owners="$(community_owners_for "$pkg")"
      if [ -n "$owners" ]; then
        printf 'ownership_drift:%s call_in=%s registry_owners=%s\n' "$pkg" "$owner" "$owners"
      else
        printf 'undeclared_call:%s@%s call=%s\n' "$pkg" "$owner" "$call_ln"
      fi
    fi
  done < <(community_unique_pkgs)
}
