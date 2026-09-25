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
#          optional sentinel 掩盖真实 r(1) 错误、声明式 marker 契约
#          （VERIFY_MARKERS_REQUIRED）完整 / 自我满足 / 与 r() 同时报告、
#          单行 `if .. display` 回显行误判为缺包、bare sentinel 仍被识别。
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

# 探针 5：标记契约完整时必须 PASS（声明行与 marker 都是真实输出，非回显）
cat > "$WORKDIR/dynamic_ok.log" <<'EOF'
. display "VERIFY_MARKERS_REQUIRED=M_A M_B M_C"
VERIFY_MARKERS_REQUIRED=M_A M_B M_C
. xtabond y x, lags(1) twostep
M_A
M_B
M_C
end of do-file
EOF
if ! judge_raw_log zzprobe "$WORKDIR/dynamic_ok.log" 0 >/dev/null 2>&1; then
  echo "FAIL  探针：诊断标记契约完整时未 PASS"
  exit 1
fi
echo "PASS  探针：诊断标记契约完整时正确 PASS"

# 探针 6：marker 只出现在声明串里（未真实输出）必须 FAIL，
#          且失败信息要同时带 r() 计数，不得被契约信息掩盖
cat > "$WORKDIR/dynamic_selfsat.log" <<'EOF'
VERIFY_MARKERS_REQUIRED=M_A M_B M_C
end of do-file
EOF
if judge_raw_log zzprobe "$WORKDIR/dynamic_selfsat.log" 0 >/dev/null 2>&1; then
  echo "FAIL  探针：marker 被声明行自我满足时误判为 PASS"
  exit 1
fi
if ! judge_raw_log zzprobe "$WORKDIR/dynamic_selfsat.log" 0 2>&1 | grep -q "M_B"; then
  echo "FAIL  探针：缺失 marker 未逐项列出"
  exit 1
fi
echo "PASS  探针：marker 不能由声明行自我满足，缺失项逐项报告"

cat > "$WORKDIR/dynamic_err_and_missing.log" <<'EOF'
VERIFY_MARKERS_REQUIRED=M_A
some output
r(198);
end of do-file
end of do-file
EOF
if ! judge_raw_log zzprobe "$WORKDIR/dynamic_err_and_missing.log" 0 2>&1 \
   | grep -qE "r\(错误 x1.*诊断标记缺失"; then
  echo "FAIL  探针：真实 r() 与缺失 marker 未同时报告（信息被掩盖）"
  exit 1
fi
echo "PASS  探针：r() 错误与缺失 marker 同时报告，互不掩盖"

# 探针 7：单行 `if !.. display "SENTINEL"` 的**回显行**以 `. if` 开头，
#         包实际装着时不得被误报成未安装（回归 verify-dynamic-panel.do 旧形状）
cat > "$WORKDIR/sentinel_echo_only.log" <<'EOF'
. cap which ftools
. local has_ftools = (_rc == 0)
. if !`has_ftools' display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ftools__"
. if `has_ftools' {
.     reghdfe y x, absorb(id)
M_A
.     display "PKG_RAN_OK"
PKG_RAN_OK
. }
end of do-file
EOF
if judge_raw_log zzprobe "$WORKDIR/sentinel_echo_only.log" 1 2>&1 \
   | grep -q "ftools"; then
  echo "FAIL  探针：仅回显的 optional sentinel 被当作真实缺包"
  exit 1
fi
echo "PASS  探针：单行 if 回显的 sentinel 不被误判为缺包"

# 探针 8：bare（非回显）optional sentinel 仍须被识别为真实缺包
cat > "$WORKDIR/sentinel_real.log" <<'EOF'
. cap which ftools
. if !`has_ftools' {
.     display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ftools__"
__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ftools__
. }
end of do-file
EOF
if ! judge_raw_log zzprobe "$WORKDIR/sentinel_real.log" 0 2>&1 | grep -q "ftools"; then
  echo "FAIL  探针：真实输出的 optional sentinel 未被识别"
  exit 1
fi
echo "PASS  探针：真实输出的 sentinel 仍被正确识别"

# 探针 9：judge_log_has_command —— 回显行规则（#29 C5 后该知识只在 judge.sh）
cat > "$WORKDIR/cmd.log" <<'EOF'
. * ivreg2 只出现在注释
. capture which ivreg2
. quietly ivreg2 y (x = z), robust
end of do-file
EOF
if ! judge_log_has_command ivreg2 "$WORKDIR/cmd.log"; then
  echo "FAIL  探针：judge_log_has_command 未识别真实执行的 ivreg2（跳过注释/which/capture 前缀）"
  exit 1
fi
if judge_log_has_command coefplot "$WORKDIR/cmd.log"; then
  echo "FAIL  探针：judge_log_has_command 把未出现的命令判为已执行"
  exit 1
fi
echo "PASS  探针：judge_log_has_command 区分真实执行与注释/which 探针"
