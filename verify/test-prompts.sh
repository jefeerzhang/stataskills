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
#                   输出；需要 claude CLI，且 ANTHROPIC_API_KEY 或 OAuth 登录态
#                   （~/.claude/.credentials.json）任一可用；不具备时 SKIP 不报错
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
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_PROMPTS_JSON="$REPO_ROOT/test-prompts.json"

# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/targets.sh"

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
    jq '.prompts | if type == "array" then length else error("prompts must be an array") end' "$TEST_PROMPTS_JSON"
  else
    "$PYTHON_BIN" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); p=d.get("prompts"); assert isinstance(p,list), "prompts must be an array"; print(len(p))' "$TEST_PROMPTS_JSON"
  fi
}

expected_skills() {
  local skill_file
  for skill_file in "$REPO_ROOT"/stata-*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    basename "$(dirname "$skill_file")"
  done | sort -u
}

json_skill_values() {
  if [ "$JSON_BACKEND" = "jq" ]; then
    jq -r '.prompts[] | .skill | if type != "string" then error("skill must be a string") else split("+")[] | sub("^\\s+"; "") | sub("\\s+$"; "") | if length > 0 then . else error("skill entry must not be empty") end end' "$TEST_PROMPTS_JSON"
  else
    "$PYTHON_BIN" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); values=[]
for p in d["prompts"]:
 s=p.get("skill"); assert isinstance(s,str), "skill must be a string"
 for raw in s.split("+"):
  part=raw.strip(); assert part, "skill entry must not be empty"; values.append(part)
print("\n".join(values))' "$TEST_PROMPTS_JSON"
  fi
}

json_covered_skills() {
  json_skill_values | tr -d '\r' | sort -u
}

json_skill_count() {
  json_covered_skills | wc -l | tr -d '[:space:]'
}

json_missing_skills() {
  local expected covered
  expected="$(expected_skills | tr -d '\r')" || return 1
  covered="$(json_covered_skills)" || return 1
  comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$covered")
}

json_unknown_skills() {
  local expected covered
  expected="$(expected_skills | tr -d '\r')" || return 1
  covered="$(json_covered_skills)" || return 1
  comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$covered")
}

required_route_branches() {
  printf '%s\n' \
    gate-failure-return iv named-method-direct rct rdd router-entry \
    selection standard-did stop-causal synth-sdid | sort -u
}

json_route_branch_values() {
  if [ "$JSON_BACKEND" = "jq" ]; then
    jq -r '.prompts[] | select(has("route_branch")) | .route_branch | if type == "string" and length > 0 then . else error("route_branch must be a non-empty string") end' "$TEST_PROMPTS_JSON"
  else
    "$PYTHON_BIN" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); values=[]
for p in d["prompts"]:
 if "route_branch" in p:
  b=p["route_branch"]; assert isinstance(b,str) and b, "route_branch must be a non-empty string"; values.append(b)
print("\n".join(values))' "$TEST_PROMPTS_JSON"
  fi
}

json_route_branches() {
  json_route_branch_values | tr -d '\r' | sort -u
}

json_missing_route_branches() {
  local required actual
  required="$(required_route_branches | tr -d '\r')" || return 1
  actual="$(json_route_branches)" || return 1
  comm -23 <(printf '%s\n' "$required") <(printf '%s\n' "$actual")
}

json_unknown_route_branches() {
  local required actual
  required="$(required_route_branches | tr -d '\r')" || return 1
  actual="$(json_route_branches)" || return 1
  comm -13 <(printf '%s\n' "$required") <(printf '%s\n' "$actual")
}

json_duplicate_route_branches() {
  local values
  values="$(json_route_branch_values | tr -d '\r')" || return 1
  printf '%s\n' "$values" | sort | uniq -d
}

json_route_action_errors() {
  if [ "$JSON_BACKEND" = "jq" ]; then
    jq -r '.prompts[] | select(has("route_branch")) | select(if (has("expected_actions") | not) then true elif (.expected_actions | type) != "array" then true elif (.expected_actions | length) == 0 then true else any(.expected_actions[]; if type == "string" then (test("\\S") | not) else true end) end) | (.id // "<missing-id>")' "$TEST_PROMPTS_JSON"
  else
    "$PYTHON_BIN" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); bad=[]
for p in d["prompts"]:
 if "route_branch" not in p: continue
 a=p.get("expected_actions")
 if not isinstance(a,list) or not a or any(not isinstance(x,str) or not x.strip() for x in a): bad.append(p.get("id","<missing-id>"))
print("\n".join(bad))' "$TEST_PROMPTS_JSON"
  fi
}

json_branch_action_count() {
  local branch="$1"
  if [ "$JSON_BACKEND" = "jq" ]; then
    jq -r --arg branch "$branch" '[.prompts[] | select(.route_branch? == $branch)] | if length != 1 then error("locked route_branch must occur exactly once") elif (.[0].expected_actions | type) != "array" then error("expected_actions must be an array") else (.[0].expected_actions | length) end' "$TEST_PROMPTS_JSON"
  else
    "$PYTHON_BIN" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); matches=[p for p in d["prompts"] if p.get("route_branch")==sys.argv[2]]; assert len(matches)==1, "locked route_branch must occur exactly once"; a=matches[0].get("expected_actions"); assert isinstance(a,list), "expected_actions must be an array"; print(len(a))' "$TEST_PROMPTS_JSON" "$branch"
  fi
}

json_branch_action() {
  local branch="$1" index="$2"
  if [ "$JSON_BACKEND" = "jq" ]; then
    jq -r --arg branch "$branch" --argjson index "$index" '[.prompts[] | select(.route_branch? == $branch)] | if length != 1 then error("locked route_branch must occur exactly once") elif (.[0].expected_actions | type) != "array" then error("expected_actions must be an array") elif $index < 0 or $index >= (.[0].expected_actions | length) then error("expected_actions index out of range") elif (.[0].expected_actions[$index] | type) != "string" then error("expected action must be a string") else .[0].expected_actions[$index] end' "$TEST_PROMPTS_JSON"
  else
    "$PYTHON_BIN" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); matches=[p for p in d["prompts"] if p.get("route_branch")==sys.argv[2]]; assert len(matches)==1, "locked route_branch must occur exactly once"; a=matches[0].get("expected_actions"); assert isinstance(a,list), "expected_actions must be an array"; i=int(sys.argv[3]); assert 0<=i<len(a), "expected_actions index out of range"; assert isinstance(a[i],str), "expected action must be a string"; print(a[i])' "$TEST_PROMPTS_JSON" "$branch" "$index"
  fi
}

route_branch_semantics_ok() {
  local branch="$1" expected_count count index action anchors_var anchors anchor
  local action_0 action_1 action_2 action_3
  case "$branch" in
    router-entry)
      expected_count=3
      action_0='首先加载 stata-identification|identification-decision-tree.md'
      action_1='定义 treatment、outcome、unit、时间结构、处理时点、目标总体与 estimand'
      action_2='stop rules|制度或设计证据|不能凭列名或关键词跳分支'
      ;;
    rct)
      expected_count=3
      action_0='随机化完整性|停止在 RCT 分支'
      action_1='assignment|actual uptake|estimand|目标总体'
      action_2='attrition|consistency|SUTVA / no interference|noncompliance'
      ;;
    rdd)
      expected_count=3
      action_0='阈值规则|时间先后|running variable'
      action_1='连续性|无精确操纵|局部 positivity'
      action_2='转 stata-rdd'
      ;;
    iv)
      expected_count=3
      action_0='制度来源|outcome 通道'
      action_1='relevance|independence|exclusion|monotonicity|SUTVA'
      action_2='转 stata-regression|iv.md|iv-testing.md|iv-identification.md'
      ;;
    standard-did)
      expected_count=3
      action_0='面板政策公共 gate|no anticipation|SUTVA|稳定构成'
      action_1='parallel trends|overlap|composition|treatment timing'
      action_2='转 stata-did|不机械运行 synth / sdid'
      ;;
    synth-sdid)
      expected_count=4
      action_0='析取入口|不要求先通过 standard DID parallel trends 父 gate'
      action_1='synth|donor pool|pre-fit|同期冲击|placebo|推断条件'
      action_2='sdid|pre / post periods|untreated / not-yet-treated comparison units|单个或多个处理单位|多个处理日期|weighting|latent-factor / regularity|方法特定推断'
      action_3='转 stata-did-community'
      ;;
    selection)
      expected_count=3
      action_0='前序 RCT、RDD、IV 与面板政策设计均失败'
      action_1='pre-treatment|conditional exchangeability|positivity / overlap|SUTVA|ATET estimand'
      action_2='转 stata-selection'
      ;;
    stop-causal)
      expected_count=3
      action_0='记录哪个 gate 失败|缺少的数据支持或制度 / 设计证据'
      action_1='停止因果声明|禁止使用因果措辞|effect / impact / caused|描述 / 关联'
      action_2='当前数据可回答的问题|补充的设计证据|重新设计方案'
      ;;
    named-method-direct)
      expected_count=3
      action_0='直接进入 stata-selection|不先加载 stata-identification router'
      action_1='stata-selection 设计 gate|pre-treatment confounders|无未观测混杂|overlap'
      action_2='psmatch2.md|社区敏感性 / 兼容性对照'
      ;;
    gate-failure-return)
      expected_count=3
      action_0='standard DID parallel trends 失败后先检查同支柱 synth / sdid|不得直接转 selection'
      action_1='synth 与 sdid 两个析取入口均失败后才返回 stata-identification router'
      action_2='离开面板政策支柱后才检查横截面 selection|selection gate 也失败则 stop causal'
      ;;
    *) return 1 ;;
  esac

  if ! count="$(json_branch_action_count "$branch")" || [ "$count" -ne "$expected_count" ]; then
    return 1
  fi
  for ((index=0; index<expected_count; index++)); do
    if ! action="$(json_branch_action "$branch" "$index")"; then
      return 2
    fi
    anchors_var="action_$index"
    anchors="${!anchors_var}"
    while IFS= read -r anchor; do
      grep -Fq "$anchor" <<< "$action" || return 1
    done < <(tr '|' '\n' <<< "$anchors")
  done
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

if ! PROMPT_COUNT="$(json_prompt_count)"; then
  echo "ERROR: 无法解析 test-prompts.json 的 prompts 数组" >&2
  exit 1
fi
# skill 字段可能是 "skill-a + skill-b" 跨 skill 形式；两种后端都只按 "+" 分割并 trim 首尾。
if ! SKILL_COUNT="$(json_skill_count)"; then
  echo "ERROR: 无法解析 test-prompts.json 的 skill 字段" >&2
  exit 1
fi

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

  if self_test_verify_log_resolution; then
    echo "PASS  target registry 为普通/多委托 skill 解析正确日志集合"
    pass=$((pass+1))
  else
    fail=$((fail+1))
  fi

  # 2. 从实际 skill 目录动态审计双向 skill 集合与精确 route_branch 合同
  local missing_skills unknown_skills missing_branches unknown_branches duplicate_branches
  local bad_actions branch
  if ! missing_skills="$(json_missing_skills)"; then
    echo "FAIL  解析 skill 覆盖集失败"
    fail=$((fail+1))
  elif ! unknown_skills="$(json_unknown_skills)"; then
    echo "FAIL  解析 skill 覆盖集失败"
    fail=$((fail+1))
  elif [ -n "$missing_skills" ] || [ -n "$unknown_skills" ]; then
    [ -z "$missing_skills" ] || echo "FAIL  test-prompts 缺 skill: $missing_skills"
    [ -z "$unknown_skills" ] || echo "FAIL  test-prompts 含未知 skill: $unknown_skills"
    fail=$((fail+1))
  else
    echo "PASS  test-prompts skill 集合与实际目录双向一致"
    pass=$((pass+1))
  fi

  if ! missing_branches="$(json_missing_route_branches)"; then
    echo "FAIL  解析 route_branch 集合失败"
    fail=$((fail+1))
  elif ! unknown_branches="$(json_unknown_route_branches)"; then
    echo "FAIL  解析 route_branch 集合失败"
    fail=$((fail+1))
  elif ! duplicate_branches="$(json_duplicate_route_branches)"; then
    echo "FAIL  解析 route_branch 唯一性失败"
    fail=$((fail+1))
  elif [ -n "$missing_branches" ] || [ -n "$unknown_branches" ] || [ -n "$duplicate_branches" ]; then
    [ -z "$missing_branches" ] || echo "FAIL  test-prompts 缺 route_branch: $missing_branches"
    [ -z "$unknown_branches" ] || echo "FAIL  test-prompts 含未知 route_branch: $unknown_branches"
    [ -z "$duplicate_branches" ] || echo "FAIL  test-prompts 含重复 route_branch: $duplicate_branches"
    fail=$((fail+1))
  else
    echo "PASS  route_branch 与锁定集合双向一致且每个恰好一条"
    pass=$((pass+1))
  fi

  if ! bad_actions="$(json_route_action_errors)"; then
    echo "FAIL  解析 route_branch expected_actions 失败"
    fail=$((fail+1))
  elif [ -z "$bad_actions" ]; then
    echo "PASS  所有 route_branch prompt 含非空字符串 expected_actions"
    pass=$((pass+1))
  else
    echo "FAIL  route_branch expected_actions 无效: $bad_actions"
    fail=$((fail+1))
  fi

  while IFS= read -r branch; do
    if route_branch_semantics_ok "$branch"; then
      echo "PASS  route_branch=$branch · action 数量与逐项语义锚点"
      pass=$((pass+1))
    else
      echo "FAIL  route_branch=$branch · action 数量/位置/语义与 router 契约不符或解析失败"
      fail=$((fail+1))
    fi
  done < <(required_route_branches)

  # 3. 每条 prompt 的 expected_outputs 关键词必须在某处出现
  #    检查范围：README.md + demo/REPORT.md + 对应 SKILL.md + demo dofile logs
  #    关键词从 expected_outputs 字段提取核心术语
  local i=0
  while [ "$i" -lt "$PROMPT_COUNT" ]; do
    local pid skill expected_outputs
    if ! pid="$(json_prompt_field "$i" id)" || \
       ! skill="$(json_prompt_field "$i" skill)" || \
       ! expected_outputs="$(json_prompt_field "$i" expected_outputs " | ")"; then
      echo "FAIL  prompt[$i] · 解析 id/skill/expected_outputs 失败"
      fail=$((fail+1))
      i=$((i+1))
      continue
    fi

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

verify_logs_for_skill() {
  local skill="$1" base
  for base in $(targets_run_dofile "verify-$skill"); do
    printf '%s\n' "$VERIFY_DIR/$base.log"
  done
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

self_test_verify_log_resolution() {
  local actual expected
  actual="$(verify_logs_for_skill did-community)" || return 1
  expected=$(printf '%s\n' \
    "$VERIFY_DIR/verify-synth-sdid.log" \
    "$VERIFY_DIR/verify-power.log" \
    "$VERIFY_DIR/verify-trop.log")
  if [ "$actual" != "$expected" ]; then
    echo "FAIL  did-community 未按 target registry 解析三个委托日志"
    return 1
  fi

  actual="$(verify_logs_for_skill regression)" || return 1
  expected="$VERIFY_DIR/verify-regression.log"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL  普通 skill 未解析为自身单日志"
    return 1
  fi
}

run_prompts_mode() {
  local pass=0 fail=0
  self_test_log_matcher || return 1
  self_test_verify_log_resolution || return 1

  local pid skill keywords first_skill verify_log i=0
  local -a verify_logs
  while [ "$i" -lt "$PROMPT_COUNT" ]; do
    if ! pid="$(json_prompt_field "$i" id)" || \
       ! skill="$(json_prompt_field "$i" skill)" || \
       ! keywords="$(json_prompt_field "$i" verify_keywords " ")"; then
      echo "FAIL  prompt[$i] · 解析 id/skill/verify_keywords 失败"
      fail=$((fail+1))
      i=$((i+1))
      continue
    fi

    if [ -z "$keywords" ]; then
      echo "SKIP  $pid · 无 verify_keywords"
      i=$((i+1))
      continue
    fi

    # 目标名 = 首个 skill 去 "stata-" 前缀（registry 按此解析 do-file）；
    # 跨 skill 联动 prompt（如 cross-01）只跑第一个 skill。
    first_skill="${skill%% *}"
    first_skill="${first_skill#stata-}"
    mapfile -t verify_logs < <(verify_logs_for_skill "$first_skill")

    # 跑 verify-<skill>.do（用 run-verify.sh harness）
    if ! bash "$VERIFY_DIR/run-verify.sh" "$first_skill" >/dev/null 2>&1; then
      echo "FAIL  $pid · run-verify.sh $first_skill 返回非零"
      fail=$((fail+1))
      i=$((i+1))
      continue
    fi

    # 只认真实执行的命令；注释、cap which <package> 和输出文本不能充当覆盖。
    local kw missing_kw="" keyword_hit
    for kw in $keywords; do
      keyword_hit=0
      for verify_log in "${verify_logs[@]}"; do
        if [ -f "$verify_log" ] && log_has_executed_command "$kw" "$verify_log"; then
          keyword_hit=1
          break
        fi
      done
      if [ "$keyword_hit" -eq 0 ]; then
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
    echo "SKIP  --llm 模式：claude CLI 不存在；需要安装 Claude CLI（并用 API key 或 OAuth 登录）"
    echo "      安装：npm install -g @anthropic-ai/claude-code"
    exit 0
  fi

  if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ ! -f "$HOME/.claude/.credentials.json" ]; then
    echo "SKIP  --llm 模式：需要 ANTHROPIC_API_KEY 或 claude CLI OAuth 登录态（~/.claude/.credentials.json）"
    exit 0
  fi

  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "INFO  --llm 认证：ANTHROPIC_API_KEY"
  else
    echo "INFO  --llm 认证：claude CLI OAuth 登录态（~/.claude/.credentials.json）"
  fi

  local pass=0 fail=0 i=0
  while [ "$i" -lt "$PROMPT_COUNT" ]; do
    local pid scenario
    if ! pid="$(json_prompt_field "$i" id)" || \
       ! scenario="$(json_prompt_field "$i" scenario)"; then
      echo "FAIL  prompt[$i] · 解析 id/scenario 失败"
      fail=$((fail+1))
      i=$((i+1))
      continue
    fi

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
    if ! expected_actions="$(json_prompt_field "$i" expected_actions " ")"; then
      echo "FAIL  $pid · 解析 expected_actions 失败"
      fail=$((fail+1))
      i=$((i+1))
      continue
    fi
    local hit=0 kw
    for kw in $expected_actions; do
      # 逐词检查（join(" ") 后按空白拆分）：先用去标点字面串做固定串匹配；
      # 若去点号改变了词形（如 SKILL.md → SKILLmd），再用原词做正则，
      # 点号留作通配（'.' 未转义）兜底——修复 "*.md" 引用永远匹配不上的缺陷。
      local cleaned
      cleaned="$(echo "$kw" | sed 's/[`(){},.]//g')"
      [ "${#cleaned}" -lt 3 ] && continue
      if echo "$response" | grep -qF "$cleaned"; then
        hit=1
        break
      fi
      if [ "$cleaned" != "$kw" ] && echo "$response" | grep -qE "$(echo "$kw" | sed 's/[][\\*^$\/()]/\\&/g')"; then
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
