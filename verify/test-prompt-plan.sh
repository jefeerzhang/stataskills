#!/usr/bin/env bash
# ============================================================
# 回归：cross-skill prompt execution plan（verify/lib/prompt_plan.sh）
#
# Issue #28：单 skill / 跨 skill / 共享 target 去重 / multi-delegate /
# missing keyword 报告格式。
#
# 用法：bash verify/test-prompt-plan.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/targets.sh"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/prompt_plan.sh"

fail=0
pass() { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; fail=$((fail + 1)); }

for fn in prompt_plan_normalize_skills prompt_plan_each_skill \
          prompt_plan_each_target prompt_plan_each_log_path; do
  if ! declare -F "$fn" >/dev/null 2>&1; then
    bad "缺少 $fn"
  fi
done
[ "$fail" -gt 0 ] && { echo "结果：${fail} 失败"; exit 1; }

plan=$(prompt_plan_each_target "stata-regression")
[ "$plan" = $'regression\tverify-regression\tverify-regression' ] \
  && pass "单 skill plan" || bad "单 skill：[$plan]"

plan=$(prompt_plan_each_target "stata-basics + stata-descriptives")
expect=$(printf '%s\n' $'basics\tverify-basics\tverify-basics' $'descriptives\tverify-descriptives\tverify-descriptives')
[ "$plan" = "$expect" ] && pass "跨 skill plan" || bad "跨 skill：[$plan]"

plan=$(prompt_plan_each_target "stata-regression + stata-basics + stata-regression")
expect=$(printf '%s\n' $'regression\tverify-regression\tverify-regression' $'basics\tverify-basics\tverify-basics')
[ "$plan" = "$expect" ] && pass "共享 target 去重保序" || bad "去重：[$plan]"

plan=$(prompt_plan_each_target "stata-did-community")
expect=$(printf '%s\n' \
  $'did-community\tverify-synth-sdid\tverify-synth-sdid' \
  $'did-community\tverify-power\tverify-power' \
  $'did-community\tverify-trop\tverify-trop')
[ "$plan" = "$expect" ] && pass "multi-delegate plan" || bad "delegate：[$plan]"

skills=$(prompt_plan_each_skill "stata-a + stata-b + stata-a" | paste -sd' ' -)
[ "$skills" = "a b" ] && pass "skill 去重保序" || bad "skills=[$skills]"

echo ""
if [ "$fail" -eq 0 ]; then
  echo "结果：全部通过"
  exit 0
fi
echo "结果：${fail} 失败"
exit 1
