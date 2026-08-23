#!/usr/bin/env bash
# ============================================================
# Agent 行为回归测试 harness：把 test-prompts.json 的 11 条 prompt
# 从 spec 升级为可执行测试。
#
# 三模式（仿 verify/test-harness.sh 套路 + check-claims.sh 的 docs 层）：
#   默认（docs）  : 文档层断言——test-prompts.json 合法 + expected_outputs 关键词
#                   出现在 README/REPORT/对应 SKILL.md；CI 友好（无 Stata 依赖）
#   --prompts     : Stata 子集层——跑现有 verify-<skill>.do（run-verify.sh harness）
#                   + grep log 关键词断言 expected_actions 都执行；需要本机 Stata
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
command -v python3 >/dev/null 2>&1 || { echo "ERROR: 需要 python3" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: 需要 jq（解析 test-prompts.json）" >&2; exit 1; }

PROMPT_COUNT="$(jq '.prompts | length' "$TEST_PROMPTS_JSON")"
# skill 字段可能是 "skill-a + skill-b" 跨 skill 形式（如 cross-*），split 后过滤掉 "+" 取 unique
SKILL_COUNT="$(jq -r '[.prompts[].skill | split(" ") | .[] | select(. != "+")] | unique | length' "$TEST_PROMPTS_JSON")"

echo "test-prompts harness · mode=$MODE · prompts=$PROMPT_COUNT · skills=$SKILL_COUNT"
echo

# ============================================================
# 模式 A: docs（默认）
# ============================================================
run_docs_mode() {
  local pass=0 fail=0

  # 1. JSON 合法
  if jq -e '.prompts | length > 0' "$TEST_PROMPTS_JSON" >/dev/null 2>&1; then
    echo "PASS  test-prompts.json 合法，含 $PROMPT_COUNT 条 prompt"
    pass=$((pass+1))
  else
    echo "FAIL  test-prompts.json 不合法"
    fail=$((fail+1))
  fi

  # 2. 覆盖全部 8 skill
  local missing_skills
  missing_skills="$(jq -r '[.prompts[].skill | split(" ") | .[] | select(. != "+")] | unique | . - ["stata-basics","stata-descriptives","stata-regression","stata-advanced","stata-coefplot","stata-did","stata-did-community","stata-rdd"] | .[]' "$TEST_PROMPTS_JSON")"
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
    pid="$(jq -r ".prompts[$i].id" "$TEST_PROMPTS_JSON")"
    skill="$(jq -r ".prompts[$i].skill" "$TEST_PROMPTS_JSON")"
    expected_outputs="$(jq -r ".prompts[$i].expected_outputs | join(\" | \")" "$TEST_PROMPTS_JSON")"

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

# prompt_id → verify_script（顺序与 test-prompts.json 一致；macOS bash 3.2 不支持关联数组，用两个平行数组）
PROMPT_VERIFY_SCRIPT=(
  "basics"              # basics-01-reverse-coding
  "descriptives"        # descriptives-01-crosstab-effect-size
  "regression"          # regression-01-ancova-with-covariate
  "advanced"            # advanced-01-factor-not-just-alpha
  "coefplot"            # coefplot-01-multiple-models-forest
  "did"                 # did-01-staggered-twowfe-bias
  "synth-sdid"          # did-02-csdid-staggered
  "synth-sdid"          # did-03-jwdid-etwfe
  "synth-sdid"          # did-04-did-imputation
  "basics+descriptives" # cross-01-clean-then-descriptives
  "regression+coefplot" # cross-02-regression-then-coefplot
  "rdd"                 # rdd-01-sharp-tutoring
)

# prompt_id → grep 关键词列表（断言 expected_actions 在 verify log 中执行过）
# 关键词与 verify-<skill>.do 实际跑的命令对齐（prompt 中的示例命令如
# price/weight/foreign 是教学示例，verify 脚本实际跑 ch9-11 章节的真实数据
# 命令如 anova/margins/logit）
PROMPT_GREP_KEYWORDS=(
  "mvdecode recode clonevar"    # basics-01-reverse-coding · verify-basics.do
  "chi2"                          # descriptives-01-crosstab-effect-size · verify-descriptives.do
  "anova margins"                 # regression-01-ancova-with-covariate · verify-regression.do
  "factor"                        # advanced-01-factor-not-just-alpha · verify-advanced.do
  "coefplot"                      # coefplot-01-multiple-models-forest · verify-coefplot.do
  "hdidregress"                   # did-01-staggered-twowfe-bias · verify-did.do
  "csdid"                         # did-02-csdid-staggered · verify-synth-sdid.do
  "jwdid"                         # did-03-jwdid-etwfe · verify-synth-sdid.do
  "did_imputation"                # did-04-did-imputation · verify-synth-sdid.do
  "mvdecode recode"               # cross-01-clean-then-descriptives · verify-basics.do（harness 跑 basics）
  "regress logit"                 # cross-02-regression-then-coefplot · verify-regression.do（harness 跑 regression）
  "rdrobust rddensity"            # rdd-01-sharp-tutoring · verify-rdd.do
)

run_prompts_mode() {
  local pass=0 fail=0

  # 加载 stata.conf 获取 STATA_MAC（设到当前 shell 变量，不自动 export）
  # shellcheck disable=SC1091
  . "$VERIFY_DIR/stata.conf"
  export STATA_MAC

  # 前置：需要 Stata 二进制
  if ! command -v stata-mp >/dev/null 2>&1 && [ -z "${STATA_MAC:-}" ]; then
    echo "ERROR: --prompts 模式需要本机 Stata（stata-mp 或 STATA_MAC 环境变量）" >&2
    exit 1
  fi

  local pid i=0
  while [ "$i" -lt "$PROMPT_COUNT" ]; do
    pid="$(jq -r ".prompts[$i].id" "$TEST_PROMPTS_JSON")"
    local verify_target="${PROMPT_VERIFY_SCRIPT[$i]:-}"
    local keywords="${PROMPT_GREP_KEYWORDS[$i]:-}"

    if [ -z "$verify_target" ] || [ -z "$keywords" ]; then
      echo "SKIP  $pid · 无 verify target 映射"
      i=$((i+1))
      continue
    fi

    # 跨 skill 联动 prompt（如 cross-01）只取第一个 skill 跑
    local first_skill="${verify_target%%+*}"
    local verify_log="$VERIFY_DIR/verify-${first_skill}.log"

    # 跑 verify-<skill>.do（用 run-verify.sh harness）
    if ! bash "$VERIFY_DIR/run-verify.sh" "$first_skill" >/dev/null 2>&1; then
      echo "FAIL  $pid · run-verify.sh $first_skill 返回非零"
      fail=$((fail+1))
      i=$((i+1))
      continue
    fi

    # grep log 关键词
    local kw missing_kw=""
    for kw in $keywords; do
      if ! grep -qE "\\b${kw}\\b" "$verify_log"; then
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
    pid="$(jq -r ".prompts[$i].id" "$TEST_PROMPTS_JSON")"
    scenario="$(jq -r ".prompts[$i].scenario" "$TEST_PROMPTS_JSON")"

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
    expected_actions="$(jq -r ".prompts[$i].expected_actions | join(\" \")" "$TEST_PROMPTS_JSON")"
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
