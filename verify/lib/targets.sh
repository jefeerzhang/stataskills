#!/usr/bin/env bash
# ============================================================
# 验证目标（verification target）注册表 —— 单一来源。
#
# 每个 skill `stata-<name>` 对应一个验证入口 `verify-<name>`。默认 1:1：
# 入口的 do-file 与 Stata 产出的 raw log 都叫 `verify-<name>`。少数入口
# 委托另一个 do-file（社区包验证脚本），在此登记。
#
# Declarative target plan（#20 / ADR-0004 深化）：
#   - targets_plan_owner <entry>           → owner skill 名（无 stata- 前缀）
#   - targets_plan_dofiles <entry>         → 有序 do-file 基名（空格分隔一行）
#   - targets_plan_logs <entry>            → 有序 raw log 基名（== dofiles）
#   - targets_plan_delegate_bases          → 纯委托 do-file 基名（由 override 派生）
#
# 旧 interface（#20 暂时保留，caller 行为不变）：
#   - targets_run_dofile <entry>  → 同 targets_plan_dofiles
#   - targets_delegates           → 同 targets_plan_delegate_bases
#
# 改委托只改下方 _TARGETS_OVERRIDES + _targets_plan_override。
# ============================================================

# 已登记的非恒等 plan 入口（空格分隔）。delegate 清单由此扫描派生，
# 不另行手写第二份名单。
_TARGETS_OVERRIDES="verify-did-community"

# _targets_plan_override <entry>
# 命中非恒等 plan 时设置 _TARGETS_OWNER / _TARGETS_DOFILES 并 return 0；
# 否则 return 1（调用方走默认 1:1）。
_targets_plan_override() {
  case "$1" in
    verify-did-community)
      _TARGETS_OWNER="did-community"
      _TARGETS_DOFILES="verify-synth-sdid verify-power verify-trop"
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# targets_plan_owner <entry>：入口对应的 owner skill（无 stata- 前缀）。
targets_plan_owner() {
  if _targets_plan_override "$1"; then
    printf '%s\n' "$_TARGETS_OWNER"
  else
    printf '%s\n' "${1#verify-}"
  fi
}

# targets_plan_dofiles <entry>：有序 do-file 基名列表（空格分隔一行）。
targets_plan_dofiles() {
  if _targets_plan_override "$1"; then
    printf '%s\n' "$_TARGETS_DOFILES"
  else
    printf '%s\n' "$1"
  fi
}

# targets_plan_logs <entry>：raw log 基名 == run do-file 基名（ADR-0005）。
targets_plan_logs() {
  targets_plan_dofiles "$1"
}

# targets_plan_delegate_bases：纯委托 do-file（出现在某 override plan 中、
# 且不等于该 entry 自身）。由 _TARGETS_OVERRIDES 扫描派生，保持唯一、保序。
targets_plan_delegate_bases() {
  local out="" entry d
  # shellcheck disable=SC2086  # 刻意按空格拆 override 入口列表
  for entry in $_TARGETS_OVERRIDES; do
    # shellcheck disable=SC2046,SC2086
    for d in $(targets_plan_dofiles "$entry"); do
      [ "$d" = "$entry" ] && continue
      case " $out " in
        *" $d "*) ;;
        *) out="${out:+$out }$d" ;;
      esac
    done
  done
  printf '%s\n' "$out"
}

# ---- 旧 interface：薄封装，事实来自 plan ----

# targets_run_dofile <entry>：兼容既有 caller（空格分隔展开）。
targets_run_dofile() {
  targets_plan_dofiles "$1"
}

# targets_delegates：兼容 check-claims 孤儿检测（空格分隔一行）。
targets_delegates() {
  targets_plan_delegate_bases
}
