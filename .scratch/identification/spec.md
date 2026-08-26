# Spec: `stata-selection` + `stata-identification` 双 skill

- **状态**：Proposed（锁定于 2026-08-25）
- **实施 ADR 草案**：[ADR-0006](../../docs/adr/0006-identification-four-pillars.md)（ADR-0006）
- **当前状态**：仓库当前仍有 8 个 skill；现有验证与文档计数仍是迁移前状态。10 个 skill 是 Proposed 实施完成后的目标状态，不是当前事实。
- **范围变化**：实施完成后仓库由 8 个 skill 扩展为 10 个 skill
- **下游用途**：本文件是可直接拆 ticket 的闭合实施契约；没有未决项

---

## 1. 目标

1. 同时新增 `stata-selection` 与 `stata-identification`，把仓库扩展为 10 个 skill，并保持 skill、verify 入口、Agent prompt 三类覆盖一致。
2. 把现有 DID、RDD、IV 与新的 selection-on-observables 组织成四个方法支柱；`stata-identification` 是横切路由与共同假设入口，不是第五个估计方法。
3. 用顺序化 stop rules 先判断识别设计，再进入方法 skill；当没有可信识别设计时，停止因果声明。
4. 为横截面、二元处理、selection-on-observables 提供以 `teffects ipwra ..., atet` 为主估计的可执行教学路径、受治理的模拟数据和独立验证入口。
5. 把路由边界、数据生成、验证、文档同步和 ADR 状态转换写成可验收的实施合同。

## 2. 非目标

- 本版本不覆盖面板 selection 修正、Wooldridge 反事实面板、CRE 或 `xtpsmatch`。
- 本版本不覆盖 DML、causal forest、DoubleML、连续或多值处理。
- 本版本不纳入样本选择模型 `heckman`，也不新增其 reference 或 verify section。
- `cem` 不进入本版本。
- `psmatch2` 不作为默认主估计；它作为社区敏感性/兼容性对照独立维护，不得暗示优于 IPWRA。`teffects-psmatch.md` 只负责官方 `teffects psmatch`；`psmatch2.md` 独立负责社区包 `psmatch2` 的安装、常用匹配语法、ATT/ATE estimand、权重/匹配样本、标准误和限制。
- `ebalance` 只是可选社区扩展，不进入默认必跑主路径。
- 不把 synth 或 sdid 拆成新 skill；二者仍归 `stata-did-community`。
- 不新增 NSW 或其他外部实证数据；本版本只发布受治理的模拟教学数据。
- 不为两个新 skill 强制新增 demo。ADR-0002 允许 verify 无 demo；以后出现独立端到端演示需求时再补。
- 不承诺任何无法由文件、命令或测试验证的覆盖性或发表适用性结论。

## 3. 架构边界

仓库的四个方法支柱是：

1. RDD：`stata-rdd`
2. IV：`stata-regression` 的 IV references
3. DID：`stata-did` 与 `stata-did-community`
4. selection-on-observables：`stata-selection`

`stata-identification` 维护完整的跨设计 stop rules、共同假设和通用论文表述。RCT / 随机分配位于 stop rules 的第一位，因为它优先于四个观察性方法支柱；仓库本版本不为 RCT 新建独立估计 skill。完整 stop rules 的「唯一副本」只约束运行时材料：静态扫描范围限定为 `stata-*/SKILL.md` 与 `stata-*/references/*.md`，其中 `identification-decision-tree.md` 的 `<!-- identification-stop-rules: full -->` 标记必须恰好出现一次；spec、ADR 与历史文档可记录摘要，不纳入副本计数。每个方法 skill 只保留最小进入条件、失败动作和返回 router 的指针，不复制完整树。

数据形状、变量名和用户关键词只能触发检查，不能证明识别假设成立。例如，存在面板和政策年份只触发政策设计公共 gate，不自动证明标准 DID 的 parallel trends。公共 gate 后，通常一个或极少处理单位、较长前期和 donor pool 触发 `synth` 检查；充分处理前 / 后期和 untreated / not-yet-treated comparison units 则触发 `sdid` 检查，后者支持单个或多个处理单位及当前实现支持的多个处理日期。存在 cutoff 不等于阈值附近不可操纵，变量名叫 instrument 不等于排除限制成立，拥有大量协变量也不等于无未观测混杂。

## 4. 正式实施文件清单

### 4.1 新增文件

```text
stata-selection/
├── SKILL.md
└── references/                              # 恰好 8 个
    ├── teffects-psmatch.md                  # 官方 teffects psmatch
    ├── psmatch2.md                            # 社区包 psmatch2
    ├── teffects-nnmatch.md
    ├── teffects-ipw.md
    ├── teffects-ipwra.md
    ├── ebalance.md
    ├── balance-overlap.md
    └── selection-paper-writing.md

stata-identification/
├── SKILL.md
└── references/                              # 恰好 3 个
    ├── identification-common-assumptions.md
    ├── identification-decision-tree.md
    └── identification-paper-writing.md

data/selection/
├── teaching-treatment.dta
├── build-teaching.do
└── README.md

verify/
├── verify-selection.do
├── verify-identification.do
├── verify-selection.log                     # ADR-0005 的最近一次完整验证记录
└── verify-identification.log                # ADR-0005 的最近一次完整验证记录

docs/adr/
└── 0006-identification-four-pillars.md
```

### 4.2 修改文件

```text
stata-did/SKILL.md                            # 标准 DID 子分支 + router 指针
stata-did-community/SKILL.md                  # synth/sdid 子分支 + router 指针 + 10-skill 文案
stata-did-community/references/sdid.md        # sdid 多处理单位/日期 + 单单位推断特例
stata-did-community/references/workflow-8step.md # 拆开 Synthetic Control 与 Synthetic DiD
stata-rdd/SKILL.md                            # 最短本地边界 + router 指针 + 10-skill 文案
stata-regression/SKILL.md                     # IV 直达规则 + router 指针

test-prompts.json                            # 新 skill 覆盖 + route_branch 路由矩阵
verify/test-prompts.sh                       # 动态派生实际 skill + 审计 route_branch
data/manifest-extra.txt                      # 登记数据 + 顶部维护说明改为两分支治理
README.md                                    # 结构先更新；实测 10/10 只在最终证据后声明
AGENTS.md                                    # 8→10 地图 + 两分支数据治理 + version 规则
CONTRIBUTING.md                              # 当前贡献、数据、验证和 10-skill 契约
CITATION.cff                                # 当前 10-skill 软件元数据
CLAUDE.md                                    # 当前项目地图与 ADR；读取现有改动后最小合并
.github/workflows/verify.yml                 # prompts 注释与预期 10-skill 文案

docs/run-stata.md                            # 首行改为 10 份
verify/run-verify.sh                         # 帮助与注释中的结构目标数、目标名列表改为 10
verify/check-claims.sh                       # 10-entry 文案 + 动态 N_ADR/README ADR 计数断言
verify/test-harness.sh                       # 纯 optional ebalance sentinel 双模式 PASS 探针
```

`verify/lib/targets.sh` 保持不变：两个新 skill 都采用默认 1:1 映射，`stata-selection` → `verify-selection.do`，`stata-identification` → `verify-identification.do`。只有将来某个入口委托给不同 do-file 时，才修改该注册表。

活跃贡献、发行与 CI 元数据必须同步，包括 `CONTRIBUTING.md`、`CITATION.cff`、`.github/workflows/verify.yml` 与 `CLAUDE.md`。`CLAUDE.md` 当前含用户未提交改动；实施该文件时必须再次读取磁盘当前内容，只做最小合并，不得用草案缓存或整文件覆盖。`CHANGELOG.md`、`LUBAN-REPORT.md` 是历史快照，不回写旧数字；`demo/REPORT.md` 如仅描述既有 demo 运行，同样不回写。`.scratch/identification/build-teaching.do` 是已修正草稿来源，正式实施时复制其内容到 `data/selection/build-teaching.do`，不把 `.scratch/` 当发布入口。

## 5. 锁定决策（20 条）

| # | 决策 | 锁定结论 |
|---|---|---|
| Q1 | skill 数量 | 同时新增两个 skill，仓库统一为 10 个 skill。 |
| Q2 | 识别架构 | DID、RDD、IV、selection-on-observables 是四个方法支柱；`stata-identification` 是横切 router。 |
| Q3 | 路由形态 | 使用 RCT → RDD → IV → 面板政策设计公共 gate → standard DID 或 synth/sdid → 横截面 selection → 停止因果声明的顺序 stop rules；standard DID 的 parallel trends 失败后仍检查 synth/sdid。 |
| Q4 | trigger ownership | 通用设计选择归 router；明确点名 DID、RDD、IV、PSM、IPW 或 `teffects` 时直达对应方法 skill。 |
| Q5 | 共同假设 | common assumptions 固定覆盖 consistency、SUTVA/no interference、design-specific exchangeability、positivity/overlap 与 estimand。 |
| Q6 | MDE 归属 | MDE 只进入 power/precision，不写成识别假设。 |
| Q7 | selection 范围 | 本版本只覆盖横截面、二元处理、处理前可观测混杂。 |
| Q8 | 默认 estimand | 所有 treatment-effect estimation 示例统一用 Stata 术语 ATET；`teffects ipwra`、`teffects psmatch`、`teffects ipw` 与 `teffects nnmatch` 均显式写 `, atet`。`teffects overlap` 是 postestimation，不接受也不需要 `atet`。 |
| Q9 | 默认估计量 | 主估计是 `teffects ipwra`，准确称为 IPW regression adjustment 双重稳健估计量。 |
| Q10 | 双重稳健边界 | 在识别假设与 positivity 成立时，outcome model 与 treatment model 至少一个正确才有双重稳健保证。 |
| Q11 | 方法区分 | `teffects ipwra` 不等于 `teffects aipw`，也不等于 DID 的 `hdidregress aipw`。 |
| Q12 | selection 强制路径 | 设计与处理前协变量 gate → 原始数据检查 → IPWRA ATET → `tebalance summarize` → propensity overlap → PSM/IPW/NN 对照 → 主表与独立平衡附表。 |
| Q13 | 比较原则 | 每个估计显式 `estimates store`；正确设定时各 estimator 应接近同一 ATET，不预设谁系统高估。 |
| Q14 | 出表策略 | 本版本主路径用内置 `estimates table`；连续结果保持原尺度，平衡表独立列示。 |
| Q15 | selection references | 恰好 8 个，名称与第 4.1 节一致，并包含独立 `psmatch2.md`；`teffects-psmatch.md` 只负责官方 `teffects psmatch`，`psmatch2.md` 负责社区包安装、常用匹配语法、ATT/ATE、权重/匹配样本、标准误和限制。 |
| Q16 | identification references | 恰好 3 个，分别承载 common assumptions、decision tree 与 paper writing。 |
| Q17 | 社区包 | `ebalance` 可选，安装命令与语法以已核实的 SSC 1.5.4 help/source 为准；纯 optional sentinel 在默认与 `--community` 两模式都 PASS，并由 harness 探针锁定。 |
| Q18 | 教学数据 | N=2000、seed 20260825、约 25% Bernoulli treatment、固定 tau=0.5，只发布 `id treat y x1-x6`。 |
| Q19 | 验证结构 | 两个新 skill 各有默认 1:1 verify 入口；文件级 VERIFY CONTRACT，section 不加 harness 未消费的 metadata。 |
| Q20 | ADR 与 demo | ADR 统一为 ADR-0006；通过全部验收后才改 Accepted；本版本不强制 demo。 |

## 6. `stata-identification` 顺序化 stop rules

### 6.1 路由前置问题

Router 先定义 treatment、outcome、unit、时间结构、处理时点、目标总体与 estimand，再依次问：

1. 分配是否真实随机？随机化通常支持 ITT，但先明确适用的 estimand。
2. 是否有预先确定的运行变量与 cutoff？
3. 是否有可辩护的外生工具变量？
4. 是否有明确政策时点、处理前后信息、未处理 donor / control，并且 no anticipation、no interference 等面板政策设计公共条件可辩护？若是，再分叉检查 standard DID 与 `synth` / `sdid`。
5. 若以上均否，是否能辩护所有共同原因均为处理前可观测变量且有 overlap？

任何一步都要区分“数据中存在某列”与“设计假设有制度或研究设计证据”。匹配到首个成立的 stop rule 即停止继续选方法。面板政策设计先通过公共 gate，再比较两个子分支：standard DID 需要可辩护的 parallel trends；`synth` / `sdid` 共享另一个子分支，但进入条件按方法析取。`synth` 通常要求一个或极少处理单位、较长前期和可辩护 donor pool；`sdid` 要求充分处理前 / 后期与 untreated / not-yet-treated comparison units，支持单个或多个处理单位及当前实现支持的多个处理日期，并检查 weighting、latent-factor / regularity 与方法特定推断条件。两者都不以 standard DID 的 parallel trends 为进入条件。因此 standard DID 的 parallel trends 失败时仍须检查 `synth` / `sdid`，不能直接踢去 selection；只有公共 gate 或两个子分支都失败时才进入下一支柱。

### 6.2 完整 stop rules

| 顺序 | 进入条件 | 关键识别假设 | 失败去向 | 路由结果 |
|---|---|---|---|---|
| 1. RCT / 随机分配 | 处理或鼓励由可审计的随机机制分配 | 随机化通常支持 ITT，但先明确适用 estimand；处理随机化完整性、consistency、SUTVA / no interference、attrition 与 noncompliance | 进入 RDD 检查；随机鼓励且有不服从时可在 IV 分支论证 LATE | `stata-identification` 固化设计与 estimand；需要常规结果模型时再指向 `stata-regression` |
| 2. RDD | treatment probability 在预定运行变量 cutoff 发生跳跃 | cutoff 附近潜在结果连续、无精确操纵、局部 positivity；fuzzy RDD 还需 first stage 与 IV 类假设 | 进入 IV 检查 | `stata-rdd` |
| 3. IV | 有影响 treatment 的候选工具，且制度故事可支持其外生性 | relevance、independence、exclusion；二元工具 LATE 还需 monotonicity 与 SUTVA | 进入面板政策设计公共 gate | `stata-regression` 的 IV references |
| 4. 面板政策设计公共 gate | 有明确政策时点、处理前后信息和未处理 donor / control；处理并非由单一 cutoff 或工具识别 | no anticipation、SUTVA / no interference、稳定构成，以及目标时点和比较单位可定义 | 公共 gate 失败则进入横截面 selection 检查；通过则同时检查 4a 与 4b | 保留在 DID / 面板政策设计支柱内分叉 |
| 4a. standard DID | 公共 gate 已成立，且有足够的处理组与对照组 / 可比较单位支持 DID 比较 | 与具体设计匹配、可辩护的 parallel trends，以及相应 overlap / composition 条件 | parallel trends 失败仍进入 4b，不得直接进入 selection；其他条件失败也检查 4b | `stata-did`；适用的 DID 社区估计量进入 `stata-did-community` |
| 4b. synth / sdid | 公共 gate 已成立，并满足任一方法入口：`synth` 通常为一个或极少处理单位、较长前期、可辩护 donor pool；`sdid` 有充分处理前 / 后期和 untreated / not-yet-treated comparison units，支持单个或多个处理单位及当前实现支持的多个处理日期 | `synth`：donor 可比性、充分前期拟合、无同期独特冲击及 placebo / 推断条件；`sdid`：weighting、latent-factor / regularity 与方法特定推断条件 | 4a 与 4b 的两个方法入口都不成立时进入横截面 selection 检查 | `stata-did-community` 的 synth 或 sdid reference |
| 5. 横截面 selection-on-observables | 二元处理；所有被用作调整的变量均在处理前测量；研究者能辩护无未观测混杂 | consistency、SUTVA / no interference、conditional exchangeability、positivity / overlap、明确 ATET | 停止因果声明 | `stata-selection` |
| 6. 无可信识别设计 | 前述分支均无法满足进入条件和关键假设 | 不适用 | 无下一因果分支 | 明确写“当前数据只支持描述或关联”；可转 `stata-descriptives` / `stata-regression`，但不使用因果措辞 |

### 6.3 Trigger ownership

| 用户表述 | 首个 skill | 规则 |
|---|---|---|
| “该选什么设计”“这能否识别”“我能不能作因果解释” | `stata-identification` | 执行完整 stop rules。 |
| 明确点名 DID、事件研究、csdid、synth、sdid | `stata-did` 或 `stata-did-community` | 直达方法 skill，不先绕 router；本地假设失败时返回 router。 |
| 明确点名 RDD、断点、rdrobust | `stata-rdd` | 直达；本地边界失败时返回 router。 |
| 明确点名 IV、2SLS、ivregress、ivreg2、LATE | `stata-regression` | 直达 IV reference；本地边界失败时返回 router。 |
| 明确点名 PSM、`psmatch2`、IPW、IPWRA、`teffects`、entropy balancing | `stata-selection` | 直达；点名 `psmatch2` 时进入社区 reference；主路径仍 IPWRA → balance/overlap → 官方 teffects 对照。 |
| 只描述数据形状或政策关键词，没有方法与假设证据 | `stata-identification` | 关键词只触发询问，不直接证明某分支成立。 |

完整 stop rules 只在 `stata-identification/references/identification-decision-tree.md` 的运行时副本维护，并带唯一标记 `<!-- identification-stop-rules: full -->`。静态唯一性扫描只遍历 `stata-*/SKILL.md` 与 `stata-*/references/*.md`；本 spec、ADR 和历史文档的摘要不计入。各方法 skill 的本地踢走段只保留三件事：本方法最小进入条件、失败时停止本方法、指向 `stata-identification` 重新路由。

## 7. 共同识别假设契约

`identification-common-assumptions.md` 必须把以下条目并列写清，并为每条严格采用“定义 → 需要的证据 → 失败后能说什么”结构：

| 条目 | 最小定义 | 失败后的结论 |
|---|---|---|
| Consistency | 个体实际接受处理水平下的观测结果等于该处理水平对应的潜在结果；处理版本需定义清楚 | 处理效应对象未定义，停止因果解释 |
| SUTVA / no interference | 一个单位的结果不受其他单位处理状态影响，且没有未区分的处理版本 | 改写 exposure mapping、聚类或 spillover estimand；未解决前停止原 estimand 的因果解释 |
| Design-specific exchangeability | 可比性来自具体设计：随机化独立性、RDD 局部连续性、IV 外生性与排除限制、standard DID 平行趋势、`synth` 的 donor / 前期拟合条件、`sdid` 的 weighting / latent-factor / regularity 条件、selection 条件可交换性 | 当前子分支不能识别目标效应；按 router 的同级或下一分支继续检查 |
| Positivity / overlap | 目标总体相关协变量或设计局部内，各处理状态有正概率或有效比较单位 | 缩小目标总体、改变 estimand 或停止；不能靠 estimator 名称修复 |
| Estimand | 明确 ATE、ATET、LATE、局部 RDD 效应、group-time ATET 等对象、总体和时间窗口 | 不允许只报告“处理效应”而不说明对谁、何时、何种处理对比 |

MDE、样本量、标准误与置信区间宽度放入 power/precision 小节。MDE 失败表示研究可能不精确，不自动表示识别失败；反之，高 power 也不能修复无效设计。

`identification-paper-writing.md` 只提供可审计的论文表述骨架：estimand、分配或制度机制、假设、支持性诊断、无法由诊断证明的部分、目标总体和外推边界。任何平衡检验、前趋势检验、密度检验、第一阶段或过度识别检验都只能作为支持性证据（设计证据的一部分），不能写成假设已被证明；论文必须说明机制、目标总体与外推边界。

## 8. `stata-selection` 实施契约

### 8.1 范围与 estimand

- 处理必须是横截面二元变量，教学数据中为 `treat`。
- 默认 estimand 固定为 ATET；所有 treatment-effect estimation 命令——明确包括 `teffects ipwra`、`teffects psmatch`、`teffects ipw` 与 `teffects nnmatch`——都显式指定 `, atet`。`teffects overlap` 是 postestimation，保持无 `atet`。
- 协变量 gate 只允许处理前变量。mediator、处理后结果、collider 和仅为提高 treatment 预测而加入的 instrument 不得进入 adjustment set。
- selection-on-observables 是识别假设，不由高拟合度、平衡改善或大量控制变量自动成立。

### 8.2 IPWRA 的准确表述

`teffects ipwra` 是 IPW regression adjustment 双重稳健估计量。它同时拟合 outcome model 与 treatment model，但算法和 estimating equations 与 `teffects aipw` 不同；它也与 DID 命令 `hdidregress aipw` 的 group-time 设计不同。

“双重稳健”只在 consistency、SUTVA/no interference、conditional exchangeability、positivity 与目标 estimand 已成立的前提下，表示 outcome model 或 treatment model 至少一个正确即可获得一致性。两类模型都错、overlap 失败或存在未观测混杂时，该标签不提供保护。

### 8.3 强制路径

强制路径按以下顺序执行，不允许把 postestimation 提前：

1. 设计 gate：定义 treatment、outcome、目标总体、ATET；逐项证明 adjustment set 是处理前变量，并记录无未观测混杂为何可辩护。
2. 原始数据检查：精确变量清单、唯一键、样本量、二元处理、缺失、处理比例、原始组间均值与离散程度。此阶段使用描述命令，不调用 treatment-effect postestimation。
3. 主估计：`teffects ipwra ..., atet`，随后立刻 `estimates store ipwra_atet`。
4. 首次平衡诊断必须紧跟 IPWRA：输出明确标题，运行 `tebalance summarize`，再运行 `teffects overlap`。这两条 postestimation 的模型归属都是 `ipwra_atet`；若在表格阶段重跑，必须先 `estimates restore ipwra_atet`。
5. 运行 PSM 与 IPW 对照；NN matching 是额外内置敏感性对照。每个结果都显式存储。
6. 用内置 `estimates table` 输出原尺度 ATET 主表。v1 的平衡附表产物只要求 verify log 中有独立、带标题的 `tebalance summarize` 输出；不自动拼入主结果表。`selection-paper-writing.md` 再提供可选导出方案。

教学数据上的规范代码形状如下，正式实现必须由 `verify/verify-selection.do` 在 StataNow 19.5 实测：

```stata
version 19.5
use "../selection/teaching-treatment", clear

ds
local actual `r(varlist)'
local expected id treat y x1 x2 x3 x4 x5 x6
assert "`actual'" == "`expected'"
isid id
assert _N == 2000
assert inlist(treat, 0, 1)
assert !missing(id, treat, y, x1, x2, x3, x4, x5, x6)
tabulate treat
tabstat y x1-x6, by(treat) statistics(n mean sd min max)

teffects ipwra (y x1-x4) (treat x1-x4), atet
estimates store ipwra_atet
display "=== BALANCE APPENDIX: IPWRA ATET ==="
tebalance summarize
teffects overlap

teffects psmatch (y) (treat x1-x4), atet nneighbor(1)
estimates store psm_atet

teffects ipw (y) (treat x1-x4), atet
estimates store ipw_atet

teffects nnmatch (y x1-x4) (treat), atet
estimates store nn_atet

estimates table ipwra_atet psm_atet ipw_atet nn_atet, ///
    b(%9.3f) se(%9.3f) stats(N)
```

首次 `tebalance summarize` 已在主估计后立即运行。若论文表阶段需要再次打印平衡附表，只允许使用以下归属恢复形状：

```stata
estimates restore ipwra_atet
display "=== BALANCE APPENDIX: IPWRA ATET ==="
tebalance summarize
```

`teffects overlap` 在 verify 中只检查命令成功；不 `graph export`，不保存或跟踪图形产物。v1 没有 selection/identification demo。交互使用时 overlap 图默认英文标签；若用户要求中文，按仓库作图规则先询问。

主路径不依赖 `estout`。如果后续 ticket 改用 `esttab`，必须把 `estout` 声明为社区依赖，定义缺包时的 sentinel/跳过策略，并重新实测；本版本不作该替换。

PSM、IPW、IPWRA 和 NN 在识别假设及各自模型设定正确时，都以同一 ATET 为目标并应在抽样误差范围内接近。文档不得预设 PSM 系统高估，也不得声称只有 IPWRA 能接近真值；估计差异触发的是 overlap、模型设定、匹配质量与有限样本诊断。

### 8.4 Reference 职责

| Reference | 唯一职责 |
|---|---|
| `teffects-psmatch.md` | 只负责官方 `teffects psmatch`、caliper/neighbor 与匹配质量 |
| `psmatch2.md` | 独立负责社区包 `psmatch2` 的安装、常用匹配语法、ATT/ATE estimand、权重/匹配样本、标准误和限制；不是默认主估计，不暗示优于 IPWRA |
| `teffects-nnmatch.md` | 直接协变量 NN matching、metric、bias adjustment 与适用边界 |
| `teffects-ipw.md` | propensity model、权重、极端概率与 ATET 解释 |
| `teffects-ipwra.md` | 默认估计量、双重稳健条件、与另外两种 AIPW 命令的区别 |
| `ebalance.md` | 可选 entropy balancing 扩展、经核实的安装/权重语法与 optional sentinel 约定 |
| `balance-overlap.md` | 原始失衡、IPWRA postestimation 归属、propensity overlap、positivity 失败后的处理 |
| `selection-paper-writing.md` | 原尺度 ATET 主表、log 中独立平衡附表、可选导出方案、识别假设与限制写法；不自动把 balance 拼入主表 |

### 8.5 `ebalance` 已核实依赖契约

已在 StataNow 19.5 MP 核实 `ebalance` 源码版本为 1.5.4（2015-01-29）；SSC/RePEc provenance 为 `http://fmwww.bc.edu/repec/bocode/e` 下的 `ebalance.pkg`。安装命令锁定为：

```stata
ssc install ebalance
```

已核实的 help/source 契约：

- 最小二组语法是 `ebalance treat covarlist, targets(1)`；`treat` 必须为 0/1 且两组都存在。
- 不写 `generate()` 时，默认权重变量名是 `_webal`；再次默认调用会替换 `_webal`。
- 指定 `generate(ebw_verify)` 时，权重写入 `ebw_verify`；已存在的同名非默认变量会报错。
- 成功收敛时 `e(convg)==1`，`e(sample)` 标记适用样本；源码为处理组赋权 1，并为控制组生成 entropy weights。

以下完整烟测已在 StataNow 19.5、与教学 DGP 同结构的 N=2000 临时模拟数据上执行通过；两次均收敛，无 Stata 错误码，默认与指定变量断言均通过。`verify-selection.do` 的 optional section 必须使用同一代码形状：

```stata
preserve
capture which ebalance
if _rc {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ebalance__"
}
else {
    ebalance treat x1 x2 x3 x4, targets(1)
    assert e(convg) == 1
    tempvar eb_sample_default
    generate byte `eb_sample_default' = e(sample)
    confirm variable _webal
    assert !missing(_webal) if `eb_sample_default'
    assert _webal >= 0 if `eb_sample_default'
    drop _webal

    ebalance treat x1 x2 x3 x4, targets(1) generate(ebw_verify)
    assert e(convg) == 1
    tempvar eb_sample_named
    generate byte `eb_sample_named' = e(sample)
    confirm variable ebw_verify
    assert !missing(ebw_verify) if `eb_sample_named'
    assert ebw_verify >= 0 if `eb_sample_named'
}
restore
estimates restore ipwra_atet
```

`preserve`/`restore` 保护主数据；最后的 `estimates restore ipwra_atet` 恢复主估计状态。verify 只探测已安装包，绝不在运行中联网安装。缺包分支只输出纯 optional sentinel；该 sentinel 必须由 `verify/test-harness.sh` 证明在默认与 `--community` 两模式都 PASS。

### 8.6 `psmatch2` optional 依赖契约

`psmatch2` 是最常用的社区匹配命令，但不是默认主估计，也不得暗示它优于 IPWRA。`teffects-psmatch.md` 只负责官方 `teffects psmatch`；本 reference 独立负责社区包的安装、常用语法、estimand、权重/匹配样本、标准误和限制。安装命令为：

```stata
ssc install psmatch2
```

已核实的最小 ATE 示例语法形状为：

```stata
psmatch2 treat x1 x2 x3 x4, outcome(y) neighbor(1) ate
```

若要社区 ATT，使用经本机 `help` / source 核实的 `att` 选项。selection 主 estimand ATET 与社区 ATT 只是术语对齐，不能把上述 `ate` 示例称为 ATT；`psmatch2` 不是 `teffects psmatch` 的同一实现。若返回结果或变量名未先由本机 `help psmatch2` / source 检查，不锁定 `r(att)`、`r(ate)`、匹配权重或 `_support` 名称；烟测只断言实际返回结果非缺失，并断言匹配权重或匹配样本存在。

`verify-selection.do` 必须使用 optional sentinel `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__psmatch2__`：缺包在默认和 `--community` 两模式都 PASS，已安装时运行上述最小烟测并断言结果非缺失及匹配权重或匹配样本存在；真实 Stata 错误必须 FAIL。verify 只探测已安装包，绝不强制安装或联网。

## 9. 教学数据契约

### 9.1 DGP

`data/selection/build-teaching.do` 必须与已修正草稿逐项一致：

- `version 19.5`
- `set seed 20260825`
- `set obs 2000`
- `x1`、`x2`、`x4`、`x6` 为标准正态；`x3`、`x5` 为均匀分布
- treatment score：`eta = -1.25 + 0.45*x1 + 0.55*x2 + 0.35*(x3 - 0.5) - 0.40*x4`
- propensity：`ps_true = invlogit(eta)`
- treatment：以 `ps_true` 为概率作 Bernoulli 分配，样本处理率断言在 `[0.20, 0.30]`
- untreated potential outcome：`y0 = 1 + 0.70*x1 + 0.80*x2 + 0.50*x3 - 0.60*x4 + noise`
- 固定处理效应：`tau = 0.5`，因此真 ATET = 0.5
- observed outcome：`y = y0 + treat*tau`
- treatment 与 `y0` 只通过共同的处理前可观测 `x1-x4` 产生原始选择偏误；结果噪声不进入 treatment score

发布文件只保留并按顺序排列：

```text
id treat y x1 x2 x3 x4 x5 x6
```

`y0`、`y1`、`tau`、`eta`、`ps_true`、`noise` 都是 oracle / build-time 变量，不发布到 `.dta`。发布 `.dta` 的 variable labels 使用英文；中文解释保留在 build 注释和 `data/selection/README.md`。图形标签继续遵循项目规则：默认英文，用户要求中文时先询问。

### 9.2 数据治理

ADR-0006 是 ADR-0003 数据条款的窄化补充，不静默推翻 ADR-0003。项目级扩展数据仍由 `data/manifest-extra.txt` 管理，但治理分为两个互斥分支：

1. **外部来源扩展数据**：继续要求 `data/<子目录>/README.md` 记录来源、license 与 provenance，并提供 checked-in `download_*.sh`；下载脚本必须含 `EXPECTED_SIZE` 字节级校验。
2. **项目内生成数据**：要求 `data/<子目录>/README.md`、固定 Stata `version` / seed / DGP、checked-in build do-file，以及 schema 与数值不变量验证；不要求下载脚本或外部许可。

`data/selection/README.md` 按第二分支记录：

1. 数据是项目内模拟生成，不是外部下载；
2. seed、StataNow 19.5、完整 DGP 和约 25% Bernoulli 分配；
3. 目标 estimand 是 ATET，固定真值 0.5；
4. 发布变量、英文 variable labels 与未发布 oracle 变量；
5. 从仓库根目录重建的命令：按 `docs/run-stata.md` 配置二进制后执行 `stata-mp -b do "data/selection/build-teaching.do"`，Windows 使用同文档的 `/e do` 形式；
6. 重建后运行 selection verify 与 manifest 静态检查。

`data/manifest-extra.txt` 按字母序新增基名 `teaching-treatment`，并在文件顶部维护说明中写明上述外部来源 / 项目内生成两分支；`AGENTS.md` 同步同一规则。manifest 与 `data/selection/teaching-treatment.dta` 必须双向一致。

## 10. 验证契约

### 10.1 `verify/verify-selection.do`

文件首行必须是 `version 19.5`，随后在前 10 行内放一个文件级契约：

```stata
version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-selection
* chapter:  selection-on-observables
* data:     selection/teaching-treatment.dta
* checks:   data-invariants+raw-imbalance+ipwra-atet+tebalance+overlap+psmatch+psmatch2-optional+ipw+nnmatch+ebalance-optional+tables
* ============================
```

脚本 section 顺序与验收如下：

1. **data load / invariants**：从 verify harness 的 `data/agis6` cwd 用 `use "../selection/teaching-treatment", clear`；断言 `_N==2000`、`id` 唯一、`treat` 二元、处理率在 `[0.20,0.30]`。发布变量必须用以下 exact varlist 形状验证；缺变量、顺序不同或任何未知额外变量都会使字符串断言失败：

   ```stata
   ds
   local actual `r(varlist)'
   local expected id treat y x1 x2 x3 x4 x5 x6
   assert "`actual'" == "`expected'"
   ```

2. **raw imbalance**：用原始组间统计计算至少一个 `x1-x4` 的绝对标准化差异大于 0.1，并断言未经调整的 outcome 均值差与真值 0.5 相差超过 0.25；不调用 treatment-effect postestimation。
3. **IPWRA ATET**：运行规范主估计并 `estimates store ipwra_atet`；用 `_b[ATET:r1vs0.treat]` 断言 `abs(atet_hat-0.5)<=0.15`。
4. **balance**：首次诊断紧接 IPWRA，先输出 `=== BALANCE APPENDIX: IPWRA ATET ===`，再运行 `tebalance summarize`。模型归属必须是 `ipwra_atet`；若 table section 重印，先 `estimates restore ipwra_atet`。verify 只要求 log 中独立、带标题的输出，不生成单独表文件。
5. **propensity overlap**：运行 `teffects overlap` 并只检查命令成功；不保存、不 export、不跟踪图形产物，也不把目测重叠写成 conditional exchangeability 的证明。
6. **PSM**：显式 `, atet`，`estimates store psm_atet`，断言 ATET 非缺失。
7. **optional psmatch2**：先 `capture which psmatch2`；缺包只输出纯 `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__psmatch2__`。已安装时运行最小 ATE 示例 `psmatch2 treat x1 x2 x3 x4, outcome(y) neighbor(1) ate`；若要社区 ATT，使用经 help/source 核实的 `att` 选项。selection 主 estimand ATET 与社区 ATT 只是术语对齐，不能把 `ate` 称 ATT。先检查本机 help/source，再断言实际返回结果非缺失，并断言匹配权重或匹配样本存在；不锁定未经检查的返回名。真实 Stata 错误必须 FAIL，不强制安装。
8. **IPW**：显式 `, atet`，`estimates store ipw_atet`，断言 ATET 非缺失。
9. **NN**：显式 `, atet`，`estimates store nn_atet`，断言 ATET 非缺失。
10. **optional ebalance**：逐行采用第 8.5 节已实测代码。缺包只输出纯 `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ebalance__`；已安装时同时验证默认 `_webal` 与指定 `ebw_verify`，断言收敛、适用样本无缺失、权重非负，并在结束后恢复主数据和 `ipwra_atet`。
11. **tables**：用存储的四个内置估计输出原尺度 ATET 主表。平衡附表只保留 log 中独立标题输出；可选文件导出属于 `selection-paper-writing.md`，不把 `tebalance` 自动拼入主表。

只写上述文件级 VERIFY CONTRACT。section 用普通注释标题，不新增 harness 不读取的“每节前三行 metadata”。

### 10.2 `verify/verify-identification.do`

文件首行与契约为：

```stata
version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-identification
* chapter:  identification-common-assumptions
* data:     sim:2000x6
* checks:   consistency+SUTVA+exchangeability+positivity+estimand+power-precision-separation
* ============================
```

该脚本采用默认 1:1 入口，以内置模拟命令和 `assert` 验证共同假设/estimand 的可执行示例：

- 构造已知固定效应和随机分配，断言 observed outcome 满足 consistency 的生成等式；
- 用随机分配示例验证 treatment rate/positivity 与已知 ATET 的数值恢复；
- 明确 no-interference 是 DGP 约束，不把样本平衡当成证明；
- 分别显示 ATE/ATET/LATE/局部效应等 estimand 标签，至少对 ATET 做数值断言；
- power/precision 示例只报告 SE、CI 或 MDE，不把它列为识别条件。

跨 skill 的自然语言路由不塞进该 do-file；由 `test-prompts.json` 承担。

### 10.3 `test-prompts.json` 路由矩阵

实施必须新增 `stata-selection` 与 `stata-identification` 的 skill 覆盖。路由 prompt 使用机器可审计字段 `route_branch`；`verify/test-prompts.sh` 必须断言下表每个锁定值至少出现一次，并检查对应 `expected_actions`，不能只靠自然语言或 prompt 顺序猜分支。

| `route_branch` | 场景 | 期望动作 |
|---|---|---|
| `router-entry` | 通用“该选什么设计 / 能否识别” | 首先加载 `stata-identification`，按 stop rules 提问 |
| `rct` | 明确随机分配 | router 停在 RCT，定义 estimand、attrition / noncompliance 与共同假设 |
| `rdd` | 只描述 cutoff，未点名方法 | router 检查进入条件后转 `stata-rdd` |
| `iv` | 只描述候选工具，未点名方法 | router 检查制度证据后转 IV references |
| `standard-did` | 政策面板通过公共 gate，且 parallel trends 可辩护 | 转 standard DID；断言公共 gate 与 parallel trends 是分层条件 |
| `synth-sdid` | 面板政策公共 gate 后满足析取入口：`synth` 通常为一个或极少处理单位、长前期和可辩护 donor pool；或 `sdid` 有充分处理前 / 后期及 untreated / not-yet-treated comparison units | 保持同一 `synth-sdid` 子分支并转 `stata-did-community`；`synth` 检查前期拟合与 donor 条件，`sdid` 支持单个或多个处理单位及当前实现支持的多个处理日期，并检查 weighting、latent-factor / regularity 与方法特定推断条件；两者都不要求先通过 standard DID parallel trends |
| `selection` | 横截面二元处理、处理前可观测混杂 | router 检查后转 `stata-selection` |
| `stop-causal` | 无随机、cutoff、工具、可用政策设计，也无法辩护无未观测混杂 | router 停止因果声明，只允许描述 / 关联 |
| `named-method-direct` | 明确点名 DID、RDD、IV、PSM、`psmatch2`、IPW 或 `teffects` | 直达对应方法 skill；点名 `psmatch2` 直达 `stata-selection` 并进入社区 reference，不强制先加载 router |
| `gate-failure-return` | named-method 本地 gate 失败，或 standard DID parallel trends 失败 | 返回 router；standard DID 失败时先检查同支柱的 `synth` / `sdid`，其后才进入 selection |

selection 完整分析另有 prompt，期望动作固定为：设计 gate → 原始检查 → IPWRA ATET → balance / overlap → 官方 teffects PSM / IPW / NN → psmatch2 社区敏感性/兼容性对照 → 分表；点名 `psmatch2` 直达 `stata-selection` 并进入 `psmatch2.md`。

验收不固定 prompt 总条数，但必须满足：JSON 合法；每个实际 `stata-*/SKILL.md` 至少一条覆盖；10 个 skill 全覆盖；上述 `route_branch` 值均有 expected action；named-method prompt 明确测试“直达而非先绕 router”。`verify/test-prompts.sh` 的 expected skill 集合必须在运行时从实际 `stata-*/SKILL.md` 路径动态派生，再与 JSON 的 `skill` 覆盖集合做差集；删除 jq 与 Python 分支中的原 8-skill 固定数组，不引入新的 10-skill 固定数组。

### 10.4 Harness 与 claims

- `verify/lib/targets.sh` 不修改；默认映射自然发现两个新入口。
- `verify/run-verify.sh` 的目标枚举继续从 `stata-*/SKILL.md` 动态生成；只更新帮助 / 注释中的结构目标数和可选单 skill 名列表。
- `.github/workflows/verify.yml` 的 prompts 注释与 step 文案同步为从实际目录审计预期 10 个 skill，不保留“覆盖 8 skill”等旧说明。
- README hero 的结构声明从 8 skill / 5 ADR 更新为预期 10 skill / 6 ADR；“本机实测 10/10 PASS”只能在 Ticket 9 的全量证据产生后更新，Ticket 8 不得提前写成当前事实。
- `verify/check-claims.sh` 新增 `N_ADR=$(count "$REPO_ROOT"/docs/adr/*.md)`，从 README 第一条 `[0-9]+ ADR` 声明提取 `readme_adr`，断言 `readme_adr == N_ADR`；缺失 ADR 声明或数字不等都 FAIL。现有 skill、prompt、hero 检查同步为预期 10 entries，并把“已实测 10/10”声明留到最终全量验证后。
- optional sentinel 的语义锁定为：纯 `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__<pkg>__` 在默认与 `--community` 两模式都 PASS；若同一 log 有真实 Stata 错误，仍 FAIL。必需 sentinel 语义不变。
- `verify/test-harness.sh` 在现有“optional sentinel + 真实错误必须 FAIL”探针之外，新增以下纯 ebalance sentinel 双模式探针：

  ```bash
  printf 'version 19.5\ndisplay "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ebalance__"\n' > "$PROBE"
  if ! bash "$VERIFY_DIR/run-verify.sh" zzprobe >/dev/null 2>&1; then
    echo "FAIL  harness 探针：纯 ebalance optional sentinel 在默认模式下未 PASS"
    exit 1
  fi
  if ! bash "$VERIFY_DIR/run-verify.sh" zzprobe --community >/dev/null 2>&1; then
    echo "FAIL  harness 探针：纯 ebalance optional sentinel 在 --community 模式下未 PASS"
    exit 1
  fi
  echo "PASS  harness 探针：纯 ebalance optional sentinel 在默认/--community 两模式均 PASS"
  ```

  两个分支都显式检查退出码，不能依赖 `set -e`；只有两模式都为零才执行最后的 PASS。
- ADR-0005 要求两个新 verify 的完整 `.log` 随仓库保存，作为最近一次实测记录。

## 11. ADR-0006 内容与状态门

`docs/adr/0006-identification-four-pillars.md` 草案标题使用 `ADR-0006`，初始状态为 Proposed，至少包含：

1. 背景：现有三个观察性识别支柱缺少 selection-on-observables 与统一 router；
2. 决策：新增两个 skill，形成四支柱 + 横切入口；
3. 面板政策公共 gate，以及 standard DID 与 `synth` / `sdid` 的分叉 stop rules 和 trigger ownership；
4. common assumptions 与 MDE 的 power / precision 归属；
5. selection 默认 ATET、IPWRA 主估计、`teffects overlap` postestimation 例外及其边界；
6. reference 分层、作为 ADR-0003 窄化补充的两分支数据治理、verify 1:1 映射和带 `route_branch` 的 prompt 路由测试；
7. demo 按 ADR-0002 不作为本版本门槛；
8. 后果：完整 stop rules 的唯一副本只约束运行时 skill / references；方法 skill 只含最短本地边界和指针；社区扩展保持可选；
9. 活跃贡献、发行与 CI 元数据同步，历史快照不回写；
10. 验收：只有第 12 节全部通过后，状态才从 Proposed 改为 Accepted。

## 12. Acceptance checklist

以下项目全部满足才算实施完成，且 ADR-0006 才能改为 Accepted。验收证据分层：shell 静态检查只验证文件、计数、字段和字符串；Stata verify 验证命令执行与 N、处理率 `[0.20, 0.30]`、ATET 容差 `abs(_b[...]-.5)<=.15`、exact varlist 以及 balance / overlap 命令成功；prompt harness 验证 `route_branch` 与 `expected_actions`。人工 review 只负责制度证据和其他不能由模拟数据证明的识别假设；“可辩护”不是 shell 可以证明的结论：

### 12.1 结构、SKILL 惯例与活跃元数据

- [ ] 文件系统恰有 10 个 `stata-*/SKILL.md`。
- [ ] `stata-selection/references/` 恰有 8 个文件，名称与第 4.1 节完全一致，并包含独立 `psmatch2.md`。
- [ ] `stata-identification/references/` 恰有 3 个文件，名称与第 4.1 节完全一致。
- [ ] 两个新 `SKILL.md` 的 YAML frontmatter 至少包含 `name`、`description`、`compatibility`；正文包含「强制路径」「运行 Stata 的方式」「关键陷阱速查」「错误码速查」和可执行禁令。
- [ ] 两个新 `SKILL.md` 的首个 Stata code fence 中，第一条可执行语句是 `version 19.5`；这不是 Markdown 物理首行要求。两个新 verify do-file 的物理首行才必须是 `version 19.5`。
- [ ] README、AGENTS、`docs/run-stata.md`、harness 与 claims 的结构目标统一为 10 entries；README 的“本机实测 10/10 PASS”只在全量证据生成后更新。
- [ ] `CONTRIBUTING.md`、`CITATION.cff`、`.github/workflows/verify.yml` 与 `CLAUDE.md` 同步当前 10-skill / 6-ADR / CI 契约；实施 `CLAUDE.md` 前再次读取当前内容并最小合并用户未提交改动。
- [ ] README 当前态 ADR 声明从 5 ADR 更新为 6 ADR；`verify/check-claims.sh` 的动态 `N_ADR` 与 README ADR 计数断言通过。
- [ ] `CHANGELOG.md`、`LUBAN-REPORT.md` 与仅描述既有 demo 的 `demo/REPORT.md` 保持历史快照，不因当前计数回写。
- [ ] ADR 文件路径和标题都为 ADR-0006。

### 12.2 路由与方法

- [ ] 面板政策设计先经过公共 gate：明确政策时点、处理前后信息、未处理 donor / control、no anticipation、no interference 等；随后分叉 standard DID 与 `synth` / `sdid`。
- [ ] standard DID 明确要求足够的处理组与对照组 / 可比较单位以及可辩护 parallel trends；`synth` / `sdid` 保持同一面板政策子分支，但验收按方法析取：`synth` 通常要求一个或极少处理单位、长前期、可辩护 donor pool 与前期拟合；`sdid` 要求充分处理前 / 后期和 untreated / not-yet-treated comparison units，支持单个或多个处理单位及当前实现支持的多个处理日期，并检查 weighting、latent-factor / regularity 与方法特定推断条件，不把“一个或极少处理单位”作为必要条件。standard DID 的 parallel trends 失败后仍检查该子分支，不直接进入 selection。
- [ ] `stata-did-community/references/sdid.md` 与 `stata-did-community/references/workflow-8step.md` 的运行时措辞和 router、`identification-decision-tree.md`、本 spec、ADR-0006 一致：`sdid.md` 把单处理单位限定为推断 / VCE 特殊情形，而非方法范围；`workflow-8step.md` 将 Synthetic Control 与 Synthetic DiD 分行并按各自条件路由。
- [ ] 运行时扫描范围 `stata-*/SKILL.md` 与 `stata-*/references/*.md` 内，`identification-decision-tree.md` 的 `<!-- identification-stop-rules: full -->` 恰有一次；spec、ADR 与历史文档排除在唯一副本计数外。
- [ ] 各方法 skill 只有最小进入条件、失败动作和 router 指针，不复制完整树；named-method trigger 直达。
- [ ] 无可信设计时明确停止因果声明。
- [ ] selection 默认 estimand 处处为 ATET；`teffects ipwra`、`teffects psmatch`、`teffects ipw` 与 `teffects nnmatch` 的 treatment-effect estimation 示例都显式 `, atet`。`teffects overlap` 作为 postestimation 不带 `atet`。
- [ ] IPWRA 的名称、双重稳健条件以及与另外两种 AIPW 命令的区别准确。
- [ ] 主路径先 gate / 原始检查，再 IPWRA、balance、overlap、对照估计和分表；每个估计显式存储。
- [ ] 首次 `tebalance summarize` 紧跟 IPWRA 且归属 `ipwra_atet`；任何后续重印之前都有 `estimates restore ipwra_atet`。
- [ ] v1 平衡附表只要求 verify log 中独立、带标题输出；可选导出只在 paper-writing reference，主结果表不自动拼入 balance。
- [ ] `teffects overlap` verify 只检查命令成功，没有保存或跟踪图形；selection / identification 均无 v1 demo。
- [ ] `ebalance` 只存在于可选 reference 与 optional verify section；安装、默认 `_webal`、指定 `generate(ebw_verify)`、状态保护和权重断言与第 8.5 节一致。
- [ ] `psmatch2.md` 是独立 reference；`teffects-psmatch.md` 只负责官方命令。`psmatch2` optional section 锁定 `ssc install psmatch2`、最小 ATE 语法 `psmatch2 treat x1 x2 x3 x4, outcome(y) neighbor(1) ate`；若要社区 ATT，使用经 help/source 核实的 `att` 选项。selection 主 estimand ATET 与社区 ATT 只是术语对齐，不能把 `ate` 称 ATT；同时保留非同一实现声明及不确定返回值的安全断言策略；不强制安装、不作为默认主路径。

### 12.3 数据治理

- [ ] ADR-0006 与 `AGENTS.md`、`data/manifest-extra.txt` 顶部维护说明都明确 ADR-0003 的两分支窄化：外部来源扩展数据要求 README + license / provenance + `download_*.sh` + `EXPECTED_SIZE`；项目内生成数据要求 README + 固定 Stata version / seed / DGP + checked-in build do-file + schema / 数值不变量验证，不要求下载脚本或外部许可。
- [ ] `teaching-treatment.dta` 可由正式 build do-file 在 seed 20260825 下重建，N=2000、处理率约 25%、真 ATET=0.5。
- [ ] `ds` 返回值的字符串断言证明发布变量严格且按序等于 `id treat y x1 x2 x3 x4 x5 x6`；缺失、乱序或未知额外变量均 FAIL。
- [ ] `data/selection/README.md` 完整记录项目内生成 provenance、Stata version、seed、DGP、estimand、发布 / oracle 变量与重建命令。
- [ ] 发布 `.dta` 的 variable labels 为英文；中文解释只在注释 / README。图形默认英文，用户要求中文时先询问。
- [ ] `data/manifest-extra.txt` 登记 `teaching-treatment`，与 `.dta` 双向一致。

### 12.4 验证与发布门

- [ ] `verify-selection.do` 与 `verify-identification.do` 都有合法文件级 VERIFY CONTRACT，默认 1:1 映射，无额外委托。
- [ ] selection verify 覆盖 exact varlist、原始失衡、IPWRA 数值断言、归属明确的 balance、只检查成功的 overlap、官方 PSM、独立 optional psmatch2、IPW、NN、已核实 ebalance 烟测、原尺度主表与 log 平衡附表。
- [ ] optional ebalance 与 psmatch2 缺包各只输出对应纯 sentinel；默认与 `--community` 两模式均 PASS；真实 Stata 错误仍 FAIL。psmatch2 已安装时断言实际返回结果非缺失及匹配权重或匹配样本存在。
- [ ] identification verify 覆盖共同假设与 estimand 的可执行示例；路由主要由 prompts 验证。
- [ ] `test-prompts.json` 合法，覆盖每个实际 `stata-*/SKILL.md`，并具有第 10.3 节锁定的 `route_branch` 值与 expected action。
- [ ] `verify/test-prompts.sh` 从实际 `stata-*/SKILL.md` 动态派生 expected skill，不保留 jq / Python 的固定 8 或固定 10 数组；`.github/workflows/verify.yml` 不保留“覆盖 8 skill”文案。
- [ ] `bash verify/test-prompts.sh` 退出码为 0，并审计动态 skill 覆盖与全部 `route_branch` 锚点。
- [ ] `bash verify/test-harness.sh` 退出码为 0，且输出包含纯 ebalance 与 psmatch2 optional sentinel 双模式 PASS 探针成功。
- [ ] `bash verify/check-claims.sh` 退出码为 0，并明确报告 README ADR 计数等于动态 `N_ADR`。
- [ ] `bash verify/run-verify.sh --static` 退出码为 0。
- [ ] `bash verify/run-verify.sh selection` 与 `bash verify/run-verify.sh identification` 均 PASS。
- [ ] `bash verify/run-verify.sh` 全量报告 10/10 PASS，并生成 / 刷新两个新 raw log。
- [ ] 静态禁词与计数检查通过：运行时 stop rules 标记唯一；没有旧 skill 迁移数字、旧 ADR 文件名、已移除方法的 section / reference / 指针、非法 propensity 函数、非法 balance 选项、连续结果指数化选项、缺失决策编号或 8+3 reference 漂移；ATET 扫描只约束四类 treatment-effect estimation 命令，排除 postestimation。
- [ ] 上述全部证据存在后，README 才写“本机实测 10/10 PASS”，raw logs 才作为当前证据留存，ADR-0006 才改为 Accepted。

## 13. Ticket 顺序

下游按以下顺序拆 ticket；每个 ticket 的 completion criterion 是该行“完成条件”，未满足不得关闭。Ticket 1–8 是同一发布单元的中间态，不得独立发布或合并；“当前已 10/10 PASS”等事实声明只在 Ticket 9 产生完整证据后更新。

1. **ADR 草案**
   文件：`docs/adr/0006-identification-four-pillars.md`。
   完成条件：状态 Proposed；内容覆盖第 11 节全部条目，路径和标题一致，并明确它对 ADR-0003 数据条款的窄化补充关系。

2. **教学数据与治理**
   文件：`data/selection/build-teaching.do`、`data/selection/teaching-treatment.dta`、`data/selection/README.md`、`data/manifest-extra.txt`。
   完成条件：DGP 与第 9 节逐项一致；发布 variable labels 为英文；重建 smoke test 通过；exact varlist 与数值不变量通过；manifest 双向一致，顶部说明写明外部来源 / 项目内生成两分支。

3. **Selection 主 skill 与 8 references**
   文件：`stata-selection/SKILL.md` 及第 4.1 节列出的 8 个 references。
   完成条件：frontmatter 至少含 `name` / `description` / `compatibility`；首个 Stata fence 的第一条可执行语句为 `version 19.5`；强制路径、错误码速查、ATET 的四类 estimation 命令量词、IPWRA 边界、postestimation 归属、对照估计、经核实的 `ebalance` 与 `psmatch2` 语法（最小 ATE 示例与经核实的 ATT 选项）、两个 optional sentinel 和 v1 分表规则全部可定位；reference 数量恰好为 8。

4. **Identification router 与 3 references**
   文件：`stata-identification/SKILL.md` 及第 4.1 节列出的 3 个 references。
   完成条件：frontmatter 与 Stata fence 惯例同 Ticket 3，并含错误码速查；运行时扫描范围内完整 stop rules 标记恰好一个；公共 gate、standard DID 与 `synth` / `sdid` 分叉、共同假设、MDE 归属和 paper-writing 边界完整；reference 数量恰好为 3。

5. **现有方法 skill 与运行时 references 的本地边界**
   文件：`stata-did/SKILL.md`、`stata-did-community/SKILL.md`、`stata-did-community/references/sdid.md`、`stata-did-community/references/workflow-8step.md`、`stata-rdd/SKILL.md`、`stata-regression/SKILL.md`。
   完成条件：named-method 仍直达；standard DID 失败后仍可检查 `synth` / `sdid`；每个方法只保留最小进入条件、失败动作和 router 指针；运行时材料没有第二份完整 stop rules。`sdid.md` 明确支持单个或多个处理单位及当前实现支持的多个处理日期，单处理单位只作为推断 / VCE 特殊情形；`workflow-8step.md` 分开 Synthetic Control（通常少数处理单位）与 Synthetic DiD（充分 pre / post、comparison units、weighting、latent-factor / regularity 和方法特定推断条件），不把处理单位少作为 Synthetic DiD 必要条件。

6. **两个 verify 入口**
   文件：`verify/verify-selection.do`、`verify/verify-identification.do`。
   完成条件：物理首行均为 `version 19.5`；第 10.1 与 10.2 节全部 section 和数值断言通过；selection 包含 exact varlist、四类 ATET estimation 命令、IPWRA balance 归属、无 `atet` 的 `teffects overlap`、log 附表、无图形产物和状态保护的 ebalance 烟测；`verify/lib/targets.sh` 保持默认映射且无改动。

7. **Agent 路由回归集**
   文件：`test-prompts.json`。
   完成条件：JSON 合法；预期 10 个实际 skill 均有覆盖；第 10.3 节全部 `route_branch` 锚点和 named-method 直达均有 expected action。

8. **结构目标、活跃元数据与 harness 同步**
   文件：`README.md`、`AGENTS.md`、`CONTRIBUTING.md`、`CITATION.cff`、`CLAUDE.md`、`.github/workflows/verify.yml`、`docs/run-stata.md`、`verify/run-verify.sh`、`verify/check-claims.sh`、`verify/test-harness.sh`、`verify/test-prompts.sh`，以及现有 skill 中的结构数字文案。
   完成条件：结构目标与预期计数统一为 10 entries / 6 ADR；`verify/test-prompts.sh` 从实际 `stata-*/SKILL.md` 动态派生 expected skill 并审计 `route_branch`，不保留固定 8 / 10 数组；AGENTS 与 manifest 顶部两分支数据治理一致；workflow 不保留 8-skill 注释；纯 ebalance optional sentinel 双模式探针和静态结构检查通过。Ticket 8 不得把 README 写成“本机实测 10/10 PASS”，也不得提前把 ADR 改为 Accepted。实施 `CLAUDE.md` 前再次读取当前磁盘内容并最小合并。

9. **全量验证、当前态声明、日志与 ADR 接受**
   文件：`README.md`、`verify/verify-selection.log`、`verify/verify-identification.log`、`docs/adr/0006-identification-four-pillars.md`。
   完成条件：第 12 节全部勾选；`test-prompts.sh`、`test-harness.sh`、claims、static、两个新 verify 与全量 Stata 都通过，最终输出 10/10 PASS；此后才更新 README 的“本机实测 10/10 PASS”、留存 raw logs，并把 ADR 状态改为 Accepted；更新声明后再次运行 claims / static 确认当前态一致。

本规格没有 future decision 或待确认项。任何偏离上述锁定结论的实现都必须先修改本规格或另立 ADR，而不是在 ticket 中自行扩 scope。
