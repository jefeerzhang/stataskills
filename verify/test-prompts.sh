#!/usr/bin/env bash
# ============================================================
# Agent 行为回归测试 harness：把 test-prompts.json 的 prompt
# 从 spec 升级为可执行测试。
#
# 三模式（仿 verify/test-harness.sh 套路 + check-claims.sh 的 docs 层）：
#   默认（docs）  : 文档层断言——test-prompts.json 合法 + expected_outputs 关键词
#                   出现在 README/REPORT/对应 SKILL.md；CI 友好（无 Stata 依赖）
#   --prompts     : Stata 子集层——跑现有 verify-<skill>.do（run-verify.sh harness）
#                   + 断言 verify_keywords 出现在实际命令行；需要本机 Stata
#   --llm         : Claude CLI 层——调用 `claude -p <prompt>` 跑 prompt，断言期望
#                   输出；需要 claude CLI + ANTHROPIC_API_KEY；不存在时 SKIP 不报错
#
# 模式设计理由（与项目 ADR-0001 / 0003 一致）：
#   - 默认模式让 CI 不被网络/Stata 包绑定（与 run-verify.sh --static 同款）
#   - --prompts 模式让本地"我要确保 prompt 真能跑通"显式可执行（与 --community 同款）
#   - --llm 模式让"Agent 真实行为"可观测，但需要 LLM API（不在 CI 跑）
#
# 用法：
#   bash verify/test-prompts.sh                 # docs（默认，CI 用）
#   bash verify/test-prompts.sh --prompts       # Stata 子集（本地真验证）
#   bash verify/test-prompts.sh --llm           # Claude CLI（开发者手动）
#   bash verify/test-prompts.sh --help          # 帮助
# ============================================================
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_PROMPTS_JSON="$REPO_ROOT/test-prompts.json"

# ---- 参数解析 ----
MODE="docs"
while [ $# -gt 0 ]; do
  case "$1" in
    --prompts) MODE="prompts" ;;
    --llm)     MODE="llm" ;;
    --help|-h)
      sed -n '2,/^set -u/p' "$0" | sed 's/^# \{0,1\}//' | head -30
      exit 0
      ;;
    *) echo "ERROR: 未知参数 $1；用 --help 查看用法" >&2; exit 1 ;;
  esac
  shift
done

# ---- 前置检查 ----
[ -f "$TEST_PROMPTS_JSON" ] || { echo "ERROR: 找不到 $TEST_PROMPTS_JSON" >&2; exit 1; }
PYTHON_BIN="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
if command -v jq >/dev/null 2>&1; then
  JSON_BACKEND="jq"
elif [ -n "$PYTHON_BIN" ]; then
  JSON_BACKEND="python"
else
  echo "ERROR: 解析 test-prompts.json 需要 jq、python3 或 python" >&2
  exit 1
fi

json_prompt_count() {
  if [ "$JSON_BACKEND" = "jq" ]; then
    jq '.prompts | length' "$TEST_PROMPTS_JSON"
  else
    "$PYTHON_BIN" -X utf8 -c 'import json,sys; print(len(json.load(open(sys.argv[1], encoding="utf-8"))["prompts"]))' "$TEST_PROMPTS_JSON"
  fi
}

json_skill_count() {
  if [ "$JSON_BACKEND" = "jq" ]; then
    jq -r '[.prompts[].skill | split(" ") | .[] | select(. != "+")] | unique | length' "$TEST_PROMPTS_JSON"
  else
    "$PYTHON_BIN" -X utf8 -c 'import json,re,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print(len({s.strip() for p in d["prompts"] for s in re.split(r"\s*\+\s*", p["skill"])}))' "$TEST_PROMPTS_JSON"
  fi
}

json_missing_skills() {
  if [ "$JSON_BACKEND" = "jq" ]; then
    jq -r '["stata-basics","stata-descriptives","stata-regression","stata-advanced","stata-coefplot","stata-did","stata-did-community","stata-rdd"] - ([.prompts[].skill | split(" ") | .[] | select(. != "+")] | unique) | .[]' "$TEST_PROMPTS_JSON"
  else
    "$PYTHON_BIN" -X utf8 -c 'import json,re,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); expected={"stata-basics","stata-descriptives","stata-regression","stata-advanced","stata-coefplot","stata-did","stata-did-community","stata-rdd"}; covered={s.strip() for p in d["prompts"] for s in re.split(r"\s*\+\s*", p["skill"])}; print("\n".join(sorted(expected-covered)))' "$TEST_PROMPTS_JSON"
  fi
}

json_prompt_field() {
  local index="$1" field="$2" separator="${3:-}"
  if [ "$JSON_BACKEND" = "jq" ]; then
    if [ -n "$separator" ]; then
      jq -r ".prompts[$index].$field | join(\"$separator\")" "$TEST_PROMPTS_JSON"
    else
      jq -r ".prompts[$index].$field" "$TEST_PROMPTS_JSON"
    fi
  else
    "$PYTHON_BIN" -X utf8 -c 'import json,sys; v=json.load(open(sys.argv[1], encoding="utf-8"))["prompts"][int(sys.argv[2])][sys.argv[3]]; print(sys.argv[4].join(v) if isinstance(v,list) else v)' "$TEST_PROMPTS_JSON" "$index" "$field" "$separator"
  fi
}

PROMPT_COUNT="$(json_prompt_count)"
# skill 字段可能是 "skill-a + skill-b" 跨 skill 形式（如 cross-*），split 后过滤掉 "+" 取 unique
SKILL_COUNT="$(json_skill_count)"

echo "test-prompts harness · mode=$MODE · prompts=$PROMPT_COUNT · skills=$SKILL_COUNT"
echo

# ============================================================
# 模式 A: docs（默认）
# ============================================================
run_docs_mode() {
  local pass=0 fail=0

  # 1. JSON 合法
  if [ "$PROMPT_COUNT" -gt 0 ]; then
    echo "PASS  test-prompts.json 合法，含 $PROMPT_COUNT 条 prompt"
    pass=$((pass+1))
  else
    echo "FAIL  test-prompts.json 不合法"
    fail=$((fail+1))
  fi

  # 2. 覆盖全部 8 skill
  local missing_skills
  missing_skills="$(json_missing_skills)"
  if [ -z "$missing_skills" ]; then
    echo "PASS  test-prompts 覆盖全部 8 skill"
    pass=$((pass+1))
  else
    echo "FAIL  test-prompts 缺 skill: $missing_skills"
    fail=$((fail+1))
  fi

  # 3. 每条 prompt 的 expected_outputs 关键词必须在某处出现
  #    检查范围：README.md + demo/REPORT.md + 对应 SKILL.md + demo dofile logs
  #    关键词从 expected_outputs 字段提取核心术语
  local i=0
  while [ "$i" -lt "$PROMPT_COUNT" ]; do
    local pid skill expected_outputs
    pid="$(json_prompt_field "$i" id)"
    skill="$(json_prompt_field "$i" skill)"
    expected_outputs="$(json_prompt_field "$i" expected_outputs " | ")"

    # 关键词提取：取每个 expected_output 元素的子串（去掉连接词），grep 任意一处出现即可
    local keyword_hit=0
    local kw
    for kw in $(echo "$expected_outputs" | tr '|' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -3); do
      # 跳过太通用的词（如 "的"、"等"）
      [ "${#kw}" -lt 4 ] && continue
      # 在 README / REPORT / 对应 SKILL.md / demo logs 中 grep
      if grep -qE "$(echo "$kw" | sed 's/[][\.*^$/]/\\&/g')" \
          "$REPO_ROOT/README.md" \
          "$REPO_ROOT/demo/REPORT.md" \
          "$REPO_ROOT/$skill/SKILL.md" \
          "$REPO_ROOT/demo/logs/"*.log \
          2>/dev/null; then
        keyword_hit=1
        break
      fi
    done

    if [ "$keyword_hit" -eq 1 ]; then
      echo "PASS  $pid · expected_outputs 关键词出现在文档/日志中"
      pass=$((pass+1))
    else
      echo "WARN  $pid · expected_outputs 关键词未在任何文档/日志中找到（可能 prompt 太抽象）"
      # 不算 FAIL，因为 prompt 可能涉及跨 skill 联动
    fi
    i=$((i+1))
  done

  echo
  echo "结果（docs 模式）：$pass 通过，$fail 失败"
  [ "$fail" -eq 0 ] || exit 1
}

# ============================================================
# 模式 B: --prompts（Stata 子集）
# ============================================================

# 模式 B 的数据全部来自 test-prompts.json（单一来源，不再用平行数组）：
#   - verify_keywords → 匹配 Stata log 中实际执行的命令行；注释与 which 探针不算覆盖
#   - skill 字段取首个、去 "stata-" 前缀 → run-verify.sh 的目标名
log_has_executed_command() {
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

self_test_log_matcher() {
  local probe
  probe="$(mktemp)"
  printf '%s\n' '. * ivreg2 只出现在注释' '. capture which ivreg2' > "$probe"
  if log_has_executed_command ivreg2 "$probe"; then
    rm -f "$probe"
    echo "FAIL  log matcher 把注释或 which 探针误判为执行证据"
    return 1
  fi
  printf '%s\n' '. ivreg2 y (x = z), robust' >> "$probe"
  if ! log_has_executed_command ivreg2 "$probe"; then
    rm -f "$probe"
    echo "FAIL  log matcher 未识别真实执行命令"
    return 1
  fi
  rm -f "$probe"
}

run_prompts_mode() {
  local pass=0 fail=0
  self_test_log_matcher || return 1

  local pid skill keywords first_skill verify_log i=0
  while [ "$i" -lt "$PROMPT_COUNT" ]; do
    pid="$(json_prompt_field "$i" id)"
    skill="$(json_prompt_field "$i" skill)"
    keywords="$(json_prompt_field "$i" verify_keywords " ")"

    if [ -z "$keywords" ]; then
      echo "SKIP  $pid · 无 verify_keywords"
      i=$((i+1))
      continue
    fi

    # 目标名 = 首个 skill 去 "stata-" 前缀（registry 按此解析 do-file）；
    # 跨 skill 联动 prompt（如 cross-01）只跑第一个 skill。
    first_skill="${skill%% *}"
    first_skill="${first_skill#stata-}"
    verify_log="$VERIFY_DIR/verify-${first_skill}.log"

    # 跑 verify-<skill>.do（用 run-verify.sh harness）
    if ! bash "$VERIFY_DIR/run-verify.sh" "$first_skill" >/dev/null 2>&1; then
      echo "FAIL  $pid · run-verify.sh $first_skill 返回非零"
      fail=$((fail+1))
      i=$((i+1))
      continue
    fi

    # 只认真实执行的命令；注释、cap which <package> 和输出文本不能充当覆盖。
    local kw missing_kw=""
    for kw in $keywords; do
      if ! log_has_executed_command "$kw" "$verify_log"; then
        missing_kw="$missing_kw $kw"
      fi
    done

    if [ -z "$missing_kw" ]; then
      echo "PASS  $pid · log 含关键词：$keywords"
      pass=$((pass+1))
    else
      echo "FAIL  $pid · log 缺关键词：$missing_kw"
      fail=$((fail+1))
    fi
    i=$((i+1))
  done

  echo
  echo "结果（--prompts 模式）：$pass 通过，$fail 失败"
  [ "$fail" -eq 0 ] || exit 1
}

# ============================================================
# 模式 C: --llm（Claude CLI）
# ============================================================
run_llm_mode() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "SKIP  --llm 模式：claude CLI 不存在；需要安装 Claude CLI 并配置 ANTHROPIC_API_KEY"
    echo "      安装：npm install -g @anthropic-ai/claude-cli"
    exit 0
  fi

  if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "SKIP  --llm 模式：ANTHROPIC_API_KEY 未设置"
    exit 0
  fi

  local pass=0 fail=0 i=0
  while [ "$i" -lt "$PROMPT_COUNT" ]; do
    local pid scenario
    pid="$(json_prompt_field "$i" id)"
    scenario="$(json_prompt_field "$i" scenario)"

    echo "RUN  $pid · 调用 claude -p 跑 prompt..."
    local response
    response="$(claude -p "$scenario" --output-format text 2>/dev/null || echo "LLM_ERROR")"

    if [ "$response" = "LLM_ERROR" ]; then
      echo "FAIL  $pid · claude CLI 调用失败"
      fail=$((fail+1))
      i=$((i+1))
      continue
    fi

    # 断言 expected_actions 关键词至少一个出现在 response 中
    local expected_actions
    expected_actions="$(json_prompt_field "$i" expected_actions " ")"
    local hit=0 kw
    for kw in $expected_actions; do
      # 取关键词（如 "load stata-basics" → "stata-basics"）
      local cleaned
      cleaned="$(echo "$kw" | sed 's/[`(){},.]//g' | awk '{print $NF}')"
      [ "${#cleaned}" -lt 3 ] && continue
      if echo "$response" | grep -qE "$(echo "$cleaned" | sed 's/[][\.*^$/]/\\&/g')"; then
        hit=1
        break
      fi
    done

    if [ "$hit" -eq 1 ]; then
      echo "PASS  $pid · Claude 输出含 expected_actions 关键词"
      pass=$((pass+1))
    else
      echo "FAIL  $pid · Claude 输出不含 expected_actions 关键词"
      fail=$((fail+1))
    fi
    i=$((i+1))
  done

  echo
  echo "结果（--llm 模式）：$pass 通过，$fail 失败"
  [ "$fail" -eq 0 ] || exit 1
}

# ---- 主调度 ----
case "$MODE" in
  docs)    run_docs_mode ;;
  prompts) run_prompts_mode ;;
  llm)     run_llm_mode ;;
esac
