#!/usr/bin/env bash
# ============================================================
# 回归测试：验证 harness 的**日志判定逻辑**（verify/lib/judge.sh）。
#
# 旧版探针把"run-verify.sh 非零退出"一概当作"捕获了 r(9)"，导致在
# Linux 上（run-verify.sh 不认平台即 exit 1 / 无 Stata 无法批处理）
# 时误判为 PASS——CI 又不跑本 harness，于是 GitHub 上完全看不见。
# 本版改为**直接构造真实形制的 Stata 批处理日志、喂给判定层断言**，
# 不依赖真实 Stata 或特定平台，CI（ubuntu-latest 无 Stata）即可可靠运行，
# 让假阳性在 GitHub 上可见。
#
# 探针覆盖：普通 r(9) 错误、纯必需包 sentinel、纯可选包 sentinel、
#          optional sentinel 掩盖真实 r(1) 错误。
#
# 用法：bash verify/test-harness.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/judge.sh"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/stataskills-harness.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# 探针 1：含 r(9) 错误的日志必须判 FAIL（回归锚点：个位数错误码不被漏判）
cat > "$WORKDIR/r9.log" <<'EOF'
. sysuse auto, clear
(1978 automobile data)
. assert mpg == 0
assert mpg == 0 contains an invalid value
r(9);
EOF
if judge_raw_log zzprobe "$WORKDIR/r9.log" 0 >/dev/null 2>&1; then
  echo "FAIL  探针：含 r(9) 错误的日志被判为 PASS（假阳性）"
  exit 1
fi
echo "PASS  探针：含 r(9) 错误的日志被正确判为 FAIL"

# 探针 2：纯必需包 sentinel —— 默认模式 PASS，--community 模式 FAIL
cat > "$WORKDIR/reqmiss.log" <<'EOF'
. display "__COMMUNITY_PACKAGE_MISSING__probe__"
__COMMUNITY_PACKAGE_MISSING__probe__
end of do-file
EOF
if ! judge_raw_log zzprobe "$WORKDIR/reqmiss.log" 0 >/dev/null 2>&1; then
  echo "FAIL  探针：纯缺必需包 sentinel 在默认模式下未 PASS"
  exit 1
fi
if judge_raw_log zzprobe "$WORKDIR/reqmiss.log" 1 >/dev/null 2>&1; then
  echo "FAIL  探针：纯缺必需包 sentinel 在 --community 模式下未 FAIL"
  exit 1
fi
echo "PASS  探针：必需包 sentinel 的默认/--community 语义正确"

# 探针 3：纯可选包 sentinel —— 默认/--community 两模式均 PASS
for package in ebalance psmatch2; do
  cat > "$WORKDIR/optmiss.log" <<EOF
. display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__${package}__"
__COMMUNITY_PACKAGE_OPTIONAL_MISSING__${package}__
end of do-file
EOF
  if ! judge_raw_log zzprobe "$WORKDIR/optmiss.log" 0 >/dev/null 2>&1; then
    echo "FAIL  探针：纯 ${package} optional sentinel 在默认模式下未 PASS"
    exit 1
  fi
  if ! judge_raw_log zzprobe "$WORKDIR/optmiss.log" 1 >/dev/null 2>&1; then
    echo "FAIL  探针：纯 ${package} optional sentinel 在 --community 模式下未 PASS"
    exit 1
  fi
  echo "PASS  探针：纯 ${package} optional sentinel 在默认/--community 两模式均 PASS"
done

# 探针 4：optional sentinel 不得掩盖真实 r(1) 错误 —— 两模式均 FAIL
cat > "$WORKDIR/opt_r1.log" <<'EOF'
. display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__psmatch2__"
__COMMUNITY_PACKAGE_OPTIONAL_MISSING__psmatch2__
. error 1
r(1);
EOF
for mode in 0 1; do
  if judge_raw_log zzprobe "$WORKDIR/opt_r1.log" "$mode" >/dev/null 2>&1; then
    echo "FAIL  探针：${mode} 模式下 optional sentinel 掩盖了真实 r(1)（假阳性）"
    exit 1
  fi
done
echo "PASS  探针：optional sentinel 在默认/--community 两模式均不掩盖真实 r(1)"
