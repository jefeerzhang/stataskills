#!/usr/bin/env bash
# ============================================================
# 回归测试：验证 harness 的判定逻辑本身。
#
# 探针 do-file 覆盖普通错误、纯 sentinel、sentinel + 真实错误三种情况。
# 回归背景：错误码匹配曾用 r\([0-9]{2,}\)（至少 2 位），
# 个位数错误码 r(9)（assert 失败）等会被漏判为 PASS。
#
# 用法：bash verify/test-harness.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
PROBE="$VERIFY_DIR/verify-zzprobe.do"
PROBE_LOG="$VERIFY_DIR/verify-zzprobe.log"

cleanup() { rm -f "$PROBE" "$PROBE_LOG"; }
trap cleanup EXIT

printf 'version 19.5\nsysuse auto, clear\nassert mpg == 0\n' > "$PROBE"

if bash "$VERIFY_DIR/run-verify.sh" zzprobe >/dev/null 2>&1; then
  echo "FAIL  harness 探针：含 r(9) 错误的 do-file 被判为 PASS（假阳性）"
  exit 1
fi
echo "PASS  harness 探针：含 r(9) 错误的 do-file 被正确判为 FAIL"

printf 'version 19.5\ndisplay "__COMMUNITY_PACKAGE_MISSING__probe__"\n' > "$PROBE"
if ! bash "$VERIFY_DIR/run-verify.sh" zzprobe >/dev/null 2>&1; then
  echo "FAIL  harness 探针：纯缺包 sentinel 在默认模式下未 PASS"
  exit 1
fi
if bash "$VERIFY_DIR/run-verify.sh" zzprobe --community >/dev/null 2>&1; then
  echo "FAIL  harness 探针：纯缺包 sentinel 在 --community 模式下未 FAIL"
  exit 1
fi
echo "PASS  harness 探针：必需包 sentinel 的默认/--community 语义正确"

for package in ebalance psmatch2; do
  printf 'version 19.5\ndisplay "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__%s__"\n' "$package" > "$PROBE"
  if ! bash "$VERIFY_DIR/run-verify.sh" zzprobe >/dev/null 2>&1; then
    echo "FAIL  harness 探针：纯 ${package} optional sentinel 在默认模式下未 PASS"
    exit 1
  fi
  if ! bash "$VERIFY_DIR/run-verify.sh" zzprobe --community >/dev/null 2>&1; then
    echo "FAIL  harness 探针：纯 ${package} optional sentinel 在 --community 模式下未 PASS"
    exit 1
  fi
  echo "PASS  harness 探针：纯 ${package} optional sentinel 在默认/--community 两模式均 PASS"
done

printf 'version 19.5\ndisplay "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__psmatch2__"\nerror 1\n' > "$PROBE"
for mode in default community; do
  args=()
  [ "$mode" = community ] && args+=(--community)
  if bash "$VERIFY_DIR/run-verify.sh" zzprobe "${args[@]}" >/dev/null 2>&1; then
    echo "FAIL  harness 探针：${mode} 模式下 optional sentinel 掩盖了真实 r(1) 错误"
    exit 1
  fi
done
echo "PASS  harness 探针：optional sentinel 在默认/--community 两模式均不掩盖真实 r(1) 错误"
