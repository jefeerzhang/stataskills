#!/usr/bin/env bash
# ============================================================
# 文档断言检查器：把"数字"从免检特权里拿出来。
#
# 背景：README/CITATION/文档中的计数（skill 数、.dta 数、demo 规模）
# 历来靠人手同步，git 历史已出现三次批量漂移（见 CHANGELOG）。
# 本脚本从文件系统数出 facts，与文档/结构断言比对，不一致即 FAIL。
#
# 用法：
#   bash verify/check-claims.sh
#
# 核心集断言（每条均可 red-capable）：
#   1. 每个 skill 目录恰有一份 SKILL.md，且 verify/ 有同名 verify-*.do
#   2. docs/run-stata.md 首行计数「N 份」与 skill 数一致
#   3. data/agis6/*.dta 数量与 manifest 登记条数一致
#   4. demo/dofiles 与 demo/logs 数量一致且同名配对
#   5. 每份 SKILL.md 含「运行 Stata 的方式」章节标题（独立分发约束）
#
# 不检查 README/CITATION 散文里的措辞性计数（散文措辞多变，误报风险高）；
# 散文数字靠本脚本输出的 facts 供人工比对。
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$VERIFY_DIR/.." && pwd)"

pass=0
fail=0

ok()   { echo "PASS  $1"; pass=$((pass+1)); }
bad()  { echo "FAIL  $1"; fail=$((fail+1)); }

count() {  # count <glob...>：数匹配文件数（无匹配返回 0）
  local n=0 f
  for f in "$@"; do
    [ -e "$f" ] && n=$((n+1))
  done
  echo "$n"
}

# ---- facts：文件系统真相 ----
N_SKILLS=$(count "$REPO_ROOT"/stata-*/SKILL.md)
N_VERIFY=$(count "$REPO_ROOT"/verify/verify-*.do)   # 探针 zz* 在下方单独排除
N_DTA=$(count "$REPO_ROOT"/data/agis6/*.dta)
N_MANIFEST=$(grep -cE '^[^#[:space:]]' "$REPO_ROOT/data/manifest.txt")
N_DEMO_DO=$(count "$REPO_ROOT"/demo/dofiles/*.do)
N_DEMO_LOG=$(count "$REPO_ROOT"/demo/logs/*.log)
N_DEMO_PNG=$(count "$REPO_ROOT"/demo/output/*.png)

echo "facts: skills=${N_SKILLS} verify=${N_VERIFY} dta=${N_DTA} manifest=${N_MANIFEST} demo_do=${N_DEMO_DO} demo_log=${N_DEMO_LOG} demo_png=${N_DEMO_PNG}"

# ---- 1. skill ↔ verify 脚本一一对应（排除 test-harness 的 zz 探针）----
N_VERIFY_REAL=0
for d in "$REPO_ROOT"/verify/verify-*.do; do
  [ -e "$d" ] || continue
  b="$(basename "$d" .do)"
  case "$b" in verify-zz*) continue ;; esac
  N_VERIFY_REAL=$((N_VERIFY_REAL+1))
done
if [ "$N_VERIFY_REAL" -eq "$N_SKILLS" ]; then
  ok "skill 数（${N_SKILLS}）与 verify-*.do 数（${N_VERIFY_REAL}，排除 zz 探针）一致"
else
  bad "skill 数（${N_SKILLS}）≠ verify-*.do 数（${N_VERIFY_REAL}）：加 skill 须配 verify 脚本"
fi
for s in "$REPO_ROOT"/stata-*; do
  [ -d "$s" ] || continue
  name="$(basename "$s")"
  [ -f "$VERIFY_DIR/verify-${name#stata-}.do" ] || bad "缺验证脚本：verify/verify-${name#stata-}.do（对应 ${name}）"
done

# ---- 2. docs/run-stata.md 首行「N 份」与 skill 数一致 ----
doc_n=$(grep -oE '^[0-9]+ 份' "$REPO_ROOT/docs/run-stata.md" | head -1 | cut -d' ' -f1)
if [ "${doc_n:-0}" -eq "$N_SKILLS" ]; then
  ok "docs/run-stata.md「${doc_n} 份」与 skill 数（${N_SKILLS}）一致"
else
  bad "docs/run-stata.md 写「${doc_n:-无} 份」但实际有 ${N_SKILLS} 个 skill"
fi

# ---- 3. .dta 数量与 manifest 条数一致（双向一致性由 run-verify --static 深查）----
if [ "$N_DTA" -eq "$N_MANIFEST" ]; then
  ok "data/agis6/*.dta（${N_DTA}）与 manifest 条数（${N_MANIFEST}）一致"
else
  bad ".dta 数（${N_DTA}）≠ manifest 条数（${N_MANIFEST}）"
fi

# ---- 4. demo dofiles 与 logs 数量一致且同名配对 ----
if [ "$N_DEMO_DO" -eq "$N_DEMO_LOG" ]; then
  ok "demo dofiles（${N_DEMO_DO}）与 logs（${N_DEMO_LOG}）数量一致"
else
  bad "demo dofiles（${N_DEMO_DO}）≠ logs（${N_DEMO_LOG}）"
fi
for d in "$REPO_ROOT"/demo/dofiles/*.do; do
  [ -e "$d" ] || continue
  b="$(basename "$d" .do)"
  [ -f "$REPO_ROOT/demo/logs/${b}.log" ] || bad "demo log 缺失：demo/logs/${b}.log（对应 ${b}.do）"
done

# ---- 5. 每份 SKILL.md 含「运行 Stata 的方式」章节标题 ----
for s in "$REPO_ROOT"/stata-*/SKILL.md; do
  [ -e "$s" ] || continue
  if grep -q '^## 运行 Stata 的方式' "$s"; then
    ok "$(basename "$(dirname "$s")") 含「运行 Stata 的方式」章节"
  else
    bad "$(basename "$(dirname "$s")")/SKILL.md 缺「## 运行 Stata 的方式」章节（独立分发须自带运行规矩）"
  fi
done

echo
echo "结果：${pass} 通过，${fail} 失败"
[ "$fail" -eq 0 ]
