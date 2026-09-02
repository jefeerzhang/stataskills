#!/usr/bin/env bash
# ============================================================
# 日志判定层（纯函数，无 Stata 依赖）—— verify 脚本群共享接口。
#
# 判定标准（与 demo/REPORT.md 一致）：日志恰好一次 "end of do-file"
# 且无 Stata 错误码 r(NN) 且无静默错误（variable not found /
# option not allowed / invalid syntax / no observations 等）→ PASS；
# 任一失败返回非零。
#
# 错误码匹配用整行锚定 ^[[:space:]]*r\([0-9]+\);[[:space:]]*$：Stata 报错时
# 错误码独占一行（形如 "    r(111);"），既能捕获个位数错误码（如 assert
# 失败的 r(9)，旧版 {2,} 正则漏判），又不会误吃命令行内嵌的合法子串
# 如 power(0.90) / star(5) 中的 r(...)。
#
# 社区包 sentinel（ADR-0003）：缺必需包分支只输出 sentinel 并跳过对应命令，
# 不产生错误码；任何 r(N) 都必须保留为真实失败，不能因 sentinel 被豁免。
#
# 用法：先 source "$VERIFY_DIR/lib/report.sh"，再
#       source "$VERIFY_DIR/lib/judge.sh"
#   judge_raw_log <entry> <raw_log_path> <community_mode(0|1)>
#   返回 0 = PASS，1 = FAIL；对每个判定打印 ok/bad 行。
# ============================================================

judge_raw_log() {
  local name="$1" log="$2" community_mode="$3"
  if [ ! -f "$log" ]; then
    bad "${name}（无 log 生成，批处理未执行）"
    return 1
  fi

  local PARSE_ENDS PARSE_ERRS PARSE_SILENT PARSE_COMMUNITY_REQ PARSE_COMMUNITY_OPT
  PARSE_ENDS=$(grep -c "end of do-file" "$log")
  PARSE_ERRS=$(grep -cE '^[[:space:]]*r\([0-9]+\);[[:space:]]*$' "$log")
  PARSE_SILENT=$(grep -cE "\(variable .* not found\)|option .* not allowed|invalid syntax|no observations|(^|[^0-9])0 observations|insufficient observations|not sorted" "$log")

  # sentinel 匹配：Stata batch mode 会把 do 文件里的 `display "SENTINEL"` 命令
  # 文本回显成 `.     display "SENTINEL"`（行首带点号 + display 前缀），导致
  # "包从未缺失但命令被回显"时误匹配。用 grep -v 剔除回显行（行首 `. display`），
  # 再在剩余行里匹配 sentinel。缺包分支只输出 sentinel 并跳过对应命令，
  # 不产生错误码；任何 r(N) 都必须保留为真实失败，不能因 sentinel 被豁免。
  local sentinel_lines
  sentinel_lines="$(grep -vE '^[.][[:space:]]*display' "$log" 2>/dev/null)"
  PARSE_COMMUNITY_REQ="$(printf '%s\n' "$sentinel_lines" | grep -oE '__COMMUNITY_PACKAGE_MISSING__[a-zA-Z0-9_]+__' 2>/dev/null | sort -u | tr '\n' ' ' || true)"
  PARSE_COMMUNITY_OPT="$(printf '%s\n' "$sentinel_lines" | grep -oE '__COMMUNITY_PACKAGE_OPTIONAL_MISSING__[a-zA-Z0-9_]+__' 2>/dev/null | sort -u | tr '\n' ' ' || true)"

  if [ "$PARSE_ENDS" -eq 1 ] && [ "$PARSE_ERRS" -eq 0 ] && [ "$PARSE_SILENT" -eq 0 ]; then
    if [ -n "$PARSE_COMMUNITY_REQ" ] && [ "$community_mode" -eq 1 ]; then
      bad "${name}（--community 模式下缺必需包：${PARSE_COMMUNITY_REQ}，请 ssc install 后重跑）"
      return 1
    elif [ -n "$PARSE_COMMUNITY_REQ" ]; then
      ok "${name}（end of do-file x1；必需社区包未装已 cap 跳过：${PARSE_COMMUNITY_REQ}；用 --community 强制验证）"
    elif [ -n "$PARSE_COMMUNITY_OPT" ]; then
      ok "${name}（end of do-file x1；可选社区包未装已跳过：${PARSE_COMMUNITY_OPT}）"
    else
      ok "${name}（end of do-file x1，无错误码，无静默错误）"
    fi
    return 0
  else
    bad "${name}（end of do-file x${PARSE_ENDS}，r(错误 x${PARSE_ERRS}，静默错误 x${PARSE_SILENT}）→ 见 ${log}"
    return 1
  fi
}
