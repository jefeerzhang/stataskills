# LLM 行为回归全量台账（T2）

> 日期：2026-08-27 09:33 · 环境：claude CLI 2.1.246 · 后端：MiniMax M3[1M]（~/.claude/settings.json 的 ANTHROPIC_BASE_URL=https://api.minimaxi.com/anthropic 与 ANTHROPIC_MODEL=MiniMax-M3[1M]）
> 执行：bash verify/test-prompts.sh --llm（T1 已修复认证闸口：API key 或 OAuth 登录态任一可用即放行）
> 判定算法：run_llm_mode 现状（每个 expected_action 取清洗后最后一个词做子串匹配，见下方「判定器已知弱点」）

**结果：25 通过 · 2 失败（共 27 条）**

**FAIL 列表：** basics-01-reverse-coding、cross-02-regression-then-coefplot

## 逐条 verdict

| id | skill | route_branch | verdict |
|---|---|---|---|
| basics-01-reverse-coding | stata-basics | - | FAIL 🔸 |
| descriptives-01-crosstab-effect-size | stata-descriptives | - | PASS |
| regression-01-ancova-with-covariate | stata-regression | - | PASS |
| regression-02-iv-command-selection | stata-regression | - | PASS |
| regression-03-iv-diagnostics-reading | stata-regression | - | PASS |
| regression-04-iv-identification-late | stata-regression | - | PASS |
| regression-05-iv-results-triangle | stata-regression | - | PASS |
| advanced-01-factor-not-just-alpha | stata-advanced | - | PASS |
| coefplot-01-multiple-models-forest | stata-coefplot | - | PASS |
| did-01-staggered-twowfe-bias | stata-did | - | PASS |
| did-02-csdid-staggered | stata-did-community | - | PASS |
| did-03-jwdid-etwfe | stata-did-community | - | PASS |
| did-04-did-imputation | stata-did-community | - | PASS |
| cross-01-clean-then-descriptives | stata-basics + stata-descriptives | - | PASS |
| cross-02-regression-then-coefplot | stata-regression + stata-coefplot | - | FAIL 🔸 |
| rdd-01-sharp-tutoring | stata-rdd | - | PASS |
| identification-01-router-entry | stata-identification | router-entry | PASS |
| identification-02-rct | stata-identification + stata-regression | rct | PASS |
| identification-03-rdd-route | stata-identification + stata-rdd | rdd | PASS |
| identification-04-iv-route | stata-identification + stata-regression | iv | PASS |
| identification-05-standard-did-route | stata-identification + stata-did | standard-did | PASS |
| identification-06-synth-sdid-route | stata-identification + stata-did-community | synth-sdid | PASS |
| identification-07-selection-route | stata-identification + stata-selection | selection | PASS |
| identification-08-stop-causal | stata-identification | stop-causal | PASS |
| identification-09-psmatch2-direct | stata-selection | named-method-direct | PASS |
| identification-10-did-gate-failure-return | stata-did + stata-did-community + stata-identification + stata-selection | gate-failure-return | PASS |
| selection-01-complete-atet | stata-selection | - | PASS |

## 判定器已知弱点（T3 分类依据）

1. **点号剥离**：清洗 sed 表达式会删掉点号，SKILL.md 变成 SKILLmd、references/iv.md 变成 references/ivmd、
   identification-decision-tree.md 变成 identification-decision-treemd——响应里写 SKILL.md 永远匹配不上，造成误伤。
2. **只取最后一个词**：长 action（如整条 Stata 命令）只检查末词，中间关键命令词没被检查；
   中文整句或含全角逗号的末词基本不可能命中。
3. **单次运行噪声**：T1 冒烟时 identification-01-router-entry FAIL，全量这次 PASS——同一 prompt 跨运行结果可变；
   FAIL 必须重放验证后才能定性为行为缺陷。

## T3 重放复核与归类（2026-08-27）

重放方法：对 FAIL 条目单独 claude -p 重放，响应保存于 .scratch/llm-smoke/*-replay.response；新旧两版 matcher 分别打分。

| id | harness v1 判定 | 重放复核证据 | 归类 |
|---|---|---|---|
| basics-01-reverse-coding | FAIL | 行为合理——模型核实仓库数据（nlsy97_chapter7.dta 仅 5 变量、无抑郁量表）后请求澄清，或给出 use/recode 指引；重放响应在新旧 matcher 下均 PASS（含 use 等词） | **场景-数据漂移 + 响应措辞依赖**：scenario 指向仓库不存在的抑郁量表，fixture 与数据不符 |
| cross-02-regression-then-coefplot | FAIL | 模型实际执行嵌套回归并产出森林图（.scratch/price-nested-forest.png + .do），但响应是执行摘要，未包含 regress / estimates store / coefplot 命令链词——新旧 matcher 均 FAIL | **行为风格缺口（教学型 vs 执行型输出）**，非命令错误 |
| identification-01-router-entry | T1 冒烟 FAIL → 全量 PASS | 同 prompt 跨运行结果可变 | **单次运行噪声** |

### 处置

1. **判定器 v2 已上线**（本日修改 verify/test-prompts.sh）：固定串优先 + 点号通配兜底，修复 SKILL.md → SKILLmd 类匹配缺陷。
2. **cross-02 产品决策（2026-08-27 落地）**：用户选「执行型」——expected_actions 已改为交付语义（forest 图 + 显著性对比，命令链不强求展开）；重放验证 PASS（命中词：森林图）。
3. **basics-01 fixture 修复（2026-08-27 落地）**：scenario 改指仓库真实数据 nlsy97_selected_variables.dta 的 psmoke97（1↔5 取值 + 扩展缺失，实测存在）；重放验证 PASS（命中词：recode）且行为质量高（读数、翻转、缺失码原样保留、均值/相关校验）。
4. **建议**：未来 harness 对 FAIL 自动重放一次再定性（当前为人工重放）。
5. **复验**：docs 模式 38/38 PASS；bash -n 通过；两条 FAIL 在新 fixture + 新判定器下重放均转 PASS。

---
