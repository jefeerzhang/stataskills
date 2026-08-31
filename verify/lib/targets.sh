#!/usr/bin/env bash
# ============================================================
# 验证目标（verification target）注册表 —— 单一来源。
#
# 每个 skill `stata-<name>` 对应一个验证入口 `verify-<name>`。默认 1:1：
# 入口的 do-file 与 Stata 产出的 raw log 都叫 `verify-<name>`。少数入口
# 委托另一个 do-file（社区包验证脚本），在此登记。
#
# 约定：
#   - targets_run_dofile <entry>  → 入口实际运行的 do-file 基名列表（不含 .do），
#     可以是多个（空格分隔）。Stata 批处理 `-b do X.do` 产出的 raw log 是
#     `X.log`，故 raw log 名 == run do-file 基名；每个委托 do-file 的 raw log
#     分别提交为 `verify/<base>.log`（run-verify.sh 的 evaluate 负责处理）。
#   - targets_delegates          → 纯委托 do-file 基名清单（不是任何 skill
#     的入口，仅被其它入口引用），供 check-claims 的孤儿检测放行。
#
# 改委托只改这里。多委托以空格分隔输出（与 check-claims.sh 的 case pattern
# `"${delegates}"` 内联 + glob 匹配兼容），不做 TSV——当前只有 did-community
# 一个多委托入口，两个小函数即可。
# ============================================================

# targets_run_dofile <entry>：把验证入口解析为实际运行的 do-file 基名列表。
# 单入口返回自身；did-community 委托三个 do-file（synth-sdid + power + trop）。
targets_run_dofile() {
  case "$1" in
    verify-did-community) printf '%s\n' "verify-synth-sdid verify-power verify-trop" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# targets_delegates：纯委托 do-file 基名（非入口），空格分隔的字符串。
# 单行输出而非 newline 分隔，是为了与 check-claims.sh 的 case pattern
# （`"${delegates}"` 内联 + glob 匹配）兼容；后续可加新委托继续以空格分隔。
targets_delegates() {
  printf '%s\n' "verify-synth-sdid verify-power verify-trop"
}
