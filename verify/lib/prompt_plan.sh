#!/usr/bin/env bash
# ============================================================
# Cross-skill prompt execution plan（#28 / parent #18）
#
# 把 fixture 的 skill 字段（可含 "stata-a + stata-b"）展开为确定的
# target plan：每个 normalized skill → do-file / log；按 do-file 基名
# 去重并保持首次出现顺序。覆盖检查与 --prompts 执行共用此 seam。
#
# 依赖：已 source verify/lib/targets.sh
# ============================================================

# prompt_plan_normalize_skills <skill_field>
# 每行一个短名（去 stata- 前缀）；按 + 分割、trim；保留重复（供调用方去重策略）。
prompt_plan_normalize_skills() {
  local field="$1" part
  # 统一分隔：+ 两侧空白
  field="${field//＋/+}"
  while IFS= read -r part; do
    part="${part#"${part%%[![:space:]]*}"}"
    part="${part%"${part##*[![:space:]]}"}"
    [ -z "$part" ] && continue
    part="${part#stata-}"
    printf '%s\n' "$part"
  done < <(printf '%s\n' "$field" | tr '+' '\n')
}

# prompt_plan_each_skill <skill_field>
# 去重后的 skill 短名（首次出现顺序），供 run-verify 逐入口执行。
prompt_plan_each_skill() {
  local seen="" s
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    case " $seen " in
      *" $s "*) continue ;;
    esac
    seen="${seen:+$seen }$s"
    printf '%s\n' "$s"
  done < <(prompt_plan_normalize_skills "$1")
}

# prompt_plan_each_target <skill_field>
# 每行：skill<TAB>dofile_base<TAB>log_base
# 经 targets_plan_each_pair 展开；按 dofile_base 去重（首次 skill 归属保留）。
prompt_plan_each_target() {
  local seen="" s entry d l
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    entry="verify-$s"
    while IFS=$'\t' read -r d l; do
      [ -n "${d:-}" ] || continue
      case " $seen " in
        *" $d "*) continue ;;
      esac
      seen="${seen:+$seen }$d"
      printf '%s\t%s\t%s\n' "$s" "$d" "$l"
    done < <(targets_plan_each_pair "$entry")
  done < <(prompt_plan_each_skill "$1")
}

# prompt_plan_each_log_path <skill_field> <verify_dir>
# 每行：skill<TAB>abs_log_path（与 each_target 同序、已去重）
prompt_plan_each_log_path() {
  local field="$1" vdir="$2" s d l
  while IFS=$'\t' read -r s d l; do
    [ -n "${l:-}" ] || continue
    printf '%s\t%s/%s.log\n' "$s" "$vdir" "$l"
  done < <(prompt_plan_each_target "$field")
}
