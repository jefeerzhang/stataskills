#!/usr/bin/env bash
# ============================================================
# 验证目标（verification target）注册表 —— 单一来源。
#
# 每个 skill `stata-<name>` 对应一个验证入口 `verify-<name>`。默认 1:1：
# 入口的 do-file 与 Stata 产出的 raw log 都叫 `verify-<name>`。少数入口
# 委托另一个 do-file（社区包验证脚本），在此登记。
#
# 约定：
#   - targets_run_dofile <entry>  → 入口实际运行的 do-file 基名（不含 .do）。
#     Stata 批处理 `-b do X.do` 产出的 raw log 是 `X.log`，故 raw log 名
#     == run do-file 基名；提交进 repo 的 log 仍用入口名（run-verify.sh 的
#     evaluate 负责 cp 成 `verify/<entry>.log`）。
#   - targets_delegates          → 纯委托 do-file 基名清单（不是任何 skill
#     的入口，仅被其它入口引用），供 check-claims 的孤儿检测放行。
#
# 改委托只改这里。若未来出现多个委托，考虑按 ADR-0003「未来再评估」沉淀为
# TSV 数据文件；当前只有一个，保持两个小函数即可。
# ============================================================

# targets_run_dofile <entry>：把验证入口解析为实际运行的 do-file 基名。
targets_run_dofile() {
  case "$1" in
    verify-did-community) printf '%s\n' "verify-synth-sdid" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# targets_delegates：纯委托 do-file 基名（非入口），空格分隔的字符串。
# 单行输出而非 newline 分隔，是为了与 check-claims.sh 的 case pattern
# （`"${delegates}"` 内联 + glob 匹配）兼容；后续可加新委托继续以空格分隔。
targets_delegates() {
  printf '%s\n' "verify-synth-sdid verify-power verify-trop"
}
