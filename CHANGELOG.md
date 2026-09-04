# Changelog

All notable changes to stataskills are documented here. This format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/) (skill content is
versioned by Stata compatibility).

## [Unreleased]

### Added
- docs(did-community) PR-D: TROP（Triply Robust Panel Estimator）完整章节 + 验证脚本 — 新增 `stata-did-community/references/trop.md`（完整语法 + 与 honestdid 联动 + Athey-Imbens-Qu-Viviano 2025 文献；陷阱四件套集中在主 SKILL.md）；SKILL.md 决策树第 1 节 +1 行（高维共同因子 + 内生选择路由）+ TROP 能力补充表（不加特征对照矩阵列，避免 9 列结构 diff 过大）；`verify/verify-trop.do`（REQUIRED sentinel + trop factors(k=2) + estat aggregate + estat placebo 三段断言）；targets.sh delegates 加 `verify-trop` — `4b23f6c`。Closes #13 #14 #15 #16。
- docs(did-community) PR-C: 面板 MDE / 功效分析模板 + 验证脚本 — 新增 `stata-did-community/references/power-analysis-template.do`（Bloom 1995 闭式 MDE 段 + Burlig-Preonas-Woerman 2020 panel simulation 段：`power_dgp` program + 500-rep Monte Carlo + ATT 扫描曲线，ATT 取 0.3 SD；修正后实测 MDE=0.2557, power=0.666）；`stata-did-community/references/workflow-8step.md` 新增步骤 5b（两套方法对比 + 典型审稿答复模板，数字与 verify 实际一致）；`verify/verify-power.do`（Bloom analytical worked-example assert MDE ∈ [0.25, 0.26] + DGP 不变量 + simulation power ∈ [0.5, 0.95] + Bloom MDE < ATT 一致性断言）；targets.sh delegates 加 `verify-power` — `8fd6a2d`。Closes #9 #10 #11 #12。
- docs(did-community) PR-B: HAD v2.0.0 两条平行路线 + did_had OPTIONAL sentinel — 新增 `stata-did-community/references/dcdh.md`（目标参数对比 DID_M vs WAS_d̲ + 识别假设对比 Case 1 QUG / Case 2 boundary + 数据特征分叉决策树 + did_had v2.0.0 完整语法 + de Chaisemartin et al. 2024b/2026 文献）；SKILL.md 决策树第 1 节 +2 行（按数据特征分叉）+ 陷阱 #19「不要把 did_had 当作 did_multiplegt (had) 的升级版」+ 陷阱 #20「did_multiplegt (had) 要求 quasi-stayer 必须存在」；`verify/verify-synth-sdid.do` 末尾追加 `did_had` OPTIONAL 检测 sentinel（`__COMMUNITY_PACKAGE_OPTIONAL_MISSING__did_had__`）— `058e748`。Closes #6 #7 #8。
- docs(did-community) PR-A: SA-IW 等价说明 + csdid method(twostage) + Roth 2022 PreTrendsPower 警示 — 新增 `stata-did-community/references/csdid-jwdid-imputation.md`（SA-IW 段：`method(dr)`/`method(ipw)` 与 Sun-Abraham 2021 在 staggered 共同支撑下 ATT(g,t) 渐近等价，引 Sant'Anna & Zhao 2020 + Callaway & Sant'Anna 2021；R `did_multiplegt_dyn` SA 选项纠偏；完整 Sun & Abraham 2021 J Econometrics 文献条目；Gardner 2022 two-stage 子节：两阶段思路 + 与 BJS did_imputation 差异 + 适用边界 + 完整 do-file + arXiv:2207.05943 文献）；`references/workflow-8step.md` 第 3 步追加 Roth 2022 Pretest with Caution 子节（3 条要点 + 何时汇报段 + R `pretrends` 提示 + 完整 Roth 2022 AER:Insights 文献）；SKILL.md 决策树 +1 行（csdid twostage）+ SA 路由 + 陷阱 #18；`description` 计数 9→10，列表 +trop，触发词扩展（Sun-Abraham / Gardner twostage / did_had / TROP / 功效分析 / power analysis / MDE）— `8057868`。Closes #1 #2 #3 #4 #5。
- docs(README): 项目展示新增仓库架构图 — Archify 工具生成的浅色截图 `docs/stataskills-architecture.png`（122 KB, 1440×900），README 引用 + provenance 在 commit message 注明 — `d48e8be`。
- feat(验证): declarative verification target plan（#20）——`verify/lib/targets.sh` 新增 `targets_plan_owner` / `dofiles` / `logs` / `delegate_bases`；旧 `targets_run_dofile` / `targets_delegates` 薄封装保留；`verify/test-targets.sh` 表驱动覆盖普通入口、DID-community 三委托、唯一性与孤儿 delegate；CI 接入。
- feat(验证): VERIFY CONTRACT + data locator module（#21）——新增 `verify/lib/contract.sh`（`contract_parse` / `contract_exhaustive_gaps` / `data_locate`；agis6/external/generated/sysuse/sim）；`test-contract.sh` 表驱动（partial 声明先红后绿、missing/unlisted/duplicate/CRLF）；`check-claims` 断言 13 改走 contract 解析；旧 `check_data_ready` 保留；CI 接入。
- feat(验证): 封装 prompt corpus adapters（#22）——新增 `verify/lib/prompt_corpus.sh`（一次选定 jq/python）；`test-prompts.sh` mode 不再分支 adapter；`test-prompt-corpus.sh` 双 adapter 对拍 + malformed（空 skill / 缺 actions / 重复 route_branch）；CI 接入。

### Fixed
- fix(did-community): 恢复 `did_imputation` method ownership（#19）——详解节从 `references/sdid.md` 迁回索引目标 `references/csdid-jwdid-imputation.md`；`sdid.md` 仅保留 `sdid`；`check-claims.sh` 新增断言 22（索引指向 A、详情在 B 先红后绿）。
- fix(验证): CI `Shellcheck harness` 因 SC2034 红——`check-claims.sh` 把已解析的 `v_chapter`/`v_checks` 纳入契约非空校验（注释本就写「4 字段全有（非空）」）；`test-prompts.sh` 的 `action_*` 间接展开改为数组下标，shellcheck 能看见引用。顺带清 SC2016/SC2001。
- fix(power): 修复功效分析两个 P1——解析式改为两组 pre/post 均值差方差，N=200、100/100 分组、4 pre / 6 post 的已知 MDE 从错误的 0.0886 修正为 0.2557；simulation 将单位 FE / 单位异质 ATT 移到 `expand` 前生成，时间 FE 每期只抽一次，扰动改为单位内 AR(1)，并以 Stata 不变量断言锁定 DGP，修正后 ATT=0.3 的 500-rep power=0.666。
- fix(验证): 修复两个 harness P1——CHANGELOG 禁词断言只审 `[Unreleased] / Added`，允许 `Fixed` 记录旧错误；`test-prompts.sh --prompts` 经 target registry 解析普通/多委托日志集合，不再读取已删除的 `verify-did-community.log`。
- fix(验证+技能): 修 HEAD~15 review 残留 findings（A1–A6）——`SKILL.md` 详细方法参考表补 `trop.md` / `power-analysis-template.do`；模板 ATT 扫描去掉非法 `rejected_\`att'`；CHANGELOG 纠 `method(dripw)` / Targeted Robust OP /「矩阵 TROP 列」；PR-A 关键词耐久锁；TROP 陷阱四件套迁入主 SKILL（#21–#24）并删 `trop.md` 独立陷阱节；`workflow-8step.md` 去掉 orphan SHA `3cae231`。`check-claims.sh` 新增断言 16–21（均先红后绿）。
- fix(验证): `verify/verify-power.do` 段 2 补 `capture which reghdfe` 前置探测（OPTIONAL sentinel + 跳段 2/3）——此前裸调用 reghdfe 在缺包机器上 r(199) 硬失败，违反 ADR-0003「默认模式静默 PASS」决策；段 2 标题同步改为「单 cohort 简化 DGP」（不宣称复现原论文数值）；`verify/check-claims.sh` 新增断言 14「社区命令均有前置 capture/cap which 探测」（red-capable：先红在 verify-power，修复后转绿）；本机重跑实测 PASS，raw log 按 ADR-0005 更新。
- fix(did-community): `stata-did-community/SKILL.md` 计数漂移修复——正文三处禁令「9 个社区包」→ 10（与 frontmatter description「10 个方法」对齐），compatibility 包清单补 `sdid` / `trop` / `nprobust` / `did_had`；`verify/check-claims.sh` 新增断言 15「did-community description 与正文计数一致」。
- fix(did-community): `references/power-analysis-template.do` 末尾答辩模板样板数字修复——原写「~70-90% power at 0.2 SD」，与本仓库实证（0.2 SD 下 power≈0.33）直接矛盾；改为与 `verify/verify-power.do` 实测一致的 0.3 SD / ~66% 版本；模板 / `workflow-8step.md` / `verify-power.do` 三处「staggered」措辞统一为「单 cohort 简化 DGP」的诚实描述。
- fix(coefplot): 移除 `stata-coefplot/SKILL.md` 指向不存在锚点的鲁班报告引用——`LUBAN-REPORT.md` 只有 P0/P1/P2 三段，不存在被引用的 `P2-C`，日期也对不上（SKILL.md 写 2026-08-17，报告为 2026-08-18）；该断链先于本次仓库清理存在，且 coefplot 独立分发后会让用户看到指向仓库外不存在文档的引用。拆分理由已由上文「主文件保留第 1–7 章（入门）和所有陷阱速查」自包含，直接删除括号指针，不补新断言。
- fix(verify): 修复 CRLF manifest 下静态验证误报数据集缺失 — `verify/run-verify.sh` 第 125 行 `ds="${ds%$'\r'}"` strip 尾随 `\r`；按 AGENTS.md「manifest 单一来源」+ `.gitattributes` 第 11 行 `eol=lf` 落地 — `2952a0a`。

### Changed
- docs(仓库): AGENTS.md 关键惯例补「Commit 规矩」条目（`Made-with: Proma` trailer + 禁 `Co-Authored-By:`）——`.githooks/commit-msg` 注释此前声称的禁令无文档出处，现同步改为指向该条目；`.githooks/commit-msg` 与 `references/power-analysis-template.do` 补 EOF 换行。
- chore(仓库): 删除 `.scratch/identification/` 已完工的规划产物（12 个文件、1098 行）——ponytail-audit 复盘的第一笔。`spec.md` 是 2026-08-25 锁定的 Proposed 实施契约，10 个 skill 已全部落地，其自述「仓库当前仍有 8 个 skill」已过期；`ADR-0006` 副本与 `build-teaching.do` 分别被 `docs/adr/0006-identification-four-pillars.md` 和 `data/selection/build-teaching.do` 取代；非目标（Heckman / cem / DML / xtpsmatch / psmatch2 / ebalance）在正式 ADR 第 73、211 行均有记录，无孤本内容丢失。`.gitignore` 本就将 `.scratch/` 视为 Agent 草稿区。
- docs(README): 修订为当前状态（v1.2.0 Release 徽章、skills.sh 上架说明、--llm 三层验证、英文 Release 指引）— `94000d3`。
- chore(README): 移除 skills.sh 徽章 `[已上架]` 标记（徽章为活链接，check-claims 断言同步）— `7e4a317`。

## [1.2.0] - 2026-08-27

方向 A 传播收尾 + LLM 行为回归实测后的首个 GitHub Release：10 skills 全部 skills.sh 上架（10/10 可访问）、English Summary 量化钩子、--llm 全量行为回归（25/27 直接 PASS，2 条判定问题经 fixture/matcher 修复重放转绿）、10 个 SKILL.md 交付前自检清单。

### Added
- feat(回归+IV): 增加识别与论文解释路径 — 新增 `references/iv-identification.md`（联合识别 / relevance+independence+exclusion+monotonicity+SUTVA / LATE/complier / 第一阶段-简约式-2SLS 结果三角 + Wald ratio / OLS-IV 差异 / 论文主表与限制模板）；SKILL.md description 增 LATE/complier/简约式/识别假设触发词 + 强制路径表 +1 行 + references 表新增 10.10 行 + 陷阱 10「验证」段改写为联合秩条件 + 引用识别文档；`references/iv.md` / `iv-testing.md` 边界约定加 pointer；`test-prompts.json` schema 2.2.0→2.3.0 新增 2 条 IV prompt（regression-04/05）需 `verify-regression.do` 真实 `assert` 执行证据；verify-regression.do ch10.10 新增官方结果三角（ivregress/
egress 三类回归共享样本 + vce + Wald-ratio 数值断言），VERIFY CONTRACT checks: 增 `iv-identification`；README prompt 计数 14→16。
- feat(回归+IV): 工具变量五命令 + 全套检验体系（教材未覆盖扩展）— 新增 `references/iv.md`（268 行）五命令全景 + `references/iv-testing.md`（412 行）检验体系；`stata-regression/SKILL.md` 新增 6 处改动（description 触发词 / compatibility 包列表 / 强制路径 +1 行 / 路由表 +3 行 10.8/10.9/10.6a / 陷阱四件套 +4 条 9-12 号 / 黑名单 +2 条）；`test-prompts.json` schema 2.1.0→2.2.0 新增 2 条 IV prompt（regression-02/03）；README prompt 计数 12→14 — `da91f8f`。
- fix(回归+IV): 修复恰好识别时 `estat overid` r(498) 导致 verify-regression 失败 — verify-regression.do 恰好识别段改 `capture noisily estat overid` + 另起过度识别段；SKILL.md r(498) 条目补充第二种触发；test-prompts.json regression-03 场景改为恰好识别 — `084fcfd`。
- feat(验证): `test-prompts.sh --llm` 全量实跑 27 条 Agent 行为回归（claude CLI + OAuth 登录态 / MiniMax M3 后端）：25/27 直接 PASS；2 条 FAIL 经重放归因并修复（见下文 Changed）；台账 `verify/llm-results.md`、`verify/llm-smoke-results.md` — `b52609d`、`9529f5c`。
- feat(传播): skills.sh 徽章 `[待注册]`→`[已上架]`（10 个 URL 实测 200 可访问、npx skills add 可发现）；English Summary 增加量化钩子「10 skills · 10/10 verified · 9 DiD estimators · 27 prompts · live on skills.sh」；check-claims 断言同步支持 `[已上架]` 状态 — `8812a87`。

### Fixed
- fix(回归+IV): 让 `test-prompts.sh --prompts` 只以真实执行的 Stata 命令作为覆盖证据；新增 `ivreg2` 非线性内生项与 `weakivtest` 实跑段，补齐 `ranktest` / `avar` 等依赖声明，并修正 KP LM 与 KP Wald F 的结果表述。
- fix(验证): `--llm` 认证闸口从「仅 ANTHROPIC_API_KEY」放宽为「API key 或 claude CLI OAuth 登录态任一」；判定器修复点号剥离缺陷（`SKILL.md`→`SKILLmd` 永不匹配）与全角标点末词误伤——固定串优先 + 点号通配兜底 — `b52609d`。

### Changed
- fix(验证): `check-claims.sh` 第 13 条注释从旧单行格式更新为 6 行 VERIFY CONTRACT 键值块 — `efa539a`。
- fix(验证): `stata-regression/SKILL.md` compatibility 包清单补 `weakivtest` — `efa539a`。
- fix(验证): `verify-regression.do` data 契约从单个 `partyid.dta` 扩展为 7 个实际数据集（分号分隔）；`check-claims.sh` 校验器支持分号分隔多数据集逐项校验 — `efa539a`。
- docs(验证): 提交最新 verify 日志快照（8 份），按 ADR-0005 保留完整原始日志 — `261997a`。
- test(行为): basics-01 场景改指仓库真实数据（`nlsy97_selected_variables.dta` 的 `psmoke97`，1–5 取值 + 扩展缺失实测存在；原 scenario 指向仓库不存在的抑郁量表）；cross-02 expected_actions 改为执行型语义（森林图 + 显著性对比为交付物，命令链不强求展开） — `8f1583d`。
- chore(仓库): 忽略 `.scratch` Agent 运行产物（`*.do` / `*.dta` / `*.png` / `llm-smoke/`）与 `stata_batch__*.log` — `5a0e457`。
- docs(skills): 10 个 SKILL.md 增加「交付前自检清单」（LUBAN 检查点设计 P2）——强制路径/陷阱/黑名单提炼为交付前逐条核对 — `1b43a3e`。

## [1.1.0] - 2026-08-25

luban 打磨方案 A 落地：README hero 钩子重写 + skills.sh badge 诚实化 + 8 skill 错误码速查 + compatibility frontmatter + Quick Reference 导航表。

### Added
- feat(skills): 8 个 SKILL.md 各加「🔍 错误码速查」节（24 条 r(N) 错误码 → 触发 → 修复三件套），挂在「❌ Agent 不该做的事（黑名单）」下方互补——黑名单给原则，错误码给精准命中 — `76493bc`。
- feat(skills): 8 个 SKILL.md frontmatter 加 `compatibility:` YAML 字段（runtime / Stata 版本平台 / skill-specific 依赖三段式），让 Skill 在 SkillsMP / OpenClaw / Claude Code / Codex 多 runtime marketplace 里都被识别为兼容 — `9cdf16a`（含 `694cb30` revert + redo 修复了 `read({limit:8})` 截断事故）。
- docs(README): 加「Quick Reference：用户原话 → 读哪几个文件」表（12 条导航），与 step 3 错误码速查形成「用户原话 → 读哪节 → 报 r(N) 怎么办」三层闭环 — `9a0a214`。

### Changed
- feat(README + 验证): README hero 钩子从「Agent 跑 Stata DID 分析的唯一验证通过入口」改为「中文实证研究者装上就能让 Agent 写出经过 8/8 verify 验证的教材级 Stata 代码」；同步声明本仓库已通过 `bash verify/run-verify.sh` 实测 8/8 PASS。README skills.sh badges 全部补 [待注册] 诚实标记（8 个含 stata-rdd）；补 stata-rdd badge（之前漏挂的 8 skill 之一） — `12d91e3`。
- feat(验证): `verify/check-claims.sh` 新增第 12 条「README hero + skills.sh badge 诚实性」断言——hero 区禁词（7/7 verify / 9 个识别方法 / DID 唯一入口 / Stata DID 分析的唯一）/ hero 区必含词（8/8 verify）/ skills.sh badge ↔ 实际 skill 目录一一对应 / 占位 badge 必须标 [待注册]。实证捕到 4 处历史漂移 — `12d91e3`。

## [1.0.0] - 2026-08-25

首个稳定版本。8 个 skill 全量验证通过（6/6 run-verify.sh + 12/12 test-prompts.sh docs 模式），
demo 全景 8 do-file + 27 PNG 全部 end of do-file，5 篇 ADR + 完整 verify harness。

### Changed
- refactor(验证): 新增 `verify/lib/targets.sh` 验证目标注册表，把
  `did-community → synth-sdid` 的委托关系收敛为单一来源；`run-verify.sh`
  全量枚举改为按 `stata-*/SKILL.md` 驱动，`check-claims.sh` 第 1 条改为
  注册表驱动的「skill ↔ 入口」双向断言（含孤儿检测），删除占位
  `verify-did-community.do`。详见 ADR-0004。
- refactor(验证): `test-prompts.json` 成为 `--prompts` 模式的单一来源——
  新增 `verify_keywords` 字段，删除 `verify_script`（重复注册表的委托知识），
  `test-prompts.sh` 删除两个按位置配对的平行数组，验证目标名从 `skill`
  字段推导（取首个、去 `stata-` 前缀）。`did-02/03/04` 目标随之收敛为
  `did-community`（由注册表解析到 synth-sdid）。
- refactor(架构): 拆分 stata-regression SKILL.md 为 references/ 模式——
  主文件 762 → 111 行，三个教材章节（ANOVA / 多元回归 / 逻辑回归）与
  三个扩展（reghdfe / ivreghdfe / fect）下沉到 6 个
  references/<章节|方法>.md（仿 stata-coefplot / stata-did-community 范式）。
  四件套陷阱统一在主文件一份。
- docs(adr-0005): 记录「保留完整 verify log、不替换为稳定摘要」的决策（架构评审候选 4 的取舍），详见 docs/adr/0005-keep-raw-verify-logs.md。

### Added
- feat(验证): 新增 `verify/check-claims.sh` 文档断言检查器（架构评审
  candidate 1）：从文件系统数出 facts（skill 数 / .dta 数 / manifest 条数 /
  demo dofiles、logs、PNG）与结构断言比对，接入 CI；顺手修复两处已实证
  漂移（docs/run-stata.md「5 份」→6、demo/REPORT.md 加快照范围声明）。
- feat(技能): 新增 `stata-did` skill，覆盖 Stata 官方 DID 命令族
  （didregress 重复截面/DDD、xtdidregress 面板、hdidregress/xthdidregress
  异质性稳健错时处理，及 trendplot/ptrends/granger/aggregation/atetplot/
  bdecomp 事后诊断），素材源自 Stata 19 官方 DID 宣传单，全部语法经
  Stata 19.5 实测；配套 `verify/verify-did.do`（全模拟数据，无网络依赖）
  接入 harness（5/5→6/6）与 README/CITATION 同步。
- feat(技能): 新增 `stata-coefplot` skill，完整整合 Ben Jann coefplot 官方
  getting-started + estimates / confidence-intervals / labelling / markers /
  varia 六大页面的系数图方法；配套 `verify/verify-coefplot.do`、
  `demo/dofiles/06_stata-coefplot.do`（4 张 PNG）与 README 更新。
- feat(测试): `test-prompts.json` schema 2.0.0 → 2.1.0，每条 prompt 新增
  `difficulty`（easy/medium/hard）/ `gotchas`（陷阱速查编号数组）/
  `requires_package`（前置 SSC 包列表；null=全部内置）三个元字段；
  借鉴 dylantmoore/stata-skill 的 evals.json 结构。`verify/test-prompts.sh`
  与 `verify/check-claims.sh` 仅消费 `id`/`skill`/`verify_keywords`，
  新字段为纯扩展，不破坏 harness。docs 模式 12/12 PASS。
- feat(stata-basics): 新增「⚠️ 通用 Stata 陷阱速查（跨 skill 前置清单）」节，
  在「强制路径」与「核心语法」之间前置 13 条通用陷阱（缺失值排序到
  +infinity、`=` vs `==`、local 宏语法、bysort 前置排序、`i.`/`c.` 因子变量、
  `gen` vs `replace`、字符串大小写、`merge` 必查 `_merge`、
  `preserve`/`restore` + `tempfile` 做 collapse-merge-back、权重不可互换、
  `capture` 吞错、行续接 `///`、`r()`/`e()`/`s()` 区分），统一用项目
  既有的「陷阱 → 触发 → Fix → 验证」四件套格式；与下方「关键陷阱速查」
  （skill 特有：漏逗号、if 缺 `& var < .`、反向编码等）互补。
  借鉴 dylantmoore/stata-skill 的 Critical Gotchas 前置模式。
- feat(验证): `verify/test-harness.sh` 回归测试——探针 do-file 故意触发
  错误，断言 harness 必须判 FAIL，锁住判定逻辑本身。
- feat(仓库): GitHub Actions（`.github/workflows/verify.yml`）在 push/PR 自动
  跑 Stata-free 静态层；配套 `run-verify.sh --static`：version 政策 +
  数据集存在 + manifest 登记 + manifest 与 `data/agis6/*.dta` 双向一致性，
  另加 shellcheck 质量门（runner 无商业 Stata，执行层仍由本机承担）。

### Fixed
- fix(验证): 错误码正则改为整行锚定 `^[[:space:]]*r\([0-9]+\);`，捕获
  个位数错误码（如 assert 失败的 `r(9)` 旧版被判 PASS 的假阳性），同时
  仍不误吃 `power(0.90)` / `star(5)` 等合法参数；版本政策校验钉到
  do-file 首行；data readiness 额外校验引用数据集已登记入
  `data/manifest.txt`。
- docs(仓库): 修正 README/CITATION 中 coefplot 加入后的声明漂移（badge 4/4→5/5、
  英文摘要 4→5 skills、对比表 demo 规模 5 do-file + 15 PNG→6 + 19、
  SKILL.md 行数范围）。
- chore(数据): 移除 `data/agis6/` 下 20 个误入库的运行日志（`chapter*.log`、
  `_*.log`）——可再生产物，非 provenance；`.gitignore` 扩为
  `data/agis6/*.log` 防复发，落实「数据目录只放数据」。

- docs(readme): 首屏加钩子句「**Agent 跑 Stata DID 分析的唯一验证通过入口。**」；
  快速开始节补 `npx skills add jefeerzhang/stataskills` marketplace 安装入口。
- refactor(架构): 拆分 stata-did-community SKILL.md 为 references/ 模式——
  主文件 1219 → 293 行，详细方法签名下沉到 8 个 references/<method>.md
  （仿 stata-coefplot 已有 references/ 目录）。陷阱表统一在主文件一份。
- docs(skills): 7 个 SKILL.md 的「关键陷阱速查」节统一为「**陷阱 → 触发 → Fix → 验证**」
  四件套格式；为每个 Skill 末尾新增「## ❌ Agent 不该做的事（黑名单）」节，
  与 ADR-0001 联动。
- feat(验证): 新增 `verify/test-prompts.sh` 三模式 harness（docs / --prompts / --llm），
  把 test-prompts.json 的 11 条 prompt 从 spec 升级为可执行测试；docs 模式（默认，CI
  友好）断言 JSON 合法 + 覆盖 7 skill + expected_outputs 关键词出现在文档/日志。
  --prompts 模式本机实测 11/11 PASS（2026-08-22 StataNow 19.5 MP）。
  接入 `.github/workflows/verify.yml`。仿 test-harness.sh 与 run-verify.sh 三模式
  设计。

- fix(验证): 本机实测 test-prompts.sh --prompts 模式时发现并修复 3 个 harness bug：
  1. `verify-did-community.do` 用了相对路径 `do "verify/verify-synth-sdid.do"`，
     cwd 切到 data/agis6/ 后路径解析失败——run-verify.sh 改为直接跑 verify-synth-sdid.do，
     主循环结束后复制一份 verify-did-community.log。
  2. harness 解析 sentinel 字符串要求单独成行，但 Stata batch mode 下
     `display "SENTINEL"` 后紧跟 `exit 1` 会让 display 输出变 echo 行
     （`.     display "SENTINEL"`），sentinel 不再单独成行——改为 grep -oE
     抓所有 sentinel 字符串（不要求独立行）。
  3. sentinel 分支的 `exit 1` 写 r(1) 错误码被 harness 计为真实错误——
     检测到 sentinel 时把 r(1) 视为缺包触发的 exit，从 r(错误) 计数中减去。
- fix(脚本): verify-synth-sdid.do 把 `error 1` 改为 `exit 1`（语义一致，行为
  一致）；`estat group/event` 在 40 unit × 10 period 小样本下报 conformability
  r(503) 是已知 csdid 限制，用 capture 包住让脚本继续。

## 2026-08-16 — repo polish

### Changed
- refactor(verify): centralise platform paths into `verify/stata.conf`; fix
  demo provenance references — `daaf692`.
- docs(readme): tighten README to be an index of seams; move descriptions of
  skill contents to per-skill files — `11c45bd`.
- refactor(arch): consolidate run conventions into `docs/run-stata.md` seam;
  deepen `verify/` into a verification harness — `d32dc99`.

### Documented
- docs(adr-0001): record decision to keep `SKILL.md` code fences as
  pedagogical pseudocode rather than an executable interface — `a3d9401`.
- docs(demo): fix English-Chinese spacing and fullwidth punctuation in
  `demo/REPORT.md` — `2268b8c`.

## 2026-08-15 — demo

### Added
- feat(demo): end-to-end demonstration using Stata's built-in `auto.dta` —
  5 do-files, 5 logs (all `end of do-file`), 11 PNG graphs, and a full
  REPORT.md walking through each skill — `2394ef9`.

## 2026-08-15 — repo polish

### Fixed
- fix(docs): fix issues identified by code-review pass — `bca861a`.
- chore: configure engineering skills (GitHub issue tracker, default triage
  labels, single-context domain docs) — `6bdd0d5`.

## 2026-08-14 — initial release

### Added
- feat(skills): 4 Stata skills (`stata-basics`, `stata-descriptives`,
  `stata-regression`, `stata-advanced`) covering chapters 1–16 + Appendix A
  of *A Gentle Introduction to Stata* (6th ed.) — `a5db238`.
- feat(book): include the textbook's Markdown text + 170 figures in `book/`
  for reference — `fd0cca5`.
- feat(data): 38 `.dta` files + 16 `chapter*.do` from the AGIS6 dataset
  bundle, with `data/manifest.txt` as the single source of truth.
- feat(verify): initial `verify/` harness with PASS/FAIL judgement.
- feat(docs): `download_data.do` for one-shot re-fetching of the AGIS6 data
  bundle.

---

[Unreleased]: https://github.com/jefeerzhang/stataskills/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/jefeerzhang/stataskills/releases/tag/v1.1.0
[1.0.0]: https://github.com/jefeerzhang/stataskills/releases/tag/v1.0.0
