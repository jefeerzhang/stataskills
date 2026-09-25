#!/usr/bin/env bash
# ============================================================
# 回归测试：verification target plan（verify/lib/targets.sh）
#
# Issue #20 / #23 / #27 / parent #18：table-driven 覆盖普通入口、DID-community
# 三委托、identification 单委托、唯一性、孤儿 delegate；each_* 按行迭代；
# #27 确认旧空格 API 已删除。
#
# 用法：bash verify/test-targets.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/targets.sh"

# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"

# ---- helpers：要求 plan API 存在 ----
require_fn() {
  if ! declare -F "$1" >/dev/null 2>&1; then
    bad "缺少 plan 函数 $1（declarative target plan）"
    return 1
  fi
  return 0
}

require_fn targets_plan_owner || true
require_fn targets_plan_dofiles || true
require_fn targets_plan_logs || true
require_fn targets_plan_delegate_bases || true
require_fn targets_plan_each_dofile || true
require_fn targets_plan_each_log || true
require_fn targets_plan_each_pair || true
require_fn targets_plan_each_delegate || true
require_fn targets_plan_is_delegate || true

# #27：旧空格分隔 API 必须已删除
if declare -F targets_run_dofile >/dev/null 2>&1 || declare -F targets_delegates >/dev/null 2>&1; then
  bad "旧 targets_run_dofile / targets_delegates 仍存在（#27 应删除）"
else
  ok "旧空格 API 已删除（targets_run_dofile / targets_delegates）"
fi

# 若核心函数缺失，后续用例无意义——仍继续以便一次列出全部缺口
has_plan=1
declare -F targets_plan_owner >/dev/null 2>&1 || has_plan=0
declare -F targets_plan_dofiles >/dev/null 2>&1 || has_plan=0
declare -F targets_plan_logs >/dev/null 2>&1 || has_plan=0
declare -F targets_plan_delegate_bases >/dev/null 2>&1 || has_plan=0
declare -F targets_plan_each_pair >/dev/null 2>&1 || has_plan=0
declare -F targets_plan_each_delegate >/dev/null 2>&1 || has_plan=0
declare -F targets_plan_is_delegate >/dev/null 2>&1 || has_plan=0

# ---- 表驱动 fixture：entry | expected_owner | expected_dofiles ----
# 普通 1:1 与 multi-delegate 各至少一行。
FIXTURES=$(cat <<'EOF'
verify-basics|basics|verify-basics
verify-dce|dce|verify-dce
verify-count|count|verify-count
verify-fractional|fractional|verify-fractional
verify-limited-dependent|limited-dependent|verify-limited-dependent
verify-regression|regression|verify-regression verify-dynamic-panel
verify-did-community|did-community|verify-synth-sdid verify-power verify-trop
verify-identification|identification|verify-identification verify-sensitivity
EOF
)

if [ "$has_plan" -eq 1 ]; then
  while IFS='|' read -r entry owner dofiles; do
    [ -n "${entry:-}" ] || continue
    got_owner=$(targets_plan_owner "$entry")
    got_dofiles=$(targets_plan_dofiles "$entry")
    got_logs=$(targets_plan_logs "$entry")

    if [ "$got_owner" = "$owner" ]; then
      ok "plan owner：$entry → $owner"
    else
      bad "plan owner：$entry 期望 $owner，得 $got_owner"
    fi

    if [ "$got_dofiles" = "$dofiles" ]; then
      ok "plan dofiles：$entry → $dofiles"
    else
      bad "plan dofiles：$entry 期望 [$dofiles]，得 [$got_dofiles]"
    fi

    if [ "$got_logs" = "$dofiles" ]; then
      ok "plan logs：$entry 与 dofiles 同序同名"
    else
      bad "plan logs：$entry 期望 [$dofiles]，得 [$got_logs]"
    fi

    # 唯一性：plan 内 dofile 不重复
    uniq_check=$(printf '%s\n' $got_dofiles | sort | uniq -d)
    if [ -z "$uniq_check" ]; then
      ok "plan 唯一性：$entry dofiles 无重复"
    else
      bad "plan 唯一性：$entry 重复 dofile：$uniq_check"
    fi

    # #23：each_dofile / each_log / each_pair 按行、同序；日志名来自 plan
    each_dofs=""
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      each_dofs="${each_dofs:+$each_dofs }$d"
    done < <(targets_plan_each_dofile "$entry")
    if [ "$each_dofs" = "$dofiles" ]; then
      ok "each_dofile：$entry 按行同序"
    else
      bad "each_dofile：$entry 期望 [$dofiles]，得 [$each_dofs]"
    fi

    each_logs=""
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      each_logs="${each_logs:+$each_logs }$l"
    done < <(targets_plan_each_log "$entry")
    if [ "$each_logs" = "$dofiles" ]; then
      ok "each_log：$entry 按行同序同名"
    else
      bad "each_log：$entry 期望 [$dofiles]，得 [$each_logs]"
    fi

    pair_ok=1
    pair_i=0
    # shellcheck disable=SC2206
    expect_arr=($dofiles)
    while IFS=$'\t' read -r pd pl; do
      [ -n "${pd:-}" ] || continue
      if [ "$pair_i" -ge "${#expect_arr[@]}" ]; then
        pair_ok=0
        break
      fi
      if [ "$pd" != "${expect_arr[$pair_i]}" ] || [ "$pl" != "${expect_arr[$pair_i]}" ]; then
        pair_ok=0
        break
      fi
      pair_i=$((pair_i + 1))
    done < <(targets_plan_each_pair "$entry")
    if [ "$pair_ok" -eq 1 ] && [ "$pair_i" -eq "${#expect_arr[@]}" ]; then
      ok "each_pair：$entry dofile\\tlog 同序（不推日志名）"
    else
      bad "each_pair：$entry 序或内容漂移（got $pair_i / ${#expect_arr[@]}）"
    fi
  done <<EOF
$FIXTURES
EOF

  # ---- 孤儿 / delegate facts：由同一 plan 派生 ----
  got_delegates=$(targets_plan_delegate_bases)
  expect_delegates="verify-dynamic-panel verify-synth-sdid verify-power verify-trop verify-sensitivity"
  if [ "$got_delegates" = "$expect_delegates" ]; then
    ok "plan delegates：$expect_delegates"
  else
    bad "plan delegates 期望 [$expect_delegates]，得 [$got_delegates]"
  fi

  each_delegates=""
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    each_delegates="${each_delegates:+$each_delegates }$d"
  done < <(targets_plan_each_delegate)
  if [ "$each_delegates" = "$expect_delegates" ]; then
    ok "each_delegate 按行同序"
  else
    bad "each_delegate 期望 [$expect_delegates]，得 [$each_delegates]"
  fi

  if targets_plan_is_delegate verify-dynamic-panel \
    && targets_plan_is_delegate verify-synth-sdid \
    && targets_plan_is_delegate verify-power \
    && targets_plan_is_delegate verify-trop \
    && targets_plan_is_delegate verify-sensitivity \
    && ! targets_plan_is_delegate verify-basics; then
    ok "is_delegate：五委托命中、普通入口否"
  else
    bad "is_delegate 契约失败"
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
      ok "orphan delegate：$d 被某 plan 引用且非 override 入口"
    else
      bad "orphan delegate 契约失败：$d（found=$found self-plan=$(targets_plan_dofiles "$d")）"
    fi
  done

  # #23/#27：caller 不得调用已删旧空格 API（允许在断言中点名禁词）
  for f in run-verify.sh check-claims.sh test-prompts.sh; do
    if grep -nE '\$\(targets_run_dofile|\$\(targets_delegates|[^[:alnum:]_]targets_run_dofile\s*\(|[^[:alnum:]_]targets_delegates\s*\(' \
         "$VERIFY_DIR/$f" >/dev/null 2>&1; then
      bad "caller 仍调用旧空格 API：$f"
    else
      ok "caller 无旧 API 调用：$f"
    fi
  done

  # #24：prompt harness 不得硬编码 DID-community 委托日志集合
  if grep -nE 'verify-synth-sdid\.log|verify-power\.log|verify-trop\.log' \
       "$VERIFY_DIR/test-prompts.sh" >/dev/null 2>&1; then
    bad "test-prompts.sh 仍硬编码 DID-community expected log 集合（#24）"
  else
    ok "test-prompts.sh 无硬编码 DID-community log 集合"
  fi
  if grep -nE 'verify_dofiles_for_skill|targets_plan_each_dofile' \
       "$VERIFY_DIR/test-prompts.sh" >/dev/null 2>&1; then
    ok "test-prompts.sh 从 plan 解析 ordered do-files"
  else
    bad "test-prompts.sh 未从 plan 获取 ordered do-files（#24）"
  fi
else
  bad "declarative target plan API 未就绪，跳过表驱动用例"
fi

# ---- targets_each_skill（#29 C7）：skill 发现的单一实现 ----
if declare -F targets_each_skill >/dev/null 2>&1; then
  n_skills="$(targets_each_skill | grep -c . || true)"
  n_dirs="$(ls -d "$VERIFY_DIR"/../stata-*/SKILL.md 2>/dev/null | grep -c . || true)"
  if [ "$n_skills" -gt 0 ] && [ "$n_skills" = "$n_dirs" ]; then
    ok "targets_each_skill 与磁盘 skill 目录数一致（${n_skills}）"
  else
    bad "targets_each_skill 计数漂移：$n_skills vs $n_dirs"
  fi
  if targets_each_skill | grep -qx 'stata-basics'; then
    ok "targets_each_skill 输出 stata-<name> 形式"
  else
    bad "targets_each_skill 未输出 stata-basics"
  fi
  if targets_each_skill "$VERIFY_DIR/.." | grep -qx 'stata-basics'; then
    ok "targets_each_skill 支持显式 root 参数"
  else
    bad "targets_each_skill 显式 root 参数不生效"
  fi
else
  bad "缺 targets_each_skill（#29 C7）"
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "结果：全部通过"
  exit 0
fi
echo "结果：${fail} 失败"
exit 1
