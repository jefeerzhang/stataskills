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
#   1. skill 事实只从实际 `stata-*/SKILL.md` 派生；每个 skill 经 target registry
#      解析出的 verify do-file 必须存在，反向孤儿 verify 仅允许已登记 delegate
#   2. docs/run-stata.md 首行计数「N 份」与动态 skill 数一致
#   3. data/agis6/*.dta 数量与 manifest 登记条数一致
#   4. manifest-extra.txt 与 data/*/ 下扩展 .dta 双向一致
#   5. demo/dofiles 与 demo/logs 动态计数一致且同名配对
#   6. 每份 SKILL.md 含可编号的「运行 Stata 的方式」标题；selection / identification
#      首个 Stata fence 的第一条可执行语句必须是 `version 19.5`
#   7. 扩展节「（扩展，教材未覆盖）」的关键词出现在 frontmatter description
#   8. 所有 SKILL.md 使用可编号的「关键陷阱速查」标题
#   9. demo↔verify 覆盖矩阵（ADR-0002）：demo 必有 verify；verify 无 demo 仅报告 debt
#   10. test-prompts.json 与动态 skill 集合双向一致
#   11. README 的 skill / target / ADR / 数据 / PNG / do-file / log / prompt 声明
#       必须存在并等于动态 facts
#   12. README hero 的 skill / target 声明及 skills.sh badge 集合与动态 skill 集合一致
#   13. 每个 verify-*.do 的 VERIFY CONTRACT、skill 字段和 data 路径有效
#   14. verify-*.do 社区包 contract（#26）：登记表 × 前置 probe × sentinel 分类 × ownership
#   15. 事故锁（#29 C1）：发现并聚合 verify/claims/*.sh——单 skill / 单文档的历史
#       事故锁与它守护的文档同地演进，不再杂居本文件
#   16. ADR-0004 与 target plan 委托 / ownership 交叉验证（#27 / #29 C2）；
#       委托名单只从 plan 派生，不手抄第二份
#
# facts（供人工比对，不自动断言）：各 skill 陷阱条目数、verify↔demo debt、
# verify-*.do assert 覆盖率。README/CITATION 的自由散文不做泛数字扫描。
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$VERIFY_DIR/.." && pwd)"

# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/targets.sh"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/contract.sh"

count() {  # count <glob...>：数匹配文件数（无匹配返回 0）
  local n=0 f
  for f in "$@"; do
    [ -e "$f" ] && n=$((n+1))
  done
  echo "$n"
}

# ---- facts：文件系统真相；skill 的唯一来源是实际 SKILL.md ----
SKILL_FILES=()
TARGET_ENTRIES=()
for skill_file in "$REPO_ROOT"/stata-*/SKILL.md; do
  [ -f "$skill_file" ] || continue
  SKILL_FILES+=("$skill_file")
  skill_name="$(basename "$(dirname "$skill_file")")"
  TARGET_ENTRIES+=("verify-${skill_name#stata-}")
done
ACTUAL_SKILLS="$(for skill_file in "${SKILL_FILES[@]}"; do basename "$(dirname "$skill_file")"; done | sort -u)"
N_SKILLS=${#SKILL_FILES[@]}
N_TARGETS=${#TARGET_ENTRIES[@]}
N_VERIFY=$(count "$REPO_ROOT"/verify/verify-*.do)   # 原始 verify-*.do 计数（含委托脚本），仅供 facts 展示
N_ADR=$(count "$REPO_ROOT"/docs/adr/*.md)
N_DTA=$(contract_manifest_file_count agis6)
N_MANIFEST=$(contract_manifest_entry_count agis6)
N_DEMO_DO=$(count "$REPO_ROOT"/demo/dofiles/*.do)
N_DEMO_LOG=$(count "$REPO_ROOT"/demo/logs/*.log)
N_DEMO_PNG=$(count "$REPO_ROOT"/demo/output/*.png)

echo "facts: skills=${N_SKILLS} targets=${N_TARGETS} verify_files=${N_VERIFY} adr=${N_ADR} dta=${N_DTA} manifest=${N_MANIFEST} demo_do=${N_DEMO_DO} demo_log=${N_DEMO_LOG} demo_png=${N_DEMO_PNG}"

# ---- 1. skill ↔ 验证入口一一对应：每个 skill 经 target plan 解析 owner /
#      do-file，且该 do-file 存在；反向，每个 verify-*.do 要么是某 skill
#      入口的 do-file、要么是 plan 登记的委托（delegate），否则为孤儿。
#      （#23：不拆空格分隔 registry 字符串；delegate/owner 全走 plan API。）----
entry_dofs=""
delegates=""
while IFS= read -r d; do
  [ -n "$d" ] || continue
  delegates="${delegates:+$delegates }$d"
done < <(targets_plan_each_delegate)
for skill_file in "${SKILL_FILES[@]}"; do
  name="$(basename "$(dirname "$skill_file")")"   # stata-<name>
  entry="verify-${name#stata-}"
  expected_owner="${name#stata-}"
  got_owner="$(targets_plan_owner "$entry")"
  if [ "$got_owner" != "$expected_owner" ]; then
    bad "target plan owner 漂移：${entry} 期望 ${expected_owner}，得 ${got_owner}"
  fi
  # 一个入口可委托多个 do-file；经 plan each_dofile 按行登记并检查存在。
  while IFS= read -r dof; do
    [ -n "$dof" ] || continue
    entry_dofs="${entry_dofs} ${dof}"
    [ -f "$VERIFY_DIR/$dof.do" ] || bad "缺验证脚本：verify/$dof.do（对应 ${name}）"
  done < <(targets_plan_each_dofile "$entry")
done
for d in "$REPO_ROOT"/verify/verify-*.do; do
  [ -e "$d" ] || continue
  b="$(basename "$d" .do)"
  case " ${entry_dofs} " in
    *" ${b} "*) continue ;;
  esac
  if targets_plan_is_delegate "$b"; then
    continue
  fi
  bad "孤儿 verify 脚本：verify/${b}.do（非任何 skill 入口，也非注册表委托）"
done
ok "skill ↔ verify 入口映射完整（委托：${delegates:-无}）"

# ---- 2. docs/run-stata.md 首行「N 份」与 skill 数一致 ----
doc_n=$(grep -oE '^[0-9]+ 份' "$REPO_ROOT/docs/run-stata.md" | head -1 | cut -d' ' -f1)
if [ "${doc_n:-0}" -eq "$N_SKILLS" ]; then
  ok "docs/run-stata.md「${doc_n} 份」与 skill 数（${N_SKILLS}）一致"
else
  bad "docs/run-stata.md 写「${doc_n:-无} 份」但实际有 ${N_SKILLS} 个 skill"
fi

# ---- 3. .dta 数量与 manifest 条数一致（双向一致性经 contract_manifest_report，
#     由 run-verify --static 深查）----
if [ "$N_DTA" -eq "$N_MANIFEST" ]; then
  ok "data/agis6/*.dta（${N_DTA}）与 manifest 条数（${N_MANIFEST}）一致"
else
  bad ".dta 数（${N_DTA}）≠ manifest 条数（${N_MANIFEST}）"
fi

# ---- 4. 扩展清单 manifest-extra.txt 与 data/*/ 下 .dta 双向一致性 ----
# 计数与漂移都经 contract.sh 的 manifest seam（#29 C3）；本文件不再 grep 清单
# 或 find 数据树。extra 面漂移含 missing_file / unlisted_file / duplicate_entry。
MANIFEST_EXTRA="$REPO_ROOT/data/manifest-extra.txt"
if [ -f "$MANIFEST_EXTRA" ]; then
  N_MANIFEST_EXTRA=$(contract_manifest_entry_count extra)
  N_EXTRA_DTA=$(contract_manifest_file_count extra)
  if [ "$N_MANIFEST_EXTRA" -eq "$N_EXTRA_DTA" ]; then
    ok "manifest-extra 条数（${N_MANIFEST_EXTRA}）与 data/*/.dta 数（${N_EXTRA_DTA}）一致"
  else
    bad "manifest-extra 条数（${N_MANIFEST_EXTRA}）≠ data/*/.dta 数（${N_EXTRA_DTA}）"
  fi
  extra_drift="$(contract_manifest_report | grep -E '^(missing_file|unlisted_file|duplicate_entry):extra/' | tr '\n' ' ')"
  if [ -n "$extra_drift" ]; then
    bad "manifest-extra 漂移：${extra_drift}"
  else
    ok "manifest-extra 每个条目均有对应 .dta 文件（无 missing/unlisted/duplicate）"
  fi
else
  ok "manifest-extra.txt 不存在（跳过扩展清单验证）"
fi

# ---- 5. demo dofiles 与 logs 数量一致且同名配对 ----
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

# ---- 6. SKILL 运行章节与 version 规则 ----
for s in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$s")")"
  if grep -qE '^## ([0-9]+\. )?运行 Stata 的方式' "$s"; then
    ok "${skill_name} 含「运行 Stata 的方式」章节"
  else
    bad "${skill_name}/SKILL.md 缺「运行 Stata 的方式」章节（独立分发须自带运行规矩）"
  fi
  case "$skill_name" in
    stata-selection|stata-identification)
      first_stata_statement=$(awk '
        /^```stata[[:space:]]*$/ { in_stata=1; next }
        in_stata && /^```/ { exit }
        in_stata {
          line=$0
          sub(/^[[:space:]]+/, "", line)
          if (line == "" || line ~ /^\*/ || line ~ /^\/\//) next
          print line
          exit
        }
      ' "$s")
      if [ "$first_stata_statement" = "version 19.5" ]; then
        ok "${skill_name} 首个 Stata fence 以 version 19.5 开始"
      else
        bad "${skill_name}/SKILL.md 首个 Stata fence 的第一条可执行语句不是 version 19.5（实际：${first_stata_statement:-无}）"
      fi
      ;;
  esac
done

# ---- 7. 扩展节触发词完整性：「（扩展，教材未覆盖）」的关键词须出现在 frontmatter ----
for s in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$s")")"
  desc=$(sed -n '1,/^---$/p' "$s" | grep '^description:')
  while IFS= read -r line; do
    # 从标题中提取关键词：去掉编号和修饰语，取反引号包裹的词或冒号后的首词
    kw=$(echo "$line" | sed 's/^##[[:space:]]*[0-9.]*[[:space:]]*//' | sed 's/（.*//')
    # 优先取反引号包裹的词
    # shellcheck disable=SC2016  # 反引号是 Markdown 字面分隔符，不是命令替换
    kw_backtick=$(echo "$kw" | grep -oE '`[^`]+`' | head -1 | tr -d '`')
    if [ -n "$kw_backtick" ]; then
      kw_clean="$kw_backtick"
    else
      kw_clean=$(echo "$kw" | sed 's/.*：//' | sed 's/^[[:space:]]*//' | awk '{print $1}')
    fi
    [ -z "$kw_clean" ] && continue
    if echo "$desc" | grep -qi "$kw_clean"; then
      ok "${skill_name} 扩展节关键词「${kw_clean}」已录入 frontmatter"
    else
      bad "${skill_name} 扩展节「${kw_clean}」未出现在 frontmatter description"
    fi
  done < <(grep '（扩展，教材未覆盖）' "$s" 2>/dev/null)
done

# ---- 8. 陷阱节标题统一：所有 SKILL.md 必须有「关键陷阱速查」（允许编号） ----
for s in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$s")")"
  if grep -qE '^## ([0-9]+\. )?关键陷阱速查' "$s"; then
    ok "${skill_name} 陷阱节标题统一（关键陷阱速查）"
  else
    bad "${skill_name}/SKILL.md 陷阱节标题不统一（期望「关键陷阱速查」）"
  fi
done

# ---- facts（供人工比对）：各 skill 陷阱条目数 ----
echo "facts: 各 skill 陷阱条目数"
for s in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$s")")"
  # 计数陷阱节下的条目：以 "- " 或数字编号开头的行
  pitfall_count=$(sed -n '/关键陷阱速查/,/^## /p' "$s" | grep -cE '^[[:space:]]*(-|\*|[0-9]+\.)[[:space:]]')
  echo "  ${skill_name}: ${pitfall_count} 条"
done

# ---- 9. demo↔verify 覆盖矩阵（ADR-0002）----
# ADR-0002 把 demo 定为独立全景层（第四层），不强制每个 skill 同时有 verify + demo，
# 但允许"扩展节按需补 demo"。缺口（verify/demo 单边）必须显式标记为可接受的 debt，
# 而非静默通过 CI。此处不覆盖 verify 缺 demo 的语义判定，由
# docs/adr/0002-demo-as-independent-panorama-layer.md 的"未来再评估"段承担。
# 本断言的"覆盖"指：每个 demo do-file 必须配 verify 脚本（demo 必有 verify），
# 而 verify 无 demo 只警告不 FAIL（demo 可后置；CI 不阻塞扩展节）。
demo_skills=()
for d in "$REPO_ROOT"/demo/dofiles/*.do; do
  [ -e "$d" ] || continue
  ds=$(grep '技能源' "$d" | head -1 | sed 's/.*stata-//;s/\/.*//')
  [ -z "$ds" ] && continue
  demo_skills+=("$ds")
done
# 硬断言：demo 必有 verify（避免 demo 漂移为孤立演示）
for ds in "${demo_skills[@]}"; do
  if [ ! -f "$VERIFY_DIR/verify-${ds}.do" ]; then
    bad "demo→verify 缺配对：demo/${ds} 有 demo do-file 但 verify/verify-${ds}.do 缺失"
  fi
done
# 软警告（不计入 fail）：verify 无 demo 仅 echo，提示 ADR-0002 debt
echo "facts: verify↔demo 覆盖矩阵（demo 必有 verify；verify 可无 demo，按 ADR-0002）"
for s in "${SKILL_FILES[@]}"; do
  name="$(basename "$(dirname "$s")")"
  name="${name#stata-}"
  if ! printf '%s\n' "${demo_skills[@]}" | grep -qx "$name"; then
    echo "  ${name}: 有 verify 无 demo（ADR-0002 当前允许；扩展 demo 时需补）"
  fi
done
# 汇总：所有 demo 都有 verify 即视为覆盖
ok "demo→verify 配对完整（${#demo_skills[@]} 个 demo do-file 均有 verify 脚本）"

# ---- 10. test-prompts.json：Agent 行为回归测试集 ----
# 从实际 stata-*/SKILL.md 动态派生 skill 集合，与 prompt 覆盖双向比对：
# - JSON 合法（兼容 python3 / python；解释器缺失与 JSON 无效分别报错）
# - prompts 数组非空、含 skill 字段
# - 缺失或未知 skill 都 FAIL，不能靠修改固定数字伪造覆盖
TEST_PROMPTS="$REPO_ROOT/test-prompts.json"
PYTHON_BIN="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
if [ ! -f "$TEST_PROMPTS" ]; then
  bad "test-prompts.json 缺失：repo 根目录应有覆盖实际 ${N_SKILLS} 个 skill 的行为回归测试集"
elif [ -z "$PYTHON_BIN" ]; then
  bad "无法校验 test-prompts.json：需要 python3 或 python"
elif ! "$PYTHON_BIN" -m json.tool "$TEST_PROMPTS" >/dev/null 2>&1; then
  bad "test-prompts.json 不是合法 JSON"
else
  N_PROMPTS=$("$PYTHON_BIN" -c 'import json, sys; print(len(json.load(open(sys.argv[1], encoding="utf-8"))["prompts"]))' "$TEST_PROMPTS")
  ok "test-prompts.json 合法，含 ${N_PROMPTS} 条 prompt"
  if "$PYTHON_BIN" - "$REPO_ROOT" "$ACTUAL_SKILLS" <<'PY'
import json, os, sys
repo_root = sys.argv[1]
with open(os.path.join(repo_root, "test-prompts.json"), encoding="utf-8") as f:
    d = json.load(f)
actual = set(sys.argv[2].splitlines())
covered = set()
for p in d["prompts"]:
    for skill in p["skill"].replace("+", ",").split(","):
        covered.add(skill.strip())
missing = sorted(actual - covered)
unknown = sorted(covered - actual)
if missing or unknown:
    if missing:
        print(f"FAIL  test-prompts 未覆盖：{', '.join(missing)}", file=sys.stderr)
    if unknown:
        print(f"FAIL  test-prompts 含未知 skill：{', '.join(unknown)}", file=sys.stderr)
    sys.exit(1)
print(f"coverage: {len(d['prompts'])} prompts, {len(covered)} skills", file=sys.stderr)
PY
  then
    ok "test-prompts.json 与实际 ${N_SKILLS} 个 skill 双向一致（Python 详情见 stderr）"
  else
    bad "test-prompts.json 与实际 skill 集合不一致：见 stderr"
  fi
fi

# ---- 11. README 结构计数与文件系统事实一致性 ----
# 每类声明都必须存在且等于动态 facts；缺声明与错数字同样 FAIL。
README="$REPO_ROOT/README.md"
if [ ! -f "$README" ]; then
  bad "README.md 缺失（无法校验结构计数）"
else
  readme_drift=""
  check_readme_count() {
    local label="$1" pattern="$2" actual="$3" declared
    declared=$(grep -oE "$pattern" "$README" | head -1 | grep -oE '^[0-9]+' || true)
    if [ -z "$declared" ]; then
      readme_drift="${readme_drift} 缺 ${label} 声明;"
    elif [ "$declared" -ne "$actual" ]; then
      readme_drift="${readme_drift} ${label}：README 写 ${declared}，实际 ${actual};"
    fi
  }

  check_readme_count "skill 计数" '[0-9]+ 个 [Ss]kill[s]?' "$N_SKILLS"
  check_readme_count "verify target 计数" '[0-9]+ 个验证入口' "$N_TARGETS"
  check_readme_count "ADR 计数" '[0-9]+ ADR' "$N_ADR"
  check_readme_count "AGIS6 数据集计数" '[0-9]+ 个数据集' "$N_DTA"
  check_readme_count "demo PNG 计数" '[0-9]+ 张 (demo )?PNG' "$N_DEMO_PNG"
  check_readme_count "demo do-file 计数" '[0-9]+ (个 )?do-file' "$N_DEMO_DO"
  check_readme_count "demo log 计数" '[0-9]+ 个 (Stata )?log' "$N_DEMO_LOG"
  check_readme_count "prompt 计数" '[0-9]+ 条 (Agent|prompt)' "${N_PROMPTS:-0}"

  if [ -n "$readme_drift" ]; then
    bad "README 结构计数漂移（${readme_drift}）"
  else
    ok "README 结构计数一致（skills=${N_SKILLS}, targets=${N_TARGETS}, ADR=${N_ADR}, prompts=${N_PROMPTS}）"
  fi
fi

# ---- 12. README hero 区 + skills.sh badge 动态诚实性 ----
README="$REPO_ROOT/README.md"
if [ ! -f "$README" ]; then
  bad "README.md 缺失（无法校验 hero 区 + skills.sh badge）"
else
  hero_drift=""
  hero_block="$(head -10 "$README")"
  for banned in "7/7 verify" "8/8 verify" "9 个识别方法" "DID 唯一入口" "Stata DID 分析的唯一"; do
    if echo "$hero_block" | grep -qF "$banned"; then
      hero_drift="${hero_drift} hero 区含旧漂移措辞「${banned}」;"
    fi
  done
  echo "$hero_block" | grep -qF "${N_SKILLS} 个 Skill" || hero_drift="${hero_drift} hero 区缺动态 skill 声明「${N_SKILLS} 个 Skill」;"
  echo "$hero_block" | grep -qF "${N_TARGETS} 个验证入口" || hero_drift="${hero_drift} hero 区缺动态 target 声明「${N_TARGETS} 个验证入口」;"

  readme_badge_slugs="$(grep -oE 'skills\.sh-stata--[a-z][a-z-]*[a-z]' "$README" \
    | sed -e 's/skills\.sh-stata--//' -e 's/--/-/g' -e 's/^/stata-/' \
    | sort -u)"
  actual_slugs="$ACTUAL_SKILLS"
  missing_badge="$(comm -23 <(printf '%s\n' "$actual_slugs") <(printf '%s\n' "$readme_badge_slugs") | tr '\n' ' ')"
  extra_badge="$(comm -13 <(printf '%s\n' "$actual_slugs") <(printf '%s\n' "$readme_badge_slugs") | tr '\n' ' ')"
  [ -z "$missing_badge" ] || hero_drift="${hero_drift} skills.sh badge 缺: ${missing_badge};"
  [ -z "$extra_badge" ] || hero_drift="${hero_drift} skills.sh badge 多出: ${extra_badge};"

  pending_marks_count=$(grep -cE '\[(待注册|TODO: register)\]|\(pending registration\)' "$README" || true)
  pending_marks_count=${pending_marks_count:-0}
  live_marks_count=$(grep -cE '\[已上架\]' "$README" || true)
  live_marks_count=${live_marks_count:-0}
  badge_count=$(grep -cE 'skills\.sh/jefeerzhang' "$README" || true)
  badge_count=${badge_count:-0}
  if [ "$live_marks_count" -ne 0 ]; then
    hero_drift="${hero_drift} skills.sh badge 残留 [已上架] 标记=${live_marks_count}（上架后徽章为活链接，无需标记）;"
  fi
  if [ "$pending_marks_count" -ne 0 ] && [ "$pending_marks_count" -ne "$badge_count" ]; then
    hero_drift="${hero_drift} skills.sh 占位 badge=${badge_count}，待注册标记=${pending_marks_count}（须 0 或全量成对）;"
  fi

  if [ -n "$hero_drift" ]; then
    bad "README hero + skills.sh 漂移（${hero_drift}）"
  else
    ok "README hero + skills.sh 动态覆盖一致（${N_SKILLS} skills / ${badge_count} badges）"
  fi
fi

# ---- 13. verify-*.do I/O 契约：每个脚本必须有机器可读声明 ----
# 借鉴 luban 报告 P1 短板：原 do-file 自包含但无机器可读「这个脚本验证什么」声明。
# 契约格式：VERIFY CONTRACT 块由 contract.sh 解析（块边界 contract_block、
# 字段缺失 contract_missing_fields）；#25 穷尽 data contract
# （missing/stale declaration + missing/unlisted/ambiguous file）只经 contract_data_report。
# 本文件不再内联 sed 提取契约块或手抄字段名单（#29 C3）。
verify_drift=""
verify_total=0
verify_missing_contract=""
verify_bad_skill=""
verify_bad_data=""
verify_bad_format=""
verify_bad_exhaustive=""
for vdo in "$REPO_ROOT"/verify/verify-*.do; do
  [ -f "$vdo" ] || continue
  verify_total=$((verify_total + 1))
  vname=$(basename "$vdo" .do)
  cblock="$(contract_block "$vdo")"
  if [ -z "$cblock" ]; then
    verify_missing_contract="${verify_missing_contract} ${vname};"
    continue
  fi
  # 解析 4 字段（contract.sh 单一实现）
  # shellcheck disable=SC2034
  eval "$(contract_parse "$vdo")"
  v_skill="${CONTRACT_SKILL:-}"
  v_chapter="${CONTRACT_CHAPTER:-}"
  v_data="${CONTRACT_DATA:-}"
  v_checks="${CONTRACT_CHECKS:-}"
  if [ -z "$v_skill" ] || [ -z "$v_chapter" ] || [ -z "$v_data" ] || [ -z "$v_checks" ]; then
    verify_bad_format="${verify_bad_format} ${vname}(空字段);"
  fi
  if [ ! -d "$REPO_ROOT/$v_skill" ]; then
    verify_bad_skill="${verify_bad_skill} ${vname}→${v_skill};"
  fi
  # 穷尽 data contract：声明/字面/文件侧问题统一由 report 给出
  report="$(contract_data_report "$vdo")"
  if [ -n "$report" ]; then
    report_flat=$(printf '%s' "$report" | tr '\n' ' ')
    verify_bad_exhaustive="${verify_bad_exhaustive} ${vname}[${report_flat}];"
    # 兼容旧摘要字段：文件缺失类单独计入 bad_data
    if printf '%s\n' "$report" | grep -qE '^(missing_file|unlisted_file|ambiguous_basename):'; then
      verify_bad_data="${verify_bad_data} ${vname};"
    fi
  fi
  missing_fields="$(contract_missing_fields "$vdo")"
  if [ -n "$missing_fields" ]; then
    verify_bad_format="${verify_bad_format} ${vname}(缺字段:${missing_fields});"
  fi
done
[ -n "$verify_missing_contract" ] && verify_drift="${verify_drift} 无 VERIFY 契约:${verify_missing_contract}"
[ -n "$verify_bad_skill" ] && verify_drift="${verify_drift} skill 字段无对应目录:${verify_bad_skill}"
[ -n "$verify_bad_data" ] && verify_drift="${verify_drift} data 字段文件侧问题:${verify_bad_data}"
[ -n "$verify_bad_exhaustive" ] && verify_drift="${verify_drift} 穷尽 data contract:${verify_bad_exhaustive}"
[ -n "$verify_bad_format" ] && verify_drift="${verify_drift} 字段行缺失或为空:${verify_bad_format}"
if [ -n "$verify_drift" ]; then
  bad "verify-*.do 契约缺失或错误（共 ${verify_total} 个脚本）${verify_drift}"
else
  ok "verify-*.do 契约完整（${verify_total} 个脚本均有 4 字段 VERIFY CONTRACT 块，skill ↔ 目录 + 穷尽 data contract 对齐）"
fi

# ---- 14. 社区包 contract（#26 / ADR-0003）：登记表 × probe × sentinel × ownership ----
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/community.sh" || exit 1
community_drift=""
for vdo in "$REPO_ROOT"/verify/verify-*.do; do
  [ -f "$vdo" ] || continue
  vname=$(basename "$vdo" .do)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    community_drift="${community_drift} ${vname}:${line};"
  done < <(community_check_dofile "$vdo")
done
if [ -n "$community_drift" ]; then
  bad "verify-*.do 社区包 contract 失败（${community_drift}）"
else
  ok "verify-*.do 社区包 contract 完整（probe + sentinel 分类 + ownership，#26）"
fi

# ---- 15. 事故锁（incident claims）：按 owner 分居，发现式聚合 ----
# #29 C1：单 skill / 单文档的历史事故锁不再杂居在本文件里。每个 owner 一个
# 可独立运行、可独立回归的 claims 文件（verify/claims/*.sh），本检查器只负责
# 发现并聚合退出码；新增事故锁 = 加一个文件，不改本文件。红/绿 fixture 见
# verify/test-claims.sh（经 CLAIMS_REPO_ROOT 覆盖仓库根）。
claims_dir="$VERIFY_DIR/claims"
if [ -d "$claims_dir" ]; then
  claims_n=0
  for cf in "$claims_dir"/*.sh; do
    [ -f "$cf" ] || continue
    claims_n=$((claims_n + 1))
    cf_name="$(basename "$cf")"
    if claims_out="$(bash "$cf" 2>&1)"; then
      ok "事故锁通过：claims/${cf_name}"
    else
      bad "事故锁失败：claims/${cf_name}（bash verify/claims/${cf_name} 可见详情）"
      printf '%s\n' "$claims_out" | sed 's/^/      /'
    fi
  done
  [ "$claims_n" -gt 0 ] || bad "verify/claims/ 下无事故锁文件（至少应有一个）"
else
  bad "缺 verify/claims/ 目录（事故锁须有独立归属，不得回流本文件）"
fi

# ---- 16. assert 覆盖率 fact（非断言，供人工比对；与 stataskills "facts 不自动断言" 政策一致） ----
# 借鉴 luban 报告 P3：每个 verify-*.do 应有 assert 断言验证关键不变量；
# 部分脚本只依赖「跑完不报错」，部分含数值 assert；此处动态 print 事实，不 FAIL——
# 是否补 assert 由 verify 脚本维护者决定（教学型 verify 偏向 end-of-do exit 0）。
assert_total=0
assert_with=0
for vdo in "$REPO_ROOT"/verify/verify-*.do; do
  [ -f "$vdo" ] || continue
  assert_total=$((assert_total + 1))
  n=$(grep -cE '^[[:space:]]*assert[[:space:]]' "$vdo" || true)
  n=${n:-0}
  if [ "$n" -gt 0 ]; then assert_with=$((assert_with + 1)); fi
done
ok "verify-*.do assert 覆盖率 fact：${assert_with}/${assert_total} 脚本含 assert（教学型 verify 依赖 end-of-do exit 0；扩展为 P3 候选）"

# ---- 17. ADR-0004 与 target plan 委托交叉验证（#27 / #29 C2）----
# 委托名单的单一来源是 target plan（targets.sh 的 override 表）；本断言不再
# 手抄第二份名单（旧版在 :664 与 :671 各写一份），改为按 plan 派生逐项与
# ADR-0004 文本互查。测试 fixture 保留独立字面量（见 test-targets.sh）。
ADR4="$REPO_ROOT/docs/adr/0004-verification-target-registry.md"
adr4_drift=""
if [ ! -f "$ADR4" ]; then
  adr4_drift="缺 ADR-0004 文件;"
else
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    grep -q "$d" "$ADR4" || adr4_drift="${adr4_drift} ADR 缺 ${d};"
  done < <(targets_plan_each_delegate)
  grep -q 'targets_plan_owner' "$ADR4" || adr4_drift="${adr4_drift} ADR 缺 targets_plan_owner;"
  grep -qE 'targets_run_dofile|targets_delegates' "$ADR4" && adr4_drift="${adr4_drift} ADR 仍描述已删旧 API;"
fi
owner=$(targets_plan_owner verify-did-community)
[ "$owner" = "did-community" ] || adr4_drift="${adr4_drift} owner=$owner;"
if [ -n "$adr4_drift" ]; then
  bad "ADR-0004 / target plan 交叉验证失败：${adr4_drift}"
else
  ok "ADR-0004 与 target plan 委托 + ownership 一致（#27）"
fi

summary
