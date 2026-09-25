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

# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"

# ---- 1. 六个 locality 回归入口存在 ----
for f in \
  test-targets.sh \
  test-contract.sh \
  test-claims.sh \
  test-community.sh \
  test-prompt-corpus.sh \
  test-prompt-plan.sh \
  test-harness.sh \
  check-claims.sh \
  run-verify.sh \
  test-prompts.sh
do
  if [ -f "$VERIFY_DIR/$f" ]; then
    ok "回归入口存在：$f"
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
    ok "deep module：$f"
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
    ok "无旧 registry 调用：$f"
  fi
done

# ---- 4. 反模式：无平行 use 路径解析 ----
if grep -nE 'grep -oE .*\^use|awk.*print \$2' "$VERIFY_DIR/run-verify.sh" >/dev/null 2>&1; then
  bad "run-verify 仍有平行 use parser"
else
  ok "run-verify 无平行 use parser"
fi
if grep -nE 'contract_data_report' "$VERIFY_DIR/run-verify.sh" >/dev/null 2>&1 \
   && grep -nE 'contract_data_report' "$VERIFY_DIR/check-claims.sh" >/dev/null 2>&1; then
  ok "data readiness 经 contract_data_report"
else
  bad "data readiness 未统一走 contract_data_report"
fi
# #29 C3：manifest 双向一致性只经 contract_manifest_report；caller 无平行数据树遍历
if grep -q 'contract_manifest_report' "$VERIFY_DIR/run-verify.sh" \
   && grep -q 'contract_manifest_report' "$VERIFY_DIR/check-claims.sh" \
   && ! grep -q -- '-maxdepth 2' "$VERIFY_DIR/run-verify.sh" \
   && ! grep -q -- '-maxdepth 2' "$VERIFY_DIR/check-claims.sh"; then
  ok "manifest 解析经 contract_manifest_report（无平行数据树遍历，#29 C3）"
else
  bad "manifest 解析未统一走 contract_manifest_report（#29 C3）"
fi

# ---- 5. 反模式：judge 无第二份 package 名单 ----
if grep -nE 'COMMUNITY_PKGS=' "$VERIFY_DIR/lib/judge.sh" >/dev/null 2>&1; then
  bad "judge.sh 承载 package registry"
else
  ok "judge.sh 无 package registry"
fi
if grep -nE 'community_check_dofile' "$VERIFY_DIR/check-claims.sh" >/dev/null 2>&1; then
  ok "community contract 经 community_check_dofile"
else
  bad "claims 未接 community contract"
fi

# ---- 6. 反模式：mode 层不分支 adapter；corpus 模块无 jq 分支 ----
# #29 C4 后 prompt_corpus.sh 只有单一 canonical adapter（python）；此处锁
# 两层：test-prompts.sh 不得做 mode-level 分支，corpus 模块不得再有 jq 分支。
if grep -nE 'command -v jq|PROMPT_CORPUS_FORCE_ADAPTER|python3? -c' "$VERIFY_DIR/test-prompts.sh" >/dev/null 2>&1; then
  bad "test-prompts.sh 仍有 mode-level adapter 分支"
else
  ok "test-prompts.sh 无 mode-level adapter 分支"
fi
if grep -vE '^[[:space:]]*#' "$VERIFY_DIR/lib/prompt_corpus.sh" | grep -qE '\bjq\b'; then
  bad "prompt_corpus.sh 仍含 jq 分支（#29 C4 要求单一 canonical adapter）"
else
  ok "prompt_corpus.sh 无 jq 分支（单一 canonical adapter）"
fi

# ---- 7. ADR 语义锚点仍在（不重开）----
ADR3="$REPO_ROOT/docs/adr/0003-community-packages-as-first-class-verifiable-subjects.md"
ADR5="$REPO_ROOT/docs/adr/0005-keep-raw-verify-logs.md"
ADR7="$REPO_ROOT/docs/adr/0007-untrack-verify-raw-logs.md"
ADR6="$REPO_ROOT/docs/adr/0006-identification-four-pillars.md"
if [ -f "$ADR3" ] && grep -E -- '--community|OPTIONAL_MISSING|COMMUNITY_PACKAGE_MISSING' "$ADR3" >/dev/null 2>&1; then
  ok "ADR-0003 联网/package 模式锚点仍在"
else
  bad "ADR-0003 语义锚点缺失"
fi
if [ -f "$ADR5" ] && grep -E -- 'Superseded' "$ADR5" >/dev/null 2>&1 \
   && grep -E -- 'ADR-0007' "$ADR5" >/dev/null 2>&1; then
  ok "ADR-0005 已显式标注 Superseded → ADR-0007"
else
  bad "ADR-0005 取代关系未记录（应标 Superseded 并指向 ADR-0007）"
fi
if [ -f "$ADR7" ] && grep -E -- 'verify/\*\.log|取消跟踪|untrack' "$ADR7" >/dev/null 2>&1 \
   && grep -E -- 'VERIFY_MARKERS_REQUIRED' "$ADR7" >/dev/null 2>&1; then
  ok "ADR-0007 raw log 退库 + 声明式 marker 契约锚点在位"
else
  bad "ADR-0007 语义锚点缺失"
fi
# 反回归锁：log 不得重新回到 git 索引（否则 ADR-0007 被无声推翻）
if grep -qE '^verify/\*\.log$' "$REPO_ROOT/.gitignore" 2>/dev/null; then
  ok ".gitignore 覆盖 verify/*.log"
else
  bad ".gitignore 缺少 verify/*.log 规则"
fi
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  tracked_logs="$(git -C "$REPO_ROOT" ls-files 'verify/*.log' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$tracked_logs" = "0" ]; then
    ok "git 索引中无 verify/*.log（工作区副本不受影响）"
  else
    bad "有 $tracked_logs 份 verify/*.log 仍在 git 索引中（违反 ADR-0007）"
  fi
fi
if [ -f "$ADR6" ] && grep -E -- 'estimand|识别|pillar|RCT|RDD' "$ADR6" >/dev/null 2>&1; then
  ok "ADR-0006 识别路由/estimand 锚点仍在"
else
  bad "ADR-0006 语义锚点缺失"
fi

# ---- 8. DID ownership / plan / prompt plan / 事故锁 / 委托名单可观察锁 ----
if grep -qE 'DID method ownership|did_imputation' "$VERIFY_DIR/claims/did-community.sh" 2>/dev/null; then
  ok "claims/did-community.sh 含 DID method ownership 断言"
else
  bad "claims/did-community.sh 缺 DID ownership 断言（#29 C1）"
fi
if grep -q 'claims_dir=.*VERIFY_DIR/claims' "$VERIFY_DIR/check-claims.sh" \
   && [ -f "$VERIFY_DIR/test-claims.sh" ]; then
  ok "事故锁 seam：check-claims 发现式聚合 + test-claims 回归入口（#29 C1）"
else
  bad "事故锁 seam 不完整（#29 C1）"
fi
if grep -qE 'for d in verify-dynamic-panel|expect_d=' "$VERIFY_DIR/check-claims.sh"; then
  bad "check-claims 仍手抄委托名单（#29 C2）"
else
  ok "check-claims 委托名单经 plan 派生（#29 C2）"
fi
# #29 C7：skill 发现只经 targets_each_skill；测试文件复用 report.sh 报告协议
for f in run-verify.sh check-claims.sh test-prompts.sh; do
  if grep -q 'targets_each_skill' "$VERIFY_DIR/$f"; then
    ok "$f 经 targets_each_skill 发现 skill"
  else
    bad "$f 未接 targets_each_skill（#29 C7）"
  fi
done
for f in test-targets.sh test-contract.sh test-prompt-plan.sh test-community.sh \
         test-acceptance.sh test-claims.sh test-prompt-corpus.sh; do
  if grep -qE '^pass\(\) *\{' "$VERIFY_DIR/$f"; then
    bad "$f 仍自定义 pass() 协议（应用 report.sh 的 ok/bad）"
  else
    ok "$f 复用 report.sh 报告协议"
  fi
done
if grep -nE 'prompt_plan_each_target|self_test_prompt_plan' "$VERIFY_DIR/test-prompts.sh" >/dev/null 2>&1; then
  ok "prompts 含跨 skill plan 自测"
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
