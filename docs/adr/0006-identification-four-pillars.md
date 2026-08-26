# ADR-0006：四个识别方法支柱与横切路由

- 状态：Accepted
- 日期：2026-08-25
- 接受日期：2026-08-26
- 路径：`docs/adr/0006-identification-four-pillars.md`
- 相关：[ADR-0001](0001-do-not-execute-skill-code-fences.md)（SKILL 围栏保持教学伪代码）、[ADR-0002](0002-demo-as-independent-panorama-layer.md)（demo 独立全景层）、[ADR-0003](0003-community-packages-as-first-class-verifiable-subjects.md)（社区包验证）、[ADR-0004](0004-verification-target-registry.md)（验证目标注册表）、[ADR-0005](0005-keep-raw-verify-logs.md)（保留完整 verify log）

## 背景

仓库现有 10 个 Stata skill；`stata-selection` 补齐横截面 selection-on-observables，`stata-identification` 提供统一的「研究设计 → 识别方法」横切入口。DID、RDD、IV 与 selection 分别承载四类观察性识别方法。仅凭变量名、数据形状或政策关键词不能证明识别假设成立，因此不能用关键词列表代替设计判断。

## 决策

### 1. 四个方法支柱 + 一个横切 router

新增 `stata-selection` 与 `stata-identification`，仓库由 8 个 skill 扩展为 10 个 skill。

| 方法支柱 | 入口 |
|---|---|
| RDD | `stata-rdd` |
| IV | `stata-regression` 的 IV references |
| DID / 面板政策设计 | `stata-did` 与 `stata-did-community` |
| selection-on-observables | `stata-selection` |

`stata-identification` 是跨方法的 router，负责顺序 stop rules、共同识别假设与通用论文表述；它不是第五个方法支柱。RCT / 随机分配优先于四个观察性方法支柱，但 v1 不为 RCT 新建独立估计 skill。

### 2. 路由采用识别条件 stop rules

以下仅记录路由顺序和分支归属，不是完整规则的第二份副本：

1. **RCT / 随机分配**：实际 treatment assignment 由可审计的随机机制分配时，停在 RCT；随机化通常支持 ITT，但必须先明确适用的 estimand，并处理 attrition 与 treatment uptake。若随机的是 encouragement 且存在 treatment noncompliance，则不把 uptake 的处理效应留在 RCT 分支，而是进入 IV 分支，论证 relevance、independence、exclusion、monotonicity 与 SUTVA 后解释 LATE。没有可辩护随机机制时继续检查 RDD。
2. **RDD**：只有预先确定的运行变量与 cutoff、且局部连续性和无精确操纵等条件可辩护时，进入 `stata-rdd`；否则继续检查 IV。
3. **IV**：只有候选工具的 relevance、independence 与 exclusion 有设计或制度证据时，进入 `stata-regression` 的 IV references；二元工具的 LATE 还要求 monotonicity 与 SUTVA。条件失败时继续检查面板政策设计。
4. **面板政策设计公共 gate**：只要求明确政策时点、处理前后信息、未处理 donor / control，以及 no anticipation、SUTVA / no interference、稳定构成等公共条件。公共 gate 通过后分叉，而不是先把 standard DID 的 parallel trends 强加给整个支柱：
   - **standard DID**：需要足够的处理组与对照组 / 可比较单位支持 DID 比较，并满足与具体设计匹配、可辩护的 parallel trends 和相应 overlap / composition 条件，进入 `stata-did` 或适用的 DID 社区估计量。
   - **`synth` / `sdid`**：保持同一面板政策设计子分支，按方法析取进入 `stata-did-community`。`synth` 通常要求一个或极少处理单位、较长处理前时期、可辩护 donor pool、充分前期拟合及 placebo / 推断条件；`sdid` 要求充分处理前 / 后期和 untreated / not-yet-treated comparison units，支持单个或多个处理单位及当前实现支持的多个处理日期，并检查 weighting、latent-factor / regularity 与方法特定推断条件。“一个或极少处理单位”不是 `sdid` 的必要条件。
   - standard DID 的 parallel trends 不成立时仍检查 `synth` / `sdid`，不能直接踢去 selection。只有公共 gate 失败，或两个子分支都失败，才继续检查 selection。
5. **横截面 selection-on-observables**：前述设计均不成立时，只有二元处理、处理前协变量、conditional exchangeability 与 positivity / overlap 可辩护，才进入 `stata-selection`。
6. **停止因果声明**：若所有分支的进入条件或关键假设均无法辩护，明确停止因果解释；数据仍可用于描述或关联分析，但不得改用因果措辞。

匹配到首个成立的支柱即停止跨支柱选方法；面板政策支柱内部必须完成两个子分支检查后才能离开。其他当前分支的关键条件失败时，返回 router 检查下一分支。

Named-method trigger 直接进入对应方法 skill，不先绕 `stata-identification`：

- DID、事件研究、`csdid`、`synth`、`sdid` → `stata-did` 或 `stata-did-community`；
- RDD、断点、`rdrobust` → `stata-rdd`；
- IV、2SLS、`ivregress`、`ivreg2`、LATE → `stata-regression` 的 IV references；
- PSM、`psmatch2`、IPW、IPWRA、`teffects`、entropy balancing → `stata-selection`；点名 `psmatch2` 进入社区 `psmatch2.md` reference。主路径仍为 IPWRA → balance/overlap → 官方 teffects 对照。

直达后仍先执行方法 skill 的最短本地 gate；本地进入条件或关键假设失败时，再返回 `stata-identification` router。

### 3. 路由规则只维护一个权威副本

完整 stop rules 只在 `stata-identification/references/identification-decision-tree.md` 维护一个运行时权威副本，并带 `<!-- identification-stop-rules: full -->` 标记。唯一副本静态扫描只遍历 `stata-*/SKILL.md` 与 `stata-*/references/*.md`；本 ADR 与历史文档只记录摘要，排除在副本计数之外。各方法 skill 只保留：

- 本方法的最短进入条件；
- 条件失败时停止本方法的动作；
- 指向 `stata-identification` router 的链接。

各方法 skill 不复制完整决策树。此维护约束只陈述可由运行时文件内容与静态检查审计的事实，不陈述不可测效果。

共同假设 reference 并列说明 consistency、SUTVA / no interference、design-specific exchangeability、positivity / overlap 与 estimand；每条假设必须按“定义 → 需要的证据 → 失败后能说什么”结构书写。design-specific exchangeability 区分 standard DID 的 parallel trends、`synth` 的 donor / 前期拟合条件，以及 `sdid` 的 weighting / latent-factor / regularity 条件。MDE、样本量、标准误和置信区间属于 power / precision，不作为识别假设。论文写作只能把诊断作为支持性证据，不能写成假设已被证明；必须同时说明 estimand、机制、目标总体与外推边界。

### 4. `stata-selection` v1 范围

v1 只覆盖横截面、二元处理、处理前可观测混杂，默认 estimand 为 Stata 术语 **ATET**。所有 treatment-effect estimation 命令——`teffects ipwra`、`teffects psmatch`、`teffects ipw` 与 `teffects nnmatch`——显式指定 `, atet`；`teffects overlap` 是 postestimation，不接受也不需要 `atet`。

默认主估计量是 `teffects ipwra`，准确名称为 **IPW regression adjustment** 双重稳健估计量。它与 `teffects aipw` 的算法和 estimating equations 不同，也与 DID 设计下的 `hdidregress aipw` 不同。双重稳健只表示：在 consistency、SUTVA / no interference、conditional exchangeability、positivity 和目标 estimand 已成立时，outcome model 与 treatment model 至少一个正确可提供一致性保证；它不能修复未观测混杂、overlap 失败或两类模型同时误设。

v1 的方法边界如下：

- Heckman 在 v1 外部；相关请求只说明其不属于当前路径或停止当前路径，不新增仓库内 Heckman 指针、section、reference 或 verify；
- `psmatch2` 不作为默认主估计，但作为社区敏感性/兼容性对照独立维护；`teffects-psmatch.md` 只负责官方 `teffects psmatch`，`psmatch2.md` 独立负责社区包安装、常用匹配语法、ATT/ATE estimand、权重/匹配样本、标准误和限制，不得暗示其优于 IPWRA；
- `cem` 完全不进入 v1，不新增 reference、指针、主路径或 verify；
- 面板 selection（Wooldridge 反事实面板、CRE、`xtpsmatch`）列为 future-work；
- ML causal（DML、causal forest、DoubleML）列为 future-work；
- 连续或多值 treatment 不属于 v1；
- `ebalance` 是 optional 社区扩展，缺包时使用 `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ebalance__`，并遵循 optional sentinel 在默认与 `--community` 两种模式下均可 PASS 的契约；
- 主路径默认运行 `teffects ipwra ..., atet`，其他 estimator 仅按规范的对照、诊断或敏感性目的运行，不把任意 estimator 集合当作新的默认选择规则。

`stata-selection` 的 8 个 references 职责必须保持独立：

| Reference | 唯一职责 |
|---|---|
| `teffects-psmatch.md` | 只负责官方 `teffects psmatch` |
| `psmatch2.md` | 社区包安装、常用匹配语法、ATT/ATE、权重/匹配样本、标准误和限制 |
| `teffects-nnmatch.md` | 官方 NN matching 与适用边界 |
| `teffects-ipw.md` | propensity model、权重、极端概率与 ATET |
| `teffects-ipwra.md` | IPWRA 默认估计量与双重稳健边界 |
| `ebalance.md` | optional entropy balancing 与 sentinel |
| `balance-overlap.md` | balance、overlap 与 positivity 诊断 |
| `selection-paper-writing.md` | ATET 表格、平衡附表、识别假设与限制写法 |

### 5. 教学数据与治理

selection 教学数据采用锁定的可复现模拟 DGP：

- seed 固定为 20260825，N=2000；
- treatment 按 propensity 作 Bernoulli 分配，处理率约 25%，verify 断言范围为 `[0.20, 0.30]`；
- treatment 与 untreated potential outcome 的共同原因固定为处理前可观测协变量 `x1-x4`，即 selection on observables；
- 固定处理效应为 0.5，因此真 ATET = 0.5；
- 发布精确 varlist 为 `id treat y x1 x2 x3 x4 x5 x6`（简写 `id treat y x1-x6`）；
- 发布 variable labels 使用英文；中文解释留在 build 注释和 README。图形默认英文，用户要求中文时先询问；
- `y0`、`y1`、`tau`、`eta`、`ps_true`、`noise` 等 oracle / build-time 变量不发布。

本 ADR 是 ADR-0003 数据条款的窄化补充，不是静默冲突。`data/manifest-extra.txt` 管理的项目级扩展数据分两类：

- **外部来源扩展数据**继续要求 README 记录来源、license / provenance，并提供 checked-in `download_*.sh` 与 `EXPECTED_SIZE` 字节校验；
- **项目内生成数据**要求 README、固定 Stata version / seed / DGP、checked-in build do-file，以及 schema / 数值不变量验证；不要求下载脚本或外部许可。

selection 数据走项目内生成分支：正式数据进入 `data/manifest-extra.txt`，并在 `data/selection/README.md` 记录 seed、Stata 版本、完整 DGP、发布变量、未发布 oracle 变量与重建命令。`AGENTS.md` 与 `data/manifest-extra.txt` 顶部维护说明必须同步上述两分支。模拟数据不进入 AGIS6 的 `data/manifest.txt`。

### 6. 验证与状态门

两个新 skill 各有默认 1:1 verify 入口，不修改默认映射规则：

- `stata-selection` → `verify/verify-selection.do`：验证 exact varlist、数据不变量、原始选择偏误、IPWRA ATET 数值接近真值 0.5、balance / overlap、PSM、IPW 与 NN matching、独立 optional `psmatch2` smoke test/sentinel、optional `ebalance` sentinel 及结果表；IPWRA、PSM、IPW、NN 每个 estimator 都必须显式 `estimates store`；
- `stata-identification` → `verify/verify-identification.do`：验证共同假设与 estimand 的可执行示例；自然语言路由主要由 `test-prompts.json` 做行为回归。

`test-prompts.json` 的状态门要求 JSON 合法、文件系统中实际存在的 10 个 skill 全覆盖，并用 `route_branch` 锁定 `router-entry`、`rct`、`rdd`、`iv`、`standard-did`、`synth-sdid`、`selection`、`stop-causal`、`named-method-direct` 与 `gate-failure-return`；`router-entry` 覆盖通用“该选什么设计 / 能否识别”入口，其余每个锚点也都有 expected action。`synth-sdid` 保持一个锚点，但场景与 expected action 必须分别覆盖 `synth` 和 `sdid` 的析取条件。`verify/test-prompts.sh` 从实际 `stata-*/SKILL.md` 动态派生 expected skill，与 JSON 覆盖集做差，不保留固定 8 或固定 10 数组。named-method trigger 必须直达对应方法 skill，而不是先绕 router；点名 `psmatch2` 直达 `stata-selection` 并进入 `psmatch2.md` 社区 reference；本地 gate 失败返回 router，standard DID 失败后先检查 `synth` / `sdid`。selection 完整分析 prompt 固定为设计 gate → 原始检查 → IPWRA → balance/overlap → 官方 teffects 对照 → `psmatch2` 社区敏感性/兼容性对照 → 分表。

正式同步范围除新 skill、references、数据与两个 verify 入口外，还包括：`test-prompts.json`、`verify/test-prompts.sh`、`README.md`、`AGENTS.md`、`CONTRIBUTING.md`、`CITATION.cff`、`CLAUDE.md`、`.github/workflows/verify.yml`、`docs/run-stata.md`、`verify/run-verify.sh`、`verify/check-claims.sh`、`verify/test-harness.sh`、`data/manifest-extra.txt`，4 个现有方法 skill 的本地边界，以及 existing runtime references `stata-did-community/references/sdid.md` 与 `stata-did-community/references/workflow-8step.md`。`sdid.md` 必须明确单个 / 多个处理单位及当前实现支持的多个处理日期，单处理单位仅作为推断 / VCE 特殊情形；`workflow-8step.md` 必须拆开 Synthetic Control 与 Synthetic DiD 的选择条件。`CLAUDE.md` 当前含用户未提交改动，实施时必须先读取当前磁盘内容并最小合并，不得覆盖。`CHANGELOG.md`、`LUBAN-REPORT.md` 与仅描述既有 demo 运行的 `demo/REPORT.md` 是历史快照，不回写。

`.github/workflows/verify.yml` 同步 prompts 注释和预期 10-skill 文案。ADR-0002 允许 verify 无 demo，因此 selection 与 identification 的 v1 不以新增 demo 为验收门槛。ADR-0005 要求两个新入口的最近一次完整 verify log 随仓库保留，但这些 raw logs 和 README 的“本机实测 10/10 PASS”只能在最终全量验证产生证据后成为当前态声明。

### 6.1 结构、SKILL 惯例与活跃元数据 Acceptance 条件

以下条件必须全部满足：

- 文件系统恰有 10 个 `stata-*/SKILL.md`；每个 skill 恰好解析到一个 verify target，最终覆盖报告为 10/10。`stata-selection` 与 `stata-identification` 使用默认 1:1 映射，分别解析到 `verify/verify-selection.do` 与 `verify/verify-identification.do`，不新增委托；现有 `stata-did-community` 委托保持由 ADR-0004 的 target registry 解析。
- `stata-selection/references/` 恰有 8 个文件：`teffects-psmatch.md`、`psmatch2.md`、`teffects-nnmatch.md`、`teffects-ipw.md`、`teffects-ipwra.md`、`ebalance.md`、`balance-overlap.md`、`selection-paper-writing.md`。
- `stata-identification/references/` 恰有 3 个文件：`identification-common-assumptions.md`、`identification-decision-tree.md`、`identification-paper-writing.md`。
- 两个新 `SKILL.md` 的 frontmatter 至少含 `name`、`description`、`compatibility`；正文包含「强制路径」「运行 Stata 的方式」「关键陷阱速查」「错误码速查」和可执行禁令。
- 两个新 `SKILL.md` 的首个 Stata code fence 中，第一条可执行语句为 `version 19.5`；Markdown 物理首行不作此要求。两个新 verify do-file 的物理首行才必须是 `version 19.5`。
- 运行时扫描范围 `stata-*/SKILL.md` 与 `stata-*/references/*.md` 内，`identification-decision-tree.md` 的 `<!-- identification-stop-rules: full -->` 恰好出现一次；每个方法 skill 只保留最短进入条件、失败动作和 router 指针。本 ADR 与历史文档不纳入副本计数。
- README、AGENTS、`docs/run-stata.md`、harness 与 claims 的结构目标统一为 10 entries；README 的“本机实测 10/10 PASS”只有在最终证据产生后才更新。
- `CONTRIBUTING.md`、`CITATION.cff`、`.github/workflows/verify.yml` 与 `CLAUDE.md` 同步当前 10-skill / 6-ADR / CI 元数据。`CLAUDE.md` 实施前再次读取当前内容，最小合并用户未提交改动，不整文件覆盖。
- `verify/check-claims.sh` 动态计算 skill、prompt 和 `docs/adr/*.md` 数量；README 的 6 ADR 声明必须等于动态 `N_ADR`，badges 与动态计数一致，缺失声明或数字不等即 FAIL。
- ADR 标题与目标路径均为 ADR-0006；`CHANGELOG.md`、`LUBAN-REPORT.md` 和仅描述既有 demo 的 `demo/REPORT.md` 保持历史快照，不回写当前数量。

### 6.2 方法与路由 Acceptance 条件

以下条件必须全部满足：

- 完整 stop branches 覆盖 RCT、RDD、IV、面板政策公共 gate、standard DID、`synth` / `sdid`、横截面 selection-on-observables 与无可信设计时停止因果声明；每个分支都写明进入条件、关键假设和失败去向。standard DID 的进入条件必须包括足够的处理组与对照组 / 可比较单位，区别于 `synth` / `sdid` 的方法特定入口。
- 公共 gate 只要求明确政策时点、处理前后信息、可定义的未处理 donor / control 或 not-yet-treated comparison 来源、no anticipation、no interference 与稳定构成；standard DID 另要求足够的处理组与对照组 / 可比较单位及 parallel trends。`synth` / `sdid` 保持同一子分支，但按方法析取：`synth` 通常要求一个或极少处理单位、长前期、可辩护 donor pool 与前期拟合；`sdid` 要求充分处理前 / 后期和 untreated / not-yet-treated comparison units，支持单个或多个处理单位及当前实现支持的多个处理日期，并检查 weighting、latent-factor / regularity 与方法特定推断条件。“一个或极少处理单位”不是 `sdid` 必要条件。standard DID 的 parallel trends 失败后仍检查该子分支。
- `stata-did-community/references/sdid.md` 与 `stata-did-community/references/workflow-8step.md` 必须与 router 和 `identification-decision-tree.md` 同步：前者把单处理单位写成推断 / VCE 特殊情形，而非 `sdid` 适用范围；后者分开 Synthetic Control（通常少数处理单位）与 Synthetic DiD（充分 pre / post、comparison units、weighting、latent-factor / regularity 和方法特定推断条件），且不把处理单位少设为 Synthetic DiD 必要条件。
- Named-method trigger 按第 2 节直接进入对应方法 skill，不先绕 router；方法本地 gate 失败后返回 router。通用设计选择、仅有数据形状或政策关键词的请求先进入 router。
- selection 默认 estimand 处处为 ATET；`teffects ipwra`、`teffects psmatch`、`teffects ipw` 与 `teffects nnmatch` 的 estimation 示例都显式写 `, atet`；`teffects overlap` 作为 postestimation 不带 `atet`。`teffects ipwra` 准确称为 IPW regression adjustment 双重稳健估计量，并与 `teffects aipw`、`hdidregress aipw` 明确区分；文档不得声称双重稳健能修复未观测混杂或 overlap 失败。
- selection 主路径按「设计与处理前协变量 gate → 原始数据检查 → IPWRA ATET → `tebalance summarize` → `teffects overlap` → PSM / IPW / NN matching 对照 → 主表与独立平衡 log」执行，不把 postestimation 提前。
- IPWRA、PSM、IPW、NN 每个 estimator 都显式 `estimates store`。首次 `tebalance summarize` 紧跟 IPWRA，并归属 `ipwra_atet`；任何后续重印前先 `estimates restore ipwra_atet`。`teffects overlap` 同样归属 `ipwra_atet`，verify 只检查命令成功，不保存、export 或跟踪图形。
- 主结果使用连续 outcome 的原尺度 ATET 表；平衡结果只在 verify log 中作为独立、带标题的 `tebalance summarize` 附表，不自动拼入主结果表，也不使用指数化选项。
- selection 与 identification 的 v1 均不要求 demo；`cem`、Heckman、面板 selection、ML causal 和连续 / 多值 treatment 的排除边界与第 4 节一致。

### 6.3 数据与依赖 Acceptance 条件

以下条件必须全部满足：

- `AGENTS.md` 与 `data/manifest-extra.txt` 顶部维护说明明确 ADR-0003 的两分支窄化：外部来源扩展数据要求 README + license / provenance + `download_*.sh` + `EXPECTED_SIZE`；项目内生成数据要求 README + 固定 Stata version / seed / DGP + checked-in build do-file + schema / 数值不变量验证，不要求下载脚本或外部许可。
- `teaching-treatment.dta` 可由正式 build do-file 在 seed 20260825 下重建；N=2000，Bernoulli treatment 处理率约 25% 且断言位于 `[0.20, 0.30]`，共同原因为 `x1-x4`，固定真 ATET=0.5。
- 发布 varlist 必须严格按序等于 `id treat y x1 x2 x3 x4 x5 x6`；verify 使用 `ds` 返回值的字符串断言，使缺变量、乱序或未知额外变量均 FAIL。发布 variable labels 为英文；中文解释只在注释 / README。`y0`、`y1`、`tau`、`eta`、`ps_true`、`noise` 等 oracle / build-time 变量不得发布。
- `data/selection/README.md` 记录项目内模拟 provenance、Stata version、seed、完整 DGP、estimand、发布与未发布变量及重建命令；`data/manifest-extra.txt` 按字母序登记 `teaching-treatment`，并与 `.dta` 双向一致。
- 图形标签默认英文；用户要求中文时先询问。
- 主路径使用内置 `estimates table`；`estout` 不成为默认依赖。若未来改用 `esttab`，必须先声明社区依赖、缺包 sentinel / 跳过策略并重新实测，本版本不作该替换。
- Optional 社区依赖锁定为 SSC `ebalance` 1.5.4；文档安装命令是 `ssc install ebalance`，最小二组语法是 `ebalance treat covarlist, targets(1)`。verify 只探测已安装包，不联网安装。
- 已安装 `ebalance` 时，不写 `generate()` 的默认权重变量为 `_webal`；指定权重变量使用 `generate(ebw_verify)`。verify 必须断言 `e(convg)==1`，在 `e(sample)` 适用样本内权重非缺失且非负，并通过 `preserve` / `restore` 和 `estimates restore ipwra_atet` 恢复主数据与主估计状态。
- 缺少 `ebalance` 时只输出纯 `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ebalance__`；该 sentinel 在默认与 `--community` 两模式都 PASS。同一 log 出现真实 Stata 错误时仍必须 FAIL，sentinel 不得掩盖错误。
- `psmatch2.md` 独立负责社区包契约。安装命令为 `ssc install psmatch2`；默认不写 `ate` 时估计 treated-effect / ATT 语义，`psmatch2 treat x1 x2 x3 x4, outcome(y) neighbor(1) ate` 才是最小 ATE 示例。本机 v4.0.12 不存在 `att` option；selection 主 estimand ATET 与社区默认 ATT 只是术语对齐。`psmatch2` 不是 `teffects psmatch` 的同一实现。若未先检查本机 help/source，不锁定 `r(att)`、`r(ate)`、权重变量或 `_support` 名称。
- `psmatch2` 为 optional 社区敏感性/兼容性对照，不是默认主路径，不强制安装；verify 缺包只输出 `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__psmatch2__`，默认与 `--community` 两模式均 PASS。已安装时运行最小烟测，断言实际返回结果非缺失及匹配权重或匹配样本存在；真实 Stata 错误仍 FAIL。

### 6.4 验证与发布 Acceptance 条件

以下条件必须全部满足。验收证据分层：shell 静态检查只验证文件、计数、字段和字符串；Stata verify 验证命令执行与 N、处理率 `[0.20, 0.30]`、ATET 容差 `abs(_b[...]-.5)<=.15`、exact varlist 以及 balance / overlap 命令成功；prompt harness 验证 `route_branch` 与 `expected_actions`。人工 review 只负责制度证据和其他不能由模拟数据证明的识别假设；“可辩护”不是 shell 可以证明的结论。

- `verify-selection.do` 与 `verify-identification.do` 的物理首行均为 `version 19.5`，前 10 行内各有合法文件级 `VERIFY CONTRACT`；section 不添加 harness 未消费的 metadata，两个新入口保持默认 1:1 映射。
- selection verify 覆盖 exact varlist、数据不变量、原始失衡、IPWRA ATET 数值断言、模型归属明确的 balance、无 `atet` 且只检查成功的 overlap、官方 PSM、独立 optional `psmatch2`（默认不写 `ate` 为 treated-effect / ATT 语义；显式 `ate` 为 ATE；v4.0.12 不存在 `att` option）、IPW、NN、optional `ebalance`、原尺度主表与独立平衡 log；每个内置 estimator 显式存储。
- identification verify 覆盖 consistency、SUTVA / no interference、design-specific exchangeability、positivity / overlap、estimand 及 power / precision 分离的可执行示例；自然语言路由主要由 prompts 验证。
- `test-prompts.json` 必须是合法 JSON，每个实际 `stata-*/SKILL.md` 至少有一条覆盖；锁定的 `route_branch` 锚点都有 expected action，其中 `router-entry` 覆盖通用设计选择 / 能否识别入口，`synth-sdid` 的场景与动作覆盖 `synth` / `sdid` 析取条件；named-method prompt 断言直达，并覆盖本地 gate 失败返回 router 与 standard DID 失败后检查该面板政策子分支。
- `verify/test-prompts.sh` 从实际 `stata-*/SKILL.md` 动态派生 expected skill，不保留 jq / Python 固定数组；`.github/workflows/verify.yml` 不保留“覆盖 8 skill”文案；`bash verify/test-prompts.sh` 退出码为 0。
- `bash verify/test-harness.sh` 退出码为 0，且明确证明纯 `ebalance` 与 `psmatch2` optional sentinel 在默认与 `--community` 两模式都 PASS、optional sentinel 加真实 Stata 错误仍 FAIL。
- `bash verify/check-claims.sh` 退出码为 0，并明确报告 skill / verify / prompt / ADR / badge 动态计数一致；`bash verify/run-verify.sh --static` 退出码为 0。
- `bash verify/run-verify.sh selection` 与 `bash verify/run-verify.sh identification` 均 PASS；`bash verify/run-verify.sh` 全量报告 10/10 PASS。
- 完整验证后才生成或刷新 `verify/verify-selection.log` 与 `verify/verify-identification.log`、更新 README 的“本机实测 10/10 PASS”，并按 ADR-0005 把 raw logs 作为当前证据保留。
- 静态扫描必须通过：运行时 stop rules 标记唯一；无旧 ADR 文件名、无 8→9 或 9-skill 等旧迁移数量、无已移除方法的 section / reference / 指针、无非法 propensity 函数、非法 balance 选项或连续结果指数化选项；ATET 扫描只约束四类 treatment-effect estimation 命令，排除 postestimation；决策编号完整，8+3 references 的数量和文件名无漂移。

上述 6.1–6.4 的每一项都是 Accepted 的必要条件；任一项未通过，ADR-0006 都保持 Proposed。中间 tickets 不得独立发布或合并，也不得提前更新最终当前态声明。不得用本节前的摘要、单项 PASS 或部分验证替代完整清单。

## 未来再评估

当新增真实用例、验证证据或运行时约束改变时，重新评估 panel selection 是否进入 v1、router 是否仍应保持当前分支顺序、`sdid` 的支持范围是否需要扩展，以及 `psmatch2` optional 对照是否仍值得保留。评估应同时更新 stop rules、references、verify 与 Acceptance 契约；在证据不足时维持现有边界，不把未来工作写成当前能力。

## 后果

### 正面

- 仓库中会出现四个方法入口和一个独立 router；目录数、入口文件及 prompt 覆盖均可直接计数。
- 面板政策设计的公共 gate 与两个子分支分开，standard DID 的 parallel trends 失败不会遮蔽可能适用的 `synth` / `sdid`。
- `stata-did-community/references/sdid.md` 与 `stata-did-community/references/workflow-8step.md` 纳入同一发布契约，避免 router 已支持多处理单位 / 日期而运行时 reference 仍把 `sdid` 缩成单处理单位。
- 完整 stop rules 在运行时范围内只有 `identification-decision-tree.md` 一个带标记的权威副本；本 ADR 摘要不制造运行时副本误报。
- 固定真 ATET = 0.5 的模拟数据允许 selection verify 使用数值断言，而不发布 oracle 变量。
- ADR-0003 的外部扩展数据保护保持不变，同时项目内生成数据获得可复现而不过度套用下载 / 许可要求的治理路径。
- `ebalance` 与 `psmatch2` 缺失时各自留下明确 optional sentinel；默认与 `--community` 两种 harness 行为可分别测试，且已安装 `psmatch2` 时有独立最小烟测。

### 负面

- 发布需要新增两个 skill、两个 verify 入口、受治理数据及 references，并同步 README、AGENTS、CONTRIBUTING、CITATION、CLAUDE、workflow、prompt 与验证计数；这些文件变化可由 diff 和计数检查观察。
- 方法 skill 与 router 的边界变更需要同时更新本地指针、`stata-did-community/references/sdid.md`、`stata-did-community/references/workflow-8step.md` 和带 `route_branch` 的路由行为回归；静态检查和 prompt 测试分别检查运行时文档与行为契约。
- `data/manifest-extra.txt` 与 AGENTS 的治理说明需要维护两个分支；外部来源数据仍承担 ADR-0003 的 README、license / provenance、download script 与 `EXPECTED_SIZE` 成本。
- 模拟数据只验证已声明 DGP 下的命令与数值行为，不提供真实研究中的 conditional exchangeability 证据，也不支持外推有效性声明；社区 `psmatch2` smoke test 只验证可执行契约，不证明方法优越性。
- v1 不覆盖 `cem`、Heckman、面板 selection、ML causal 或连续 / 多值 treatment；`cem` 不建立任何仓库入口，Heckman 请求只获得外部范围说明或停止当前路径，其余项目保持明确排除或 future-work。
- 中间 tickets 不能独立发布或合并；历史快照不回写，活跃当前态声明必须等最终证据，增加了发布顺序约束。

## 拒绝方案

- **只建 `stata-selection`，不建 router。** 被拒：跨 DID、RDD、IV 与 selection 的设计判断不属于单一 selection 方法。
- **把 `synth` 或 `sdid` 作为并列 assignment mechanism，或拆成两个顶层 route branch。** 被拒：二者仍属于 DID / 面板政策设计支柱，并共享 `route_branch: synth-sdid`；方法适用条件在该子分支内部析取。
- **把“一个或极少处理单位”设为 `sdid` 必要条件。** 被拒：该条件通常属于 `synth`；`sdid` 支持单个或多个处理单位及当前实现支持的多个处理日期，其入口取决于充分处理前 / 后期、untreated / not-yet-treated comparison units 及方法特定条件。
- **把 standard DID 的 parallel trends 作为 `synth` / `sdid` 的父级 gate。** 被拒：这会在 standard DID 失败时错误地跳过同支柱的替代设计；parallel trends 只约束 standard DID 子分支。
- **standard DID 失败后直接进入 selection。** 被拒：公共 gate 成立时必须先检查 `synth` / `sdid` 的方法特定条件。
- **要求项目内模拟数据提供外部许可和下载脚本。** 被拒：ADR-0006 对 ADR-0003 作窄化补充，项目内生成分支改用固定 version / seed / DGP、checked-in build 与不变量验证。
- **v1 纳入 Heckman。** 被拒：样本选择模型不属于本次横截面 treatment selection-on-observables 的锁定范围。
- **默认运行全部 estimator，包括 `psmatch2`。** 被拒：v1 固定 `teffects ipwra ..., atet` 为默认主估计；官方 teffects 命令用于规范对照，`psmatch2` 只用于社区敏感性/兼容性对照，不强制安装，也不得暗示优于 IPWRA。
- **把 treatment-effect estimation 与 postestimation 混为一谈。** 被拒：四类 treatment-effect estimation 命令必须带 `atet`，但 `teffects overlap` 是 postestimation。
- **把完整路由复制到各方法 skill，或扫描 spec / ADR 计数副本。** 被拒：唯一性只约束运行时 skill / references；各方法 skill 只留最短本地边界和指针。
- **在结构同步 ticket 提前宣称实测 10/10。** 被拒：README 的本机 PASS、raw logs 当前证据和 ADR Accepted 都只能在最终全量验证后更新。

## 状态

Accepted。2026-08-26 同轮验证满足第 6.1–6.4 节全部 Acceptance 条件：`test-prompts.sh`、`test-harness.sh`、`check-claims.sh` 与 static verify 全部退出 0；selection、identification 和全量 Stata 验证报告 10/10 PASS；README 当前态与 10 份 raw logs 已基于同一轮证据更新。
