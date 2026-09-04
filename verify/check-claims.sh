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
#   14. verify-*.do 调用的社区包契约登记命令前必有 `capture/cap which` 探测
#       （ADR-0003 默认模式静默 PASS：缺包时打 sentinel 跳段，不得裸调用致 r(199)）
#   15. did-community 内部计数一致：frontmatter description 的「N 个方法」必须等于
#       正文每一处「N 个社区包」（扩包时正文禁令漏改的历史漂移，见 CHANGELOG）
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
N_DTA=$(count "$REPO_ROOT"/data/agis6/*.dta)
N_MANIFEST=$(grep -cE '^[^#[:space:]]' "$REPO_ROOT/data/manifest.txt")
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

# ---- 3. .dta 数量与 manifest 条数一致（双向一致性由 run-verify --static 深查）----
if [ "$N_DTA" -eq "$N_MANIFEST" ]; then
  ok "data/agis6/*.dta（${N_DTA}）与 manifest 条数（${N_MANIFEST}）一致"
else
  bad ".dta 数（${N_DTA}）≠ manifest 条数（${N_MANIFEST}）"
fi

# ---- 4. 扩展清单 manifest-extra.txt 与 data/*/ 下 .dta 双向一致性 ----
MANIFEST_EXTRA="$REPO_ROOT/data/manifest-extra.txt"
if [ -f "$MANIFEST_EXTRA" ]; then
  # 统计 manifest-extra 中的条目数（排除注释和空行）
  N_MANIFEST_EXTRA=$(grep -cE '^[^#[:space:]]' "$MANIFEST_EXTRA")
  # 统计 data/*/ 下（排除 agis6）的 .dta 文件数
  N_EXTRA_DTA=$(find "$REPO_ROOT/data" -maxdepth 2 -name "*.dta" -not -path "*/agis6/*" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$N_MANIFEST_EXTRA" -eq "$N_EXTRA_DTA" ]; then
    ok "manifest-extra 条数（${N_MANIFEST_EXTRA}）与 data/*/.dta 数（${N_EXTRA_DTA}）一致"
  else
    bad "manifest-extra 条数（${N_MANIFEST_EXTRA}）≠ data/*/.dta 数（${N_EXTRA_DTA}）"
  fi
  # 反向：每个 manifest-extra 条目必须在 data/*/ 下存在对应 .dta
  extra_missing=""
  while IFS= read -r ds; do
    ds="${ds%$'\r'}"
    case "$ds" in \#*|"") continue ;; esac
    found=0
    while IFS= read -r f; do
      [ -f "$f" ] && found=1 && break
    done < <(find "$REPO_ROOT/data" -maxdepth 2 -name "${ds}.dta" -not -path "*/agis6/*" 2>/dev/null)
    if [ "$found" -eq 0 ]; then
      extra_missing="${extra_missing} ${ds}.dta"
    fi
  done < <(cat "$MANIFEST_EXTRA")
  if [ -n "$extra_missing" ]; then
    bad "manifest-extra 登记但文件缺失：${extra_missing}"
  else
    ok "manifest-extra 每个条目均有对应 .dta 文件"
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
# 契约格式：前 10 行内含 6 行键值块（由 verify CONTRACT + data locator module 解析，#21）。
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/contract.sh"
verify_drift=""
verify_total=0
verify_missing_contract=""
verify_bad_skill=""
verify_bad_data=""
verify_bad_format=""
for vdo in "$REPO_ROOT"/verify/verify-*.do; do
  [ -f "$vdo" ] || continue
  verify_total=$((verify_total + 1))
  vname=$(basename "$vdo" .do)
  contract_block=$(head -10 "$vdo" | sed -n '/^\* ==== VERIFY CONTRACT ====$/,/^\* ============================$/p')
  if [ -z "$contract_block" ]; then
    verify_missing_contract="${verify_missing_contract} ${vname};"
    continue
  fi
  # 解析 4 字段（contract.sh 单一实现；旧手写 sed 路径收缩为调用）
  # shellcheck disable=SC2034
  eval "$(contract_parse "$vdo")"
  v_skill="${CONTRACT_SKILL:-}"
  v_chapter="${CONTRACT_CHAPTER:-}"
  v_data="${CONTRACT_DATA:-}"
  v_checks="${CONTRACT_CHECKS:-}"
  # 校验解析值非空：字段名在块里出现但值为空仍算坏契约（与下方 field_count 互补）
  if [ -z "$v_skill" ] || [ -z "$v_chapter" ] || [ -z "$v_data" ] || [ -z "$v_checks" ]; then
    verify_bad_format="${verify_bad_format} ${vname}(空字段);"
  fi
  # 校验 skill 字段 → 必须有对应 stata-xxx 目录
  if [ ! -d "$REPO_ROOT/$v_skill" ]; then
    verify_bad_skill="${verify_bad_skill} ${vname}→${v_skill};"
  fi
  # 校验 data 字段：; 分隔多个仓库数据集；每项经 data_locate 分类
  #   sysuse / sim - 非仓库，跳过路径存在性
  #   其它         - 必须能 locate 到现存文件（missing/unlisted 仍报文件侧问题）
  IFS=';' read -r -a data_items <<< "$v_data"
  for data_item in "${data_items[@]}"; do
    case "$data_item" in
      sysuse:*|sim:*|"")
        :  # 内置/模拟/未声明，跳过路径检查
        ;;
      *)
        # shellcheck disable=SC2034
        eval "$(data_locate "$data_item")"
        if [ ! -f "${DATA_PATH:-}" ]; then
          verify_bad_data="${verify_bad_data} ${vname}→${data_item};"
        fi
        ;;
    esac
  done
  # 校验 4 字段全有（非空）：用 grep 数 contract 块里出现几次字段名关键字
  field_count=0
  for fk in skill chapter data checks; do
    if echo "$contract_block" | grep -q "^\* $fk:"; then field_count=$((field_count+1)); fi
  done
  if [ "$field_count" -ne 4 ]; then
    verify_bad_format="${verify_bad_format} ${vname}(${field_count}/4 字段);"
  fi
done
[ -n "$verify_missing_contract" ] && verify_drift="${verify_drift} 无 VERIFY 契约:${verify_missing_contract}"
[ -n "$verify_bad_skill" ] && verify_drift="${verify_drift} skill 字段无对应目录:${verify_bad_skill}"
[ -n "$verify_bad_data" ] && verify_drift="${verify_drift} data 字段文件缺失:${verify_bad_data}"
[ -n "$verify_bad_format" ] && verify_drift="${verify_drift} 字段数 != 4:${verify_bad_format}"
if [ -n "$verify_drift" ]; then
  bad "verify-*.do 契约缺失或错误（共 ${verify_total} 个脚本）${verify_drift}"
else
  ok "verify-*.do 契约完整（${verify_total} 个脚本均有 4 字段 VERIFY CONTRACT 块，skill ↔ 目录 + data ↔ 文件对齐）"
fi

# ---- 14. 社区命令探测断言（ADR-0003）：verify-*.do 调用的每个社区包命令，
# 同文件更早位置必须已有 `capture which <pkg>` 探测。裸调用社区命令在缺包机器上
# 直接 r(199) 硬失败，违反「默认模式静默 PASS（cap which 风格）」决策。
# 清单 = 所有 verify-*.do 实际调用的社区包：did-community 契约包（verify-synth-sdid.do
# 头部 + trop / nprobust / did_had）+ reghdfe（verify-regression / verify-power 共用引擎）
# + ivreghdfe / rdrobust / rddensity / psmatch2 / ebalance / coefplot（各自 verify-*.do）。
# 探测行兼容 `capture which` 与缩写 `cap which`（verify-regression.do 先例）。
COMMUNITY_PKGS=(csdid drdid jwdid hdfe did_imputation reghdfe synth synth_runner sdid trop nprobust did_had coefplot ivreghdfe rdrobust rddensity psmatch2 ebalance)
probe_drift=""
for vdo in "$REPO_ROOT"/verify/verify-*.do; do
  [ -f "$vdo" ] || continue
  vname=$(basename "$vdo" .do)
  for pkg in "${COMMUNITY_PKGS[@]}"; do
    # 调用行：首词为包名的可执行语句行（剔除 capture which 探测行与纯注释行）
    call_ln=$(grep -nE "^[[:space:]]*(capture[[:space:]]+noisily[[:space:]]+|quietly[[:space:]]+)*${pkg}([[:space:]]|$)" "$vdo" | head -1 | cut -d: -f1)
    [ -z "$call_ln" ] && continue
    probe_ln=$(grep -nE "^[[:space:]]*(capture|cap)[[:space:]]+which[[:space:]]+${pkg}([[:space:]]|$)" "$vdo" | head -1 | cut -d: -f1)
    if [ -z "$probe_ln" ]; then
      probe_drift="${probe_drift} ${vname} 调用 ${pkg}（行 ${call_ln}）但全文无 capture/cap which 探测;"
    elif [ "$probe_ln" -gt "$call_ln" ]; then
      probe_drift="${probe_drift} ${vname} 的 capture/cap which ${pkg}（行 ${probe_ln}）晚于首次调用（行 ${call_ln}）;"
    fi
  done
done
if [ -n "$probe_drift" ]; then
  bad "verify-*.do 社区命令无探测（${probe_drift}）"
else
  ok "verify-*.do 社区命令均有前置 capture/cap which 探测（ADR-0003 静默 PASS）"
fi

# ---- 15. did-community 内部计数一致性：description 声明的方法数与正文所有「N 个社区包」一致 ----
# 背景：PR-A 把 description 从 9 改到 10 个方法，正文三处禁令「9 个社区包」漏改。
DC_SKILL="$REPO_ROOT/stata-did-community/SKILL.md"
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

# ---- 16. did-community references 索引表登记 trop + power 模板（CONTRIBUTING 同步规矩）----
# 决策树/能力表已链到 trop.md / power-analysis-template.do，但「详细方法参考」表漏行
# 会让 Agent 只靠索引时找不到入口。
DC_SKILL="$REPO_ROOT/stata-did-community/SKILL.md"
DC_REF_INDEX_MISS=""
if [ -f "$DC_SKILL" ]; then
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

# ---- 17. power-analysis-template.do ATT 扫描不得用浮点插值作 Stata 变量名 ----
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

# ---- 18. CHANGELOG [Unreleased] Added 不得保留已否决/错误的 PR-A/D 措辞 ----
# #15 明确不加「特征对照矩阵 TROP 列」；TROP = Triply Robust（非 Targeted Robust OP）；
# #1 AC 为 method(dr)/method(ipw)，不是 method(dripw)。
# Fixed 小节允许按原文记录已经修复的错误，否则修复台账本身会触发禁词误报。
CL="$REPO_ROOT/CHANGELOG.md"
if [ -f "$CL" ]; then
  cl_unreleased_added=$(awk '
    /^## \[Unreleased\]/{unreleased=1; next}
    unreleased && /^## \[/{exit}
    unreleased && /^### Added/{added=1; next}
    added && /^### /{exit}
    added
  ' "$CL")
  cl_bad=""
  echo "$cl_unreleased_added" | grep -q 'method(dripw)' && cl_bad="${cl_bad} method(dripw);"
  echo "$cl_unreleased_added" | grep -q 'Targeted Robust OP' && cl_bad="${cl_bad} Targeted Robust OP;"
  echo "$cl_unreleased_added" | grep -q '特征对照矩阵 TROP 列' && cl_bad="${cl_bad} 特征对照矩阵 TROP 列;"
  if [ -n "$cl_bad" ]; then
    bad "CHANGELOG [Unreleased] Added 含已否决/错误措辞：${cl_bad}"
  else
    ok "CHANGELOG [Unreleased] Added 无 dripw / Targeted Robust OP / 矩阵 TROP 列漂移"
  fi
fi

# ---- 19. PR-A 关键词耐久锁（#5）：SA-IW / twostage / Roth 不得从文档 silently 消失 ----
CSJ="$REPO_ROOT/stata-did-community/references/csdid-jwdid-imputation.md"
WF8="$REPO_ROOT/stata-did-community/references/workflow-8step.md"
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

# ---- 20. TROP 陷阱只在主 SKILL.md（ADR-0001 / 陷阱四件套单一来源）----
# trop.md 头部自述「陷阱统一收录在主 SKILL.md」；references 不得另开「关键陷阱」节。
TROP_MD="$REPO_ROOT/stata-did-community/references/trop.md"
DC_SKILL="$REPO_ROOT/stata-did-community/SKILL.md"
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

# ---- 21. workflow-8step 不得引用 orphan SHA 3cae231 ----
# filter-branch / rebase 后该短 SHA 不再是 HEAD 祖先；留在文档会误导溯源。
WF8="$REPO_ROOT/stata-did-community/references/workflow-8step.md"
if [ -f "$WF8" ]; then
  if grep -qE '\b3cae231\b' "$WF8"; then
    bad "workflow-8step.md 仍引用 orphan SHA 3cae231"
  else
    ok "workflow-8step.md 未引用 orphan SHA 3cae231"
  fi
fi

# ---- 22. DID method ownership（#19 / #18）：索引声明的方法详情必须在目标 reference ----
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
DC_SKILL="$REPO_ROOT/stata-did-community/SKILL.md"
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

# ---- 23. assert 覆盖率 fact（非断言，供人工比对；与 stataskills "facts 不自动断言" 政策一致） ----
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

summary
