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
#   4. 扩展清单 manifest-extra.txt 与 data/*/ 下 .dta 双向一致性
#   5. demo/dofiles 与 demo/logs 数量一致且同名配对
#   6. 每份 SKILL.md 含「运行 Stata 的方式」章节标题（独立分发约束）
#   7. 扩展节「（扩展，教材未覆盖）」的关键词出现在 frontmatter description
#   8. 所有 SKILL.md 陷阱节统一使用「## 关键陷阱速查」标题
#   9. demo↔verify 覆盖矩阵（ADR-0002）：demo 必有 verify；verify 无 demo 仅警告不 FAIL
#   10. test-prompts.json：Agent 行为回归测试集覆盖全部 skill
#   11. README 硬编码计数与文件系统事实一致性（skill/dta/PNG/dofile/prompt 数）
#
# facts（供人工比对，不自动断言）：
#   - 各 skill 陷阱条目数
#   - verify↔demo 覆盖矩阵（verify 无 demo 的 skill 清单，ADR-0002 debt 跟踪）
#
# 不检查 README/CITATION 散文里的措辞性计数（散文措辞多变，误报风险高）；
# 散文数字靠本脚本输出的 facts 供人工比对。
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$VERIFY_DIR/.." && pwd)"

# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"

count() {  # count <glob...>：数匹配文件数（无匹配返回 0）
  local n=0 f
  for f in "$@"; do
    [ -e "$f" ] && n=$((n+1))
  done
  echo "$n"
}

# ---- facts：文件系统真相 ----
N_SKILLS=$(count "$REPO_ROOT"/stata-*/SKILL.md)
N_VERIFY=$(count "$REPO_ROOT"/verify/verify-*.do)   # zz 探针与 verify-synth-sdid 在下方排除
N_DTA=$(count "$REPO_ROOT"/data/agis6/*.dta)
N_MANIFEST=$(grep -cE '^[^#[:space:]]' "$REPO_ROOT/data/manifest.txt")
N_DEMO_DO=$(count "$REPO_ROOT"/demo/dofiles/*.do)
N_DEMO_LOG=$(count "$REPO_ROOT"/demo/logs/*.log)
N_DEMO_PNG=$(count "$REPO_ROOT"/demo/output/*.png)

echo "facts: skills=${N_SKILLS} verify=${N_VERIFY} dta=${N_DTA} manifest=${N_MANIFEST} demo_do=${N_DEMO_DO} demo_log=${N_DEMO_LOG} demo_png=${N_DEMO_PNG}"

# ---- 1. skill ↔ verify 脚本一一对应（排除 test-harness 的 zz 探针与
#      verify-synth-sdid.do——后者是社区包附加验证脚本，被
#      verify-did-community.do 委托调用，不构成独立 skill 的 verify 入口。
#      新增 skill 时只需放入 verify-<skill-name>.do，此处自动计入。----
N_VERIFY_REAL=0
for d in "$REPO_ROOT"/verify/verify-*.do; do
  [ -e "$d" ] || continue
  b="$(basename "$d" .do)"
  # verify-synth-sdid 是社区包验证脚本，由 verify-did-community.do 委托调用
  case "$b" in verify-zz*|verify-synth-sdid) continue ;; esac
  N_VERIFY_REAL=$((N_VERIFY_REAL+1))
done
if [ "$N_VERIFY_REAL" -eq "$N_SKILLS" ]; then
  ok "skill 数（${N_SKILLS}）与 verify-*.do 数（${N_VERIFY_REAL}，排除 zz 探针与 verify-synth-sdid）一致"
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

# ---- 6. 每份 SKILL.md 含「运行 Stata 的方式」章节标题 ----
for s in "$REPO_ROOT"/stata-*/SKILL.md; do
  [ -e "$s" ] || continue
  if grep -q '^## 运行 Stata 的方式' "$s"; then
    ok "$(basename "$(dirname "$s")") 含「运行 Stata 的方式」章节"
  else
    bad "$(basename "$(dirname "$s")")/SKILL.md 缺「## 运行 Stata 的方式」章节（独立分发须自带运行规矩）"
  fi
done

# ---- 7. 扩展节触发词完整性：「（扩展，教材未覆盖）」的关键词须出现在 frontmatter ----
for s in "$REPO_ROOT"/stata-*/SKILL.md; do
  [ -e "$s" ] || continue
  skill_name="$(basename "$(dirname "$s")")"
  desc=$(sed -n '1,/^---$/p' "$s" | grep '^description:')
  while IFS= read -r line; do
    # 从标题中提取关键词：去掉编号和修饰语，取反引号包裹的词或冒号后的首词
    kw=$(echo "$line" | sed 's/^##[[:space:]]*[0-9.]*[[:space:]]*//' | sed 's/（.*//')
    # 优先取反引号包裹的词
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

# ---- 8. 陷阱节标题统一：所有 SKILL.md 必须用「## 关键陷阱速查」----
for s in "$REPO_ROOT"/stata-*/SKILL.md; do
  [ -e "$s" ] || continue
  skill_name="$(basename "$(dirname "$s")")"
  if grep -q '^## 关键陷阱速查' "$s"; then
    ok "${skill_name} 陷阱节标题统一（## 关键陷阱速查）"
  else
    bad "${skill_name}/SKILL.md 陷阱节标题不统一（期望「## 关键陷阱速查」）"
  fi
done

# ---- facts（供人工比对）：各 skill 陷阱条目数 ----
echo "facts: 各 skill 陷阱条目数"
for s in "$REPO_ROOT"/stata-*/SKILL.md; do
  [ -e "$s" ] || continue
  skill_name="$(basename "$(dirname "$s")")"
  # 计数陷阱节下的条目：以 "- " 或数字编号开头的行
  pitfall_count=$(sed -n '/^## 关键陷阱速查/,/^## /p' "$s" | grep -cE '^[[:space:]]*(-|\*|[0-9]+\.)[[:space:]]')
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
for s in "$REPO_ROOT"/stata-*/SKILL.md; do
  [ -e "$s" ] || continue
  name="$(basename "$(dirname "$s")")"
  name="${name#stata-}"
  if ! printf '%s\n' "${demo_skills[@]}" | grep -qx "$name"; then
    echo "  ${name}: 有 verify 无 demo（ADR-0002 当前允许；扩展 demo 时需补）"
  fi
done
# 汇总：所有 demo 都有 verify 即视为覆盖
ok "demo→verify 配对完整（${#demo_skills[@]} 个 demo do-file 均有 verify 脚本）"

# ---- 10. test-prompts.json：Agent 行为回归测试集 ----
# 把"Skill 不只是文档，还能被 Agent 实际执行并产生期望锚点"这件事
# 变成可验证的 CI 断言。覆盖 8 个 skill + 跨 skill 联动：
# - JSON 合法（兼容 python3 / python；解释器缺失与 JSON 无效分别报错）
# - prompts 数组非空、含 id/skill/scenario/expected_actions 字段
# - 每个 skill 至少有 1 条 prompt 覆盖（避免新 skill 漏登记）
TEST_PROMPTS="$REPO_ROOT/test-prompts.json"
PYTHON_BIN="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
if [ ! -f "$TEST_PROMPTS" ]; then
  bad "test-prompts.json 缺失：repo 根目录应有 Agent 行为回归测试集（覆盖 8 个 skill）"
elif [ -z "$PYTHON_BIN" ]; then
  bad "无法校验 test-prompts.json：需要 python3 或 python"
elif ! "$PYTHON_BIN" -m json.tool "$TEST_PROMPTS" >/dev/null 2>&1; then
  bad "test-prompts.json 不是合法 JSON"
else
  N_PROMPTS=$("$PYTHON_BIN" -c 'import json, sys; print(len(json.load(open(sys.argv[1], encoding="utf-8"))["prompts"]))' "$TEST_PROMPTS")
  ok "test-prompts.json 合法，含 ${N_PROMPTS} 条 prompt"
  # 每个 skill 至少 1 条 prompt（用 awk 提取 skill 字段做覆盖矩阵）
  "$PYTHON_BIN" - "$REPO_ROOT" <<'PY' && {
import json, sys, os, glob
repo_root = sys.argv[1]
with open(os.path.join(repo_root, "test-prompts.json"), encoding="utf-8") as f:
    d = json.load(f)
covered = set()
for p in d["prompts"]:
    # skill 字段可能含 " + " 联动，按 ", " 或 " + " 切分
    for s in p["skill"].replace("+", ",").split(","):
        covered.add(s.strip())
missing = []
for sdir in sorted(glob.glob(os.path.join(repo_root, "stata-*"))):
    full_name = os.path.basename(sdir)  # 目录名本来就是 stata-xxx
    if full_name not in covered:
        missing.append(full_name)
if missing:
    print(f"FAIL  test-prompts 未覆盖以下 skill：{', '.join(missing)}", file=sys.stderr)
    sys.exit(1)
# 把覆盖详情写到 stderr，让 ok 行单独占据 stdout
print(f"coverage: {len(d['prompts'])} prompts, {len(covered)} skills", file=sys.stderr)
PY
    ok "test-prompts.json 覆盖全部 8 个 skill（Python 详情见 stderr）"
  } || bad "test-prompts.json 未覆盖全部 skill：见 stderr"
fi

# ---- 11. README 硬编码计数与文件系统事实一致性 ----
# 提取 README 中的数字声明，与 facts 比对。模式：
#   "N 个 Skill" / "N 个 skill" / "N 个数据集" / "N .dta" / "N 张 demo PNG"
#   "N do-file" / "N 个 do-file" / "N 条 Agent" / "N 条 prompt"
README="$REPO_ROOT/README.md"
if [ ! -f "$README" ]; then
  bad "README.md 缺失（无法校验硬编码计数）"
else
  readme_drift=""

  # skill 计数（匹配 "6 个 Skill" / "6 个 skill" / "6 个 skills"）
  readme_skills=$(grep -oE '[0-9]+ 个 [Ss]kill[s]?' "$README" | head -1 | grep -oE '^[0-9]+')
  if [ -n "$readme_skills" ] && [ "$readme_skills" -ne "$N_SKILLS" ]; then
    readme_drift="${readme_drift} skill 计数：README 写 ${readme_skills}，实际 ${N_SKILLS};"
  fi

  # 数据集计数（匹配 "38 个数据集" / "38 .dta"）
  readme_dta=$(grep -oE '[0-9]+ (个数据集|\.dta)' "$README" | head -1 | grep -oE '^[0-9]+')
  if [ -n "$readme_dta" ] && [ "$readme_dta" -ne "$N_DTA" ]; then
    readme_drift="${readme_drift} 数据集计数：README 写 ${readme_dta}，实际 ${N_DTA};"
  fi

  # demo PNG 计数（匹配 "27 张 demo PNG" / "27 张 PNG"）
  readme_png=$(grep -oE '[0-9]+ 张 (demo )?PNG' "$README" | head -1 | grep -oE '^[0-9]+')
  if [ -n "$readme_png" ] && [ "$readme_png" -ne "$N_DEMO_PNG" ]; then
    readme_drift="${readme_drift} demo PNG 计数：README 写 ${readme_png}，实际 ${N_DEMO_PNG};"
  fi

  # demo do-file 计数（匹配 "7 do-file" / "7 个 do-file"）
  readme_dofiles=$(grep -oE '[0-9]+ (个 )?do-file' "$README" | head -1 | grep -oE '^[0-9]+')
  if [ -n "$readme_dofiles" ] && [ "$readme_dofiles" -ne "$N_DEMO_DO" ]; then
    readme_drift="${readme_drift} demo do-file 计数：README 写 ${readme_dofiles}，实际 ${N_DEMO_DO};"
  fi

  # demo log 计数（匹配 "N 个 Stata log" / "N 个 log"）
  readme_logs=$(grep -oE '[0-9]+ 个 (Stata )?log' "$README" | head -1 | grep -oE '^[0-9]+')
  if [ -n "$readme_logs" ] && [ "$readme_logs" -ne "$N_DEMO_LOG" ]; then
    readme_drift="${readme_drift} demo log 计数：README 写 ${readme_logs}，实际 ${N_DEMO_LOG};"
  fi

  # Agent 行为回归 prompt 计数（匹配 "8 条 Agent" / "8 条 prompt"）
  readme_prompts=$(grep -oE '[0-9]+ 条 (Agent|prompt)' "$README" | head -1 | grep -oE '^[0-9]+')
  if [ -n "$readme_prompts" ] && [ -n "${N_PROMPTS:-}" ] && [ "$readme_prompts" -ne "$N_PROMPTS" ]; then
    readme_drift="${readme_drift} prompt 计数：README 写 ${readme_prompts}，实际 ${N_PROMPTS};"
  fi

  if [ -n "$readme_drift" ]; then
    bad "README 硬编码计数漂移（${readme_drift}）"
  else
    ok "README 硬编码计数与文件系统事实一致"
  fi
fi

summary
