#!/usr/bin/env bash
# ============================================================
# 回归测试：verification target plan（verify/lib/targets.sh）
#
# Issue #20 / parent #18：table-driven 覆盖普通入口、DID-community
# 三委托、唯一性、孤儿 delegate。断言走 plan 公共接口；旧
# targets_run_dofile / targets_delegates 必须与 plan 派生一致。
#
# 用法：bash verify/test-targets.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/targets.sh"

fail=0
pass() { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; fail=$((fail + 1)); }

# ---- helpers：要求 plan API 存在（#20 新 seam）----
require_fn() {
  if ! declare -F "$1" >/dev/null 2>&1; then
    bad "缺少 plan 函数 $1（#20 declarative target plan）"
    return 1
  fi
  return 0
}

require_fn targets_plan_owner || true
require_fn targets_plan_dofiles || true
require_fn targets_plan_logs || true
require_fn targets_plan_delegate_bases || true

# 若核心函数缺失，后续用例无意义——仍继续以便一次列出全部缺口
has_plan=1
declare -F targets_plan_owner >/dev/null 2>&1 || has_plan=0
declare -F targets_plan_dofiles >/dev/null 2>&1 || has_plan=0
declare -F targets_plan_logs >/dev/null 2>&1 || has_plan=0
declare -F targets_plan_delegate_bases >/dev/null 2>&1 || has_plan=0

# ---- 表驱动 fixture：entry | expected_owner | expected_dofiles ----
# 普通 1:1 与 multi-delegate 各至少一行。
FIXTURES=$(cat <<'EOF'
verify-basics|basics|verify-basics
verify-regression|regression|verify-regression
verify-did-community|did-community|verify-synth-sdid verify-power verify-trop
EOF
)

if [ "$has_plan" -eq 1 ]; then
  while IFS='|' read -r entry owner dofiles; do
    [ -n "${entry:-}" ] || continue
    got_owner=$(targets_plan_owner "$entry")
    got_dofiles=$(targets_plan_dofiles "$entry")
    got_logs=$(targets_plan_logs "$entry")

    if [ "$got_owner" = "$owner" ]; then
      pass "plan owner：$entry → $owner"
    else
      bad "plan owner：$entry 期望 $owner，得 $got_owner"
    fi

    if [ "$got_dofiles" = "$dofiles" ]; then
      pass "plan dofiles：$entry → $dofiles"
    else
      bad "plan dofiles：$entry 期望 [$dofiles]，得 [$got_dofiles]"
    fi

    if [ "$got_logs" = "$dofiles" ]; then
      pass "plan logs：$entry 与 dofiles 同序同名"
    else
      bad "plan logs：$entry 期望 [$dofiles]，得 [$got_logs]"
    fi

    # 唯一性：plan 内 dofile 不重复
    uniq_check=$(printf '%s\n' $got_dofiles | sort | uniq -d)
    if [ -z "$uniq_check" ]; then
      pass "plan 唯一性：$entry dofiles 无重复"
    else
      bad "plan 唯一性：$entry 重复 dofile：$uniq_check"
    fi

    # 旧 interface 与 plan 派生一致（#20：旧接口暂时保留）
    old_dofiles=$(targets_run_dofile "$entry")
    if [ "$old_dofiles" = "$got_dofiles" ]; then
      pass "旧 targets_run_dofile 与 plan 一致：$entry"
    else
      bad "旧 targets_run_dofile 漂移：$entry plan=[$got_dofiles] old=[$old_dofiles]"
    fi
  done <<EOF
$FIXTURES
EOF

  # ---- 孤儿 / delegate facts：由同一 plan 派生 ----
  got_delegates=$(targets_plan_delegate_bases)
  expect_delegates="verify-synth-sdid verify-power verify-trop"
  if [ "$got_delegates" = "$expect_delegates" ]; then
    pass "plan delegates：$expect_delegates"
  else
    bad "plan delegates 期望 [$expect_delegates]，得 [$got_delegates]"
  fi

  old_delegates=$(targets_delegates)
  if [ "$old_delegates" = "$got_delegates" ]; then
    pass "旧 targets_delegates 与 plan 一致"
  else
    bad "旧 targets_delegates 漂移：plan=[$got_delegates] old=[$old_delegates]"
  fi

  # 每个 orphan delegate：出现在某 entry plan 中，且自身不是恒等入口
  for d in $got_delegates; do
    found=0
    while IFS='|' read -r entry _owner dofiles; do
      [ -n "${entry:-}" ] || continue
      case " $dofiles " in
        *" $d "*) found=1 ;;
      esac
    done <<EOF
$FIXTURES
EOF
    if [ "$found" -eq 1 ] && [ "$(targets_plan_dofiles "$d")" = "$d" ]; then
      # 以 orphan 名调用 plan 时走默认恒等——说明它不是 override entry
      pass "orphan delegate：$d 被某 plan 引用且非 override 入口"
    else
      bad "orphan delegate 契约失败：$d（found=$found self-plan=$(targets_plan_dofiles "$d")）"
    fi
  done
else
  bad "declarative target plan API 未就绪，跳过表驱动用例"
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "结果：全部通过"
  exit 0
fi
echo "结果：${fail} 失败"
exit 1
