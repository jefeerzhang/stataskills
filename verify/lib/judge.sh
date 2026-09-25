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
# 诊断标记契约：需要哪些成功标记由 do-file 自己在日志里声明
#   display "VERIFY_MARKERS_REQUIRED=<M1> <M2> ..."
# judge 只解释日志观察到的声明，不承载第二份 marker 名单（同 community.sh
# 对 package 名单的约定）。未声明的入口行为不变，只看 end / r() / 静默错误。
#
# 用法：先 source "$VERIFY_DIR/lib/report.sh"，再
#       source "$VERIFY_DIR/lib/judge.sh"
#   judge_raw_log <entry> <raw_log_path> <community_mode(0|1)>
#   返回 0 = PASS，1 = FAIL；对每个判定打印 ok/bad 行。
#   judge_log_has_command <keyword> <log_file>
#   返回 0 = 日志里真实执行过该命令（注释/which 探针不算）；1 = 没有。
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

  # sentinel / marker 匹配：Stata batch mode 会把 do 源码逐行回显成 `. ...` 行，
  # 导致 "TOKEN 从未真实输出、只是命令被回显" 时误匹配。剔除回显行时不能只盯
  # `. display` 前缀——单行 `if !`has_x' display "TOKEN"` 的回显以 `. if` 开头。
  # 按「回显行且含 display」剔除：真实输出是裸 TOKEN，不含 display 一词。
  local log_body
  log_body="$(grep -vE '^[.].*display' "$log" 2>/dev/null || true)"
  PARSE_COMMUNITY_REQ="$(printf '%s\n' "$log_body" | grep -oE '__COMMUNITY_PACKAGE_MISSING__[a-zA-Z0-9_]+__' 2>/dev/null | sort -u | tr '\n' ' ' || true)"
  PARSE_COMMUNITY_OPT="$(printf '%s\n' "$log_body" | grep -oE '__COMMUNITY_PACKAGE_OPTIONAL_MISSING__[a-zA-Z0-9_]+__' 2>/dev/null | sort -u | tr '\n' ' ' || true)"

  # 诊断标记契约：需要哪些成功标记由 do-file 自己在日志里声明
  # （`display "VERIFY_MARKERS_REQUIRED=A B C"`），judge 只解释日志观察到的
  # 声明，不承载第二份 marker 名单——与 community.sh 对 package 名单的约定一致。
  # 校验时必须先剔除声明行本身，否则名单里的 marker 会被声明串自我满足。
  local PARSE_MARKERS="" PARSE_MARKER_MISSING="" PARSE_MARKER_EVIDENCE="" marker
  PARSE_MARKERS="$(printf '%s\n' "$log_body" | grep -oE 'VERIFY_MARKERS_REQUIRED=.*' 2>/dev/null | head -1 | sed 's/^VERIFY_MARKERS_REQUIRED=//')"
  if [ -n "$PARSE_MARKERS" ]; then
    PARSE_MARKER_EVIDENCE="$(printf '%s\n' "$log_body" | grep -v '^VERIFY_MARKERS_REQUIRED=')"
    for marker in $PARSE_MARKERS; do
      if ! printf '%s\n' "$PARSE_MARKER_EVIDENCE" | grep -qF -- "$marker"; then
        PARSE_MARKER_MISSING="${PARSE_MARKER_MISSING}${marker} "
      fi
    done
  fi

  if [ "$PARSE_ENDS" -eq 1 ] && [ "$PARSE_ERRS" -eq 0 ] && [ "$PARSE_SILENT" -eq 0 ] && [ -z "$PARSE_MARKER_MISSING" ]; then
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
    # 两类问题必须同时报：只有 marker 缺失时曾把 r() 计数吞掉，逼作者去开日志。
    local fail_detail
    fail_detail="end of do-file x${PARSE_ENDS}，r(错误 x${PARSE_ERRS}，静默错误 x${PARSE_SILENT}"
    if [ -n "$PARSE_MARKER_MISSING" ]; then
      fail_detail="${fail_detail}，诊断标记缺失：${PARSE_MARKER_MISSING}"
    fi
    bad "${name}（${fail_detail}）→ 见 ${log}"
    return 1
  fi
}

# judge_log_has_command <keyword> <log_file>
# 日志中是否存在「真实执行」过 keyword 的命令行：行以 `. ` 回显开头、
# 跳过 capture/cap/quietly/noisily 等前缀、跳过 `*` 注释与 `which` 探针。
# 这是「Stata 批处理日志行长什么样」的单一实现（#29 C5）——caller 不得再
# 自写 awk 复刻回显规则（回归见 test-harness.sh 的 judge_log_has_command 探针）。
judge_log_has_command() {
  local keyword="$1" log_file="$2"
  awk -v keyword="$keyword" '
    $1 == "." {
      i = 2
      while ($i ~ /^(capture|cap|quietly|quiet|qui|noisily|noi)$/) i++
      if ($i == "*" || $i == "which") next
      for (j = i; j <= NF; j++) {
        token = $j
        gsub(/^[,(]+|[,)]+$/, "", token)
        if (token == keyword) found = 1
      }
    }
    END { exit(found ? 0 : 1) }
  ' "$log_file"
}
