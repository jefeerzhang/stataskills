#!/usr/bin/env bash
# ============================================================
# 回归：community-package contract（verify/lib/community.sh）
#
# Issue #26：先红后绿捕获 center / ivreg2 / weakivtest 漏检；
# 校验 missing probe、wrong sentinel、ownership 漂移。
#
# 用法：bash verify/test-community.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$VERIFY_DIR/.." && pwd)"

fail=0
pass() { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; fail=$((fail + 1)); }

# shellcheck disable=SC1091
if ! . "$VERIFY_DIR/lib/community.sh" 2>/dev/null; then
  bad "无法 source verify/lib/community.sh"
  echo "结果：${fail} 失败"
  exit 1
fi

for fn in community_registry_each community_class_for community_unique_pkgs \
          community_check_dofile community_owners_for; do
  if ! declare -F "$fn" >/dev/null 2>&1; then
    bad "缺少函数 $fn（#26 community contract）"
  fi
done
[ "$fail" -gt 0 ] && { echo "结果：${fail} 失败"; exit 1; }

# ---- 1. 漏检包必须在 registry（red-capable：缺则失败）----
for pkg in center ivreg2 weakivtest; do
  if community_unique_pkgs | grep -qx "$pkg"; then
    pass "registry 含漏检修复包：$pkg"
  else
    bad "registry 缺 $pkg（#26 要求先捕获再修复）"
  fi
done

# ---- 2. class 交叉：center=optional @ coefplot；ivreg2/weakivtest=required @ regression ----
c=$(community_class_for center verify-coefplot || true)
[ "$c" = "optional" ] && pass "center @ coefplot → optional" || bad "center class=$c"
c=$(community_class_for ivreg2 verify-regression || true)
[ "$c" = "required" ] && pass "ivreg2 @ regression → required" || bad "ivreg2 class=$c"
c=$(community_class_for weakivtest verify-regression || true)
[ "$c" = "required" ] && pass "weakivtest @ regression → required" || bad "weakivtest class=$c"

# ---- 3. fixture：missing probe ----
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/stataskills-community.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

printf '%s\n' \
  'version 19.5' \
  'center price, inplace' \
  >"$WORKDIR/verify-coefplot.do"
# 临时缩小 registry 视角：直接调 check 会用真实 registry（center 已登记）
# → 应报 missing_probe
rep=$(community_check_dofile "$WORKDIR/verify-coefplot.do")
case "$rep" in
  *missing_probe:center*) pass "fixture：missing_probe 捕获 center 无探测" ;;
  *) bad "fixture missing_probe 失败：[$rep]" ;;
esac

# ---- 4. fixture：wrong sentinel（required 包打 optional sentinel）----
printf '%s\n' \
  'version 19.5' \
  'cap which ivreg2' \
  'if _rc {' \
  '    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ivreg2__"' \
  '}' \
  'ivreg2 y (x = z)' \
  >"$WORKDIR/verify-regression.do"
rep=$(community_check_dofile "$WORKDIR/verify-regression.do")
case "$rep" in
  *wrong_sentinel:ivreg2*) pass "fixture：wrong_sentinel 捕获 class 漂移" ;;
  *) bad "fixture wrong_sentinel 失败：[$rep]" ;;
esac

# ---- 5. fixture：ownership drift（在错误 owner 调用）----
printf '%s\n' \
  'version 19.5' \
  'cap which center' \
  'display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__center__"' \
  'center price, inplace' \
  >"$WORKDIR/verify-basics.do"
rep=$(community_check_dofile "$WORKDIR/verify-basics.do")
case "$rep" in
  *ownership_drift:center*) pass "fixture：ownership_drift 捕获错主" ;;
  *) bad "fixture ownership_drift 失败：[$rep]" ;;
esac

# ---- 6. 生产 verify-*.do 全绿；judge 无第二份名单 ----
prod_bad=0
for vdo in "$REPO_ROOT"/verify/verify-*.do; do
  [ -f "$vdo" ] || continue
  rep=$(community_check_dofile "$vdo")
  if [ -n "$rep" ]; then
    bad "生产 $(basename "$vdo") community contract：$(printf '%s' "$rep" | tr '\n' ' ')"
    prod_bad=1
  fi
done
[ "$prod_bad" -eq 0 ] && pass "生产 verify-*.do community contract 全部干净"

if grep -nE 'COMMUNITY_PKGS=|csdid.*jwdid.*did_imputation' "$VERIFY_DIR/lib/judge.sh" >/dev/null 2>&1; then
  bad "judge.sh 承载了第二份 package registry"
else
  pass "judge.sh 不承载 package registry（只解释 log sentinel）"
fi

if grep -nE 'community_check_dofile|lib/community.sh' "$VERIFY_DIR/check-claims.sh" >/dev/null 2>&1; then
  pass "check-claims 经 community contract seam"
else
  bad "check-claims 未接入 community.sh（#26）"
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "结果：全部通过"
  exit 0
fi
echo "结果：${fail} 失败"
exit 1
