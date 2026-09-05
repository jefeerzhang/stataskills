#!/usr/bin/env bash
# ============================================================
# 整体验收：架构深化规格（#29 / parent #18）
#
# 证明六个 locality seams 均有可观察回归入口，且生产 caller 无
# 旧 registry / 平行 data parser / 第二份 package 名单 / mode-level
# adapter 分支残留。四套 exit-0 门禁由本脚本末尾提示；CI 分别跑。
#
# 用法：bash verify/test-acceptance.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$VERIFY_DIR/.." && pwd)"

fail=0
pass() { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; fail=$((fail + 1)); }

# ---- 1. 六个 locality 回归入口存在 ----
for f in \
  test-targets.sh \
  test-contract.sh \
  test-community.sh \
  test-prompt-corpus.sh \
  test-prompt-plan.sh \
  test-harness.sh \
  check-claims.sh \
  run-verify.sh \
  test-prompts.sh
do
  if [ -f "$VERIFY_DIR/$f" ]; then
    pass "回归入口存在：$f"
  else
    bad "缺回归入口：$f"
  fi
done

# ---- 2. deep modules 文件存在 ----
for f in \
  lib/targets.sh \
  lib/contract.sh \
  lib/community.sh \
  lib/prompt_corpus.sh \
  lib/prompt_plan.sh \
  lib/judge.sh
do
  if [ -f "$VERIFY_DIR/$f" ]; then
    pass "deep module：$f"
  else
    bad "缺 deep module：$f"
  fi
done

# ---- 3. 反模式：生产 caller 无旧空格 API 调用 ----
for f in run-verify.sh check-claims.sh test-prompts.sh; do
  if grep -nE '\$\(targets_run_dofile|\$\(targets_delegates|[^[:alnum:]_]targets_run_dofile\s*\(|[^[:alnum:]_]targets_delegates\s*\(' \
       "$VERIFY_DIR/$f" >/dev/null 2>&1; then
    bad "旧 registry 调用残留：$f"
  else
    pass "无旧 registry 调用：$f"
  fi
done

# ---- 4. 反模式：无平行 use 路径解析 ----
if grep -nE 'grep -oE .*\^use|awk.*print \$2' "$VERIFY_DIR/run-verify.sh" >/dev/null 2>&1; then
  bad "run-verify 仍有平行 use parser"
else
  pass "run-verify 无平行 use parser"
fi
if grep -nE 'contract_data_report' "$VERIFY_DIR/run-verify.sh" >/dev/null 2>&1 \
   && grep -nE 'contract_data_report' "$VERIFY_DIR/check-claims.sh" >/dev/null 2>&1; then
  pass "data readiness 经 contract_data_report"
else
  bad "data readiness 未统一走 contract_data_report"
fi

# ---- 5. 反模式：judge 无第二份 package 名单 ----
if grep -nE 'COMMUNITY_PKGS=' "$VERIFY_DIR/lib/judge.sh" >/dev/null 2>&1; then
  bad "judge.sh 承载 package registry"
else
  pass "judge.sh 无 package registry"
fi
if grep -nE 'community_check_dofile' "$VERIFY_DIR/check-claims.sh" >/dev/null 2>&1; then
  pass "community contract 经 community_check_dofile"
else
  bad "claims 未接 community contract"
fi

# ---- 6. 反模式：test-prompts mode 不分支 jq/python ----
# 允许 prompt_corpus.sh 内部选 adapter；禁止 test-prompts.sh 直接分支
if grep -nE 'command -v jq|PROMPT_CORPUS_FORCE_ADAPTER|python3? -c' "$VERIFY_DIR/test-prompts.sh" >/dev/null 2>&1; then
  bad "test-prompts.sh 仍有 mode-level adapter 分支"
else
  pass "test-prompts.sh 无 mode-level adapter 分支"
fi

# ---- 7. ADR 语义锚点仍在（不重开）----
ADR3="$REPO_ROOT/docs/adr/0003-community-packages-as-first-class-verifiable-subjects.md"
ADR5="$REPO_ROOT/docs/adr/0005-keep-raw-verify-logs.md"
ADR6="$REPO_ROOT/docs/adr/0006-identification-four-pillars.md"
if [ -f "$ADR3" ] && grep -E -- '--community|OPTIONAL_MISSING|COMMUNITY_PACKAGE_MISSING' "$ADR3" >/dev/null 2>&1; then
  pass "ADR-0003 联网/package 模式锚点仍在"
else
  bad "ADR-0003 语义锚点缺失"
fi
if [ -f "$ADR5" ] && grep -E -- 'raw|verify/\*\.log|不采纳' "$ADR5" >/dev/null 2>&1; then
  pass "ADR-0005 raw log 决策锚点仍在"
else
  bad "ADR-0005 语义锚点缺失"
fi
if [ -f "$ADR6" ] && grep -E -- 'estimand|识别|pillar|RCT|RDD' "$ADR6" >/dev/null 2>&1; then
  pass "ADR-0006 识别路由/estimand 锚点仍在"
else
  bad "ADR-0006 语义锚点缺失"
fi

# ---- 8. DID ownership / plan / prompt plan 可观察锁 ----
if grep -nE 'DID method ownership|did_imputation' "$VERIFY_DIR/check-claims.sh" >/dev/null 2>&1; then
  pass "claims 含 DID method ownership 断言"
else
  bad "claims 缺 DID ownership 断言"
fi
if grep -nE 'prompt_plan_each_target|self_test_prompt_plan' "$VERIFY_DIR/test-prompts.sh" >/dev/null 2>&1; then
  pass "prompts 含跨 skill plan 自测"
else
  bad "prompts 缺跨 skill plan 自测"
fi

echo ""
echo "四套 exit-0 门禁（须分别跑绿）："
echo "  bash verify/run-verify.sh --static"
echo "  bash verify/check-claims.sh"
echo "  bash verify/test-harness.sh"
echo "  bash verify/test-prompts.sh"
echo ""
if [ "$fail" -eq 0 ]; then
  echo "结果：全部通过（#29 结构验收）"
  exit 0
fi
echo "结果：${fail} 失败"
exit 1
