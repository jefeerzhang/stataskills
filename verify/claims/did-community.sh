#!/usr/bin/env bash
# ============================================================
# 事故锁：stata-did-community（#29 C1）
#
# 本文件承载 stata-did-community 的历史事故锁——每条都对应一次真实漂移，
# 与它守护的 SKILL.md / references 同地演进，不再杂居在 check-claims.sh 里。
# 可独立运行、独立回归：
#   bash verify/claims/did-community.sh
# 由 verify/check-claims.sh 发现式聚合（新增锁 = 加一个文件，不改聚合器）。
# CLAIMS_REPO_ROOT 可覆盖仓库根（供 test-claims.sh 造红 fixture）。
#
# 锁清单（每条先红后绿的历史见 CHANGELOG）：
#   1. 内部计数：frontmatter「N 个方法」== 正文每处「N 个社区包」
#   2. 详细方法参考表登记 trop.md 与 power-analysis-template.do
#   3. power-analysis-template.do 不得用浮点插值作 Stata 变量名
#   4. PR-A 关键词耐久：SA-IW / method(twostage) / Roth 2022 不得静默消失
#   5. TROP 陷阱只在主 SKILL.md（ADR-0001 陷阱四件套单一来源）
#   6. workflow-8step.md 不得引用 orphan SHA 3cae231
#   7. DID method ownership：did_imputation 详解只在索引目标 reference
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="${CLAIMS_REPO_ROOT:-$(cd "$VERIFY_DIR/.." && pwd)}"

# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"

DC_SKILL="$REPO_ROOT/stata-did-community/SKILL.md"
CSJ="$REPO_ROOT/stata-did-community/references/csdid-jwdid-imputation.md"
WF8="$REPO_ROOT/stata-did-community/references/workflow-8step.md"

# ---- 1. 内部计数：description 声明的方法数与正文所有「N 个社区包」一致 ----
# 背景：PR-A 把 description 从 9 改到 10 个方法，正文三处禁令「9 个社区包」漏改。
if [ -f "$DC_SKILL" ]; then
  desc_n=$(sed -n '1,/^---$/p' "$DC_SKILL" | grep '^description:' | grep -oE '[0-9]+ 个方法' | head -1 | grep -oE '^[0-9]+' || true)
  if [ -z "${desc_n:-}" ]; then
    bad "stata-did-community description 缺「N 个方法」计数声明"
  else
    body_drift=""
    while IFS= read -r m; do
      [ -n "$m" ] && [ "$m" -ne "$desc_n" ] && body_drift="${body_drift} 正文写 ${m} 个社区包;"
    done < <(grep -oE '[0-9]+ 个社区包' "$DC_SKILL" | grep -oE '^[0-9]+' | sort -u)
    if [ -n "$body_drift" ]; then
      bad "stata-did-community 计数漂移：description 为 ${desc_n} 个方法，但${body_drift}"
    else
      ok "stata-did-community 计数一致（description 与正文均 ${desc_n}）"
    fi
  fi
fi

# ---- 2. references 索引表登记 trop + power 模板（CONTRIBUTING 同步规矩）----
# 决策树/能力表已链到 trop.md / power-analysis-template.do，但「详细方法参考」表漏行
# 会让 Agent 只靠索引时找不到入口。
if [ -f "$DC_SKILL" ]; then
  DC_REF_INDEX_MISS=""
  # 只在「详细方法参考」表到下一 ## 之间查链接（避免误命中决策树正文）
  idx_block=$(awk '/^## 详细方法参考/{p=1} p && /^## / && !/^## 详细方法参考/{exit} p' "$DC_SKILL")
  echo "$idx_block" | grep -q 'references/trop\.md' || DC_REF_INDEX_MISS="${DC_REF_INDEX_MISS} trop.md;"
  echo "$idx_block" | grep -q 'power-analysis-template\.do' || DC_REF_INDEX_MISS="${DC_REF_INDEX_MISS} power-analysis-template.do;"
  if [ -n "$DC_REF_INDEX_MISS" ]; then
    bad "stata-did-community 详细方法参考表缺登记：${DC_REF_INDEX_MISS}"
  else
    ok "stata-did-community 详细方法参考表已登记 trop.md 与 power-analysis-template.do"
  fi
fi

# ---- 3. power-analysis-template.do ATT 扫描不得用浮点插值作 Stata 变量名 ----
# `gen rejected_`att'` 在 att=0.05 时展开为 rejected_0.05，点号非法，扫描段无法跑通。
POWER_TMPL="$REPO_ROOT/stata-did-community/references/power-analysis-template.do"
if [ -f "$POWER_TMPL" ]; then
  # shellcheck disable=SC2016  # 反引号是 Stata 宏字面量，不是命令替换
  if grep -nE 'rejected_`att'\''' "$POWER_TMPL" >/dev/null 2>&1 || grep -nE 'rejected_`att`' "$POWER_TMPL" >/dev/null 2>&1; then
    bad "power-analysis-template.do 用 rejected_\`att' 作变量名（浮点插值含点号，Stata 非法）"
  else
    ok "power-analysis-template.do ATT 扫描未使用浮点插值变量名"
  fi
fi

# ---- 4. PR-A 关键词耐久锁（#5）：SA-IW / twostage / Roth 不得从文档 silently 消失 ----
pra_miss=""
if [ -f "$CSJ" ]; then
  grep -q 'SA-IW' "$CSJ" || pra_miss="${pra_miss} csdid-jwdid-imputation.md 缺 SA-IW;"
  grep -q 'method(twostage)' "$CSJ" || pra_miss="${pra_miss} csdid-jwdid-imputation.md 缺 method(twostage);"
else
  pra_miss="${pra_miss} csdid-jwdid-imputation.md 缺失;"
fi
if [ -f "$WF8" ]; then
  grep -q 'Roth 2022' "$WF8" || pra_miss="${pra_miss} workflow-8step.md 缺 Roth 2022;"
else
  pra_miss="${pra_miss} workflow-8step.md 缺失;"
fi
if [ -n "$pra_miss" ]; then
  bad "PR-A 关键词锁失败：${pra_miss}"
else
  ok "PR-A 关键词锁：SA-IW + method(twostage) + Roth 2022 均在位"
fi

# ---- 5. TROP 陷阱只在主 SKILL.md（ADR-0001 / 陷阱四件套单一来源）----
# trop.md 头部自述「陷阱统一收录在主 SKILL.md」；references 不得另开「关键陷阱」节。
TROP_MD="$REPO_ROOT/stata-did-community/references/trop.md"
trop_layer=""
if [ -f "$TROP_MD" ]; then
  if grep -qE '^## 关键陷阱' "$TROP_MD"; then
    trop_layer="${trop_layer} trop.md 仍有「## 关键陷阱」节;"
  fi
fi
if [ -f "$DC_SKILL" ]; then
  # 主文件关键陷阱速查须含至少一条可识别的 TROP 陷阱（四件套格式由既有陷阱标题断言覆盖）
  trap_block=$(awk '/^## 关键陷阱速查/{p=1} p && /^## / && !/^## 关键陷阱速查/{exit} p' "$DC_SKILL")
  # shellcheck disable=SC2016  # 反引号是 Markdown 字面分隔符，不是命令替换
  echo "$trap_block" | grep -qiE 'TROP|`trop`' || trop_layer="${trop_layer} SKILL.md 关键陷阱速查无 TROP 条目;"
fi
if [ -n "$trop_layer" ]; then
  bad "TROP 陷阱分层违规：${trop_layer}"
else
  ok "TROP 陷阱仅在主 SKILL.md（trop.md 无独立关键陷阱节）"
fi

# ---- 6. workflow-8step 不得引用 orphan SHA 3cae231 ----
# filter-branch / rebase 后该短 SHA 不再是 HEAD 祖先；留在文档会误导溯源。
if [ -f "$WF8" ]; then
  if grep -qE '\b3cae231\b' "$WF8"; then
    bad "workflow-8step.md 仍引用 orphan SHA 3cae231"
  else
    ok "workflow-8step.md 未引用 orphan SHA 3cae231"
  fi
fi

# ---- 7. DID method ownership（#19 / #18）：索引声明的方法详情必须在目标 reference ----
# 复现当前缺陷：主索引把 did_imputation 指向 csdid-jwdid-imputation.md，
# 但「### did_imputation 详解」实际落在 sdid.md——删除 sdid 会误删插补法能力。
CSJ_REF="$REPO_ROOT/stata-did-community/references/csdid-jwdid-imputation.md"
SDID_REF="$REPO_ROOT/stata-did-community/references/sdid.md"
own_drift=""
if [ -f "$CSJ_REF" ]; then
  if ! grep -qE '^###[[:space:]]+did_imputation' "$CSJ_REF"; then
    own_drift="${own_drift} csdid-jwdid-imputation.md 缺「### did_imputation」详解节;"
  fi
else
  own_drift="${own_drift} csdid-jwdid-imputation.md 缺失;"
fi
if [ -f "$SDID_REF" ] && grep -qE '^###[[:space:]]+did_imputation' "$SDID_REF"; then
  own_drift="${own_drift} sdid.md 仍承载 did_imputation 详解（索引所有权应仅保留 sdid）;"
fi
# 索引内容列声明 did_imputation 时，链接目标必须是错时 DID reference
if [ -f "$DC_SKILL" ]; then
  idx_block=$(awk '/^## 详细方法参考/{p=1} p && /^## / && !/^## 详细方法参考/{exit} p' "$DC_SKILL")
  idx_row=$(echo "$idx_block" | grep '`did_imputation`' | head -1 || true)
  if [ -n "$idx_row" ] && ! echo "$idx_row" | grep -q 'csdid-jwdid-imputation\.md'; then
    own_drift="${own_drift} 详细方法参考表中 did_imputation 未链到 csdid-jwdid-imputation.md;"
  fi
fi
if [ -n "$own_drift" ]; then
  bad "DID method ownership 漂移：${own_drift}"
else
  ok "DID method ownership：did_imputation 详解仅在索引目标 csdid-jwdid-imputation.md"
fi

summary
