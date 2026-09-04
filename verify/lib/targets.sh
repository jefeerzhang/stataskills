#!/usr/bin/env bash
# ============================================================
# 验证目标（verification target）注册表 —— 单一来源。
#
# 每个 skill `stata-<name>` 对应一个验证入口 `verify-<name>`。默认 1:1：
# 入口的 do-file 与 Stata 产出的 raw log 都叫 `verify-<name>`。少数入口
# 委托另一个 do-file（社区包验证脚本），在此登记。
#
# Declarative target plan（#20 / #23 / #27 / ADR-0004）：
#   - targets_plan_owner <entry>           → owner skill 名（无 stata- 前缀）
#   - targets_plan_dofiles <entry>         → 有序 do-file 基名（空格分隔一行）
#   - targets_plan_logs <entry>            → 有序 raw log 基名（== dofiles）
#   - targets_plan_delegate_bases          → 纯委托 do-file 基名（由 override 派生）
#
# Caller-facing iterators（按行输出；空格拆分只发生在本文件内）：
#   - targets_plan_each_dofile <entry>     → 每行一个 do-file 基名
#   - targets_plan_each_log <entry>        → 每行一个 raw log 基名
#   - targets_plan_each_pair <entry>       → 每行 "dofile<TAB>log"
#   - targets_plan_each_delegate           → 每行一个纯委托基名
#   - targets_plan_is_delegate <base>      → 0 若 base 为纯委托
#
# 旧空格分隔 interface（targets_run_dofile / targets_delegates）已于 #27 删除。
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

# ---- 按行迭代（空格拆分只发生在本文件内）----

# targets_plan_each_dofile <entry>
targets_plan_each_dofile() {
  local d
  # shellcheck disable=SC2086
  for d in $(targets_plan_dofiles "$1"); do
    printf '%s\n' "$d"
  done
}

# targets_plan_each_log <entry>
targets_plan_each_log() {
  local l
  # shellcheck disable=SC2086
  for l in $(targets_plan_logs "$1"); do
    printf '%s\n' "$l"
  done
}

# targets_plan_each_pair <entry>：每行 dofile<TAB>log（同序，caller 不推日志名）
targets_plan_each_pair() {
  local entry="$1"
  local -a ds ls
  local i
  # shellcheck disable=SC2206
  ds=($(targets_plan_dofiles "$entry"))
  # shellcheck disable=SC2206
  ls=($(targets_plan_logs "$entry"))
  if [ "${#ds[@]}" -ne "${#ls[@]}" ]; then
    printf 'targets_plan_each_pair: dofiles/logs 长度不一致 (%s)\n' "$entry" >&2
    return 1
  fi
  for i in "${!ds[@]}"; do
    printf '%s\t%s\n' "${ds[$i]}" "${ls[$i]}"
  done
}

# targets_plan_each_delegate
targets_plan_each_delegate() {
  local d
  # shellcheck disable=SC2086
  for d in $(targets_plan_delegate_bases); do
    [ -n "$d" ] || continue
    printf '%s\n' "$d"
  done
}

# targets_plan_is_delegate <base>：0=是纯委托 do-file
targets_plan_is_delegate() {
  local want="$1" d
  while IFS= read -r d; do
    [ "$d" = "$want" ] && return 0
  done < <(targets_plan_each_delegate)
  return 1
}
