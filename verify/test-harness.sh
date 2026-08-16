#!/usr/bin/env bash
# ============================================================
# 回归测试：验证 harness 的判定逻辑本身。
#
# 探针 do-file 故意触发 Stata 错误，断言 run-verify.sh 必须报 FAIL。
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
