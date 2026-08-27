---
name: stata-rdd
description: Stata 断点回归（RDD）：rdrobust / rdplot / rddensity，覆盖 sharp 与 fuzzy、密度操纵检验、带宽敏感性、placebo cutoff。Cattaneo 团队协议，需 ssc install。触发词：RDD / 断点回归 / regression discontinuity / 分数线 / 年龄门槛 / 地理边界 / rdrobust / 操纵检验。
compatibility: >-
  适配 Claude Code / Codex / OpenClaw / SkillsMP；StataNow 19.5 MP（macOS / Windows / Linux）实测 PASS；
  触发即读本文，无需联网加载其他文件。必装：ssc install rdrobust rdplot rddensity（Cattaneo 团队协议）。
---

# Stata 断点回归：rdrobust 命令族（RDD / sharp / fuzzy）

本仓库当前由 `stata-identification` 在四个设计支柱之间路由：随机分配、RDD、IV、面板政策设计；横截面 selection-on-observables 是后续可检查分支。标准 RDD 的处理概率由一个**运行变量的阈值**产生跳跃；当运行变量是时间时，必须在 RDiT、ITS 与 DID 之间按时间设计、comparison units 和 parallel-trends 依据重新判断，不能仅凭“时间 cutoff”机械选方法（详见「强制路径 / 踢走」）。

本 skill 对应 Cattaneo 团队的 rdpackages 协议（`rdrobust` / `rdplot` / `rddensity` / `rdbwselect`），全部为**社区包**，需 `ssc install`。官方 Stata 手册（*Causal Inference* / `teffects` / `cate` / `lateffects`）**没有** RDD 命令——RDD 在 Stata 里由社区包承载，手册只在「识别策略判断」层有用。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`。平台路径见 `docs/run-stata.md`。
- **中文作图规矩**：需要图形命令且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 安装与版本

```stata
version 19.5                       // 本仓库版本政策：首行钉住
ssc install rdrobust, replace      // rdrobust / rdplot / rdbwselect
ssc install rddensity, replace     // 密度操纵检验
ssc install lpdensity, replace     // rddensity 的底包（画密度图需要）
```

- 跟踪 GitHub 最新版：`net install rdrobust, from("https://raw.githubusercontent.com/rdpackages/rdrobust/main/stata") replace`
- 官方示例数据：`rdrobust_senate.dta`（随包，或从 rdpackages GitHub 下载）
- 本仓库数据：`data/rdd/tutoring.dta`（sharp，cutoff=70，占位教学用）

## 强制路径

匹配到第一条就停。不要把 `rdrobust` / `rdplot` / `rddensity` 全跑一遍当稳健性；只用命中的那条链。详细签名见 `references/`；禁令见文末黑名单。

**何时用**：处理由一个**连续（或细粒度）运行变量**在**事先给定的阈值**上决定——分数线、年龄门槛、地理边界、评分阈值；阈值规则、时间先后、cutoff 附近连续性和无精确操纵等本地 gate 也必须可辩护。用户明确点名 RDD 时先执行本地 gate；失败返回 `stata-identification`，不要用普通回归、DID 或更复杂 RDD 变体绕过。完整判断只读 `stata-identification/references/identification-decision-tree.md`。
**何时踢走**：
- 运行变量是**时间**（政策实施年月、时间 cutoff、错时处理）→ 不要机械判作 DID 或标准 RDD：有可定义 comparison units 且能为具体设计辩护 parallel trends 时才进入 `stata-did` / `stata-did-community`；单一时间序列干预按时间结构与反事实证据区分 RDiT / ITS。RDD 本地 gate 失败一律返回 `stata-identification` router 重新判断
- 截面可观测选择（无阈值，只看协变量）→ 不是 RDD；走 `stata-selection`
- 运行变量只有少数离散值（mass points）→ 连续性框架变弱；用 `rdlocrand`（见 `references/extensions.md`）
- 只要回归 / 系数图 → `stata-regression` / `stata-coefplot`

### RDD 六步强制路径

| 步骤 | 命令 | 目的 |
|---|---|---|
| 1. 验设计 | `tab treat`（处理 × 是否过线） | sharp（100% 合规）/ fuzzy（部分交叉） |
| 2. 看目视图 | `rdplot y x, c(c0) p(1)` | 断点是否可见、跳跃方向 |
| 3. 主估计 | `rdrobust y x, c(c0)` | sharp；fuzzy 加 `fuzzy(treat)` |
| 4. 密度检验 | `rddensity x, c(c0)` | 操纵检验（替代旧 McCrary） |
| 5. 带宽敏感性 | `rdbwselect y x, c(c0) all` — `foreach bw in ... rdrobust, h(\`bw')` | 结果不依赖带宽选择 |
| 6. placebo | `foreach c in ... rdrobust y x, c(\`c')` | 只有真 cutoff 显著 |

**默认主估计**：`rdrobust y x, c(c0)`——MSE 最优带宽、三角核、局部线性（p=1）、偏误校正（q=2）、**robust CI**。读系数用 **`e(tau_cl)`**（robust 版），**不是** `e(tau)`（conventional）。

### sharp vs fuzzy

- **sharp**：处理是运行变量的确定函数（100% 合规、无交叉）。`tab treat` 显示两组完全对齐。
- **fuzzy**：阈值改变的是处理**概率**（部分人跨线、或有人未按规则接受）。`tab treat` 有交叉。**必须显式 `fuzzy(treat)`**，否则 `rdrobust` 估计的是意向处理（ITT），不是 LATE。写成 LATE 前还必须通过 IV 类 gate：cutoff 有非零且足够强的 first stage、cutoff 对结果只经处理起作用（exclusion）、处理响应满足 monotonicity、SUTVA / no interference 可辩护，并把 estimand 限定为 cutoff 附近的 compliers。

```stata
* sharp（tutoring 数据）
tab below_cutoff treat, row
rdrobust exit_exam entrance_exam, c(70)

* fuzzy（处理概率在阈值跳跃）
rdrobust y x, c(c0) fuzzy(treat)
```

**fuzzy 的 LATE 解释**：只有在标准 RDD 的局部连续性 / 无精确操纵 gate 与上述 first stage、exclusion、monotonicity、SUTVA / no-interference gate 均可辩护时，`rdrobust ..., fuzzy(treat)` 才能解释为 cutoff 附近 compliers 的局部平均处理效应；必须报告第一阶段，并明确 complier / local estimand，不能外推为全样本 ATE。任一 gate 失败则返回 `stata-identification` router。

## 详细参考（references/）

主文件保留六步强制路径 + 关键陷阱 + 黑名单。扩展方法按需加载：

| 文件 | 内容 | 何时加载 |
|---|---|---|
| `references/extensions.md` | `rdlocrand`（离散分数 / 局部随机化）、`rdmulti`（多 cutoff/多 score）、`rd2d`（地理边界 RD）、`rdpower`（功效） | 遇到离散 running variable、多个 cutoff、地理/行政区边界时 |
| `references/workflow-full.md` | Cattaneo 完整工作流：协变量 `covs()`、聚类 `vce(nncluster)`、偏误校正细节、`rdrobust` 的 `_cl` 三套输出 | 主路径已验证，需要协变量 / 聚类 / 完整稳健性时 |

> **陷阱只在主文件集中维护**，references 不重复——避免漂移。

## 关键陷阱速查

> 统一格式：**陷阱 → 触发 → Fix → 验证**。每条给出可执行修复 + 验证；Agent 读到即拿到完整修复路径。

1. **`rdrobust` 符号是「从左到右的跳跃」，不是 `treat` 系数方向**
   - **触发**：教程里 tutoring 提高成绩（treat 系数 +10.8），但 `rdrobust` 报 **−8.58**——因为被处理者在 cutoff 左侧（score ≤ 70）且分数更高，右移是下降。
   - **Fix**：先确认处理在 cutoff 哪一侧；报告写「左侧处理 / 右侧处理」，不要用负号直接说「项目有害」。
   - **验证**：`rdplot` 目视跳跃方向 + `tab treat` 对照处理赋值方向。

2. **读错输出：用 `e(tau)` 而不是 `e(tau_cl)`**
   - **触发**：`rdrobust` 默认给 conventional / bias-corrected / robust 三套，主报告应取**robust**（`e(tau_cl)`、`e(se_tau_cl)`）。
   - **Fix**：`local coef = e(tau_cl)`；width 与 CI 都从 `_cl` 版本取。
   - **验证**：compare `e(tau)` vs `e(tau_cl)`——报告 robust 那行。

3. **把 RDD 当成全局 ATE**
   - **触发**：把 cutoff 处的局部效应外推成全样本（「全体学生提高 9 分」「全体企业收益」）。
   - **Fix**：RDD 识别的是 **cutoff 处的 LATE**；写「局部到 cutoff」。要全局效应须换设计。
   - **验证**：报告必含「局部」「LATE」「到 cutoff」；不同 fit（OLS 全样本 vs `rdrobust` 局部）数值必然不同。

4. **用全样本全局高阶多项式**
   - **触发**：`regress y c.x##i.treat` 或 3/4 次多项式当主结果——Gelman/Imbens 指出会在边界振荡。
   - **Fix**：主结果用 `rdrobust` 局部线性；参数回归只做对照（同斜率 / 不同斜率 / 低阶），并允许两侧斜率不同。
   - **验证**：`estimates table` 对比参数模型；主估计始终是 `rdrobust`。

5. **带宽手填但不报告敏感性**
   - **触发**：`rdrobust y x, c(c0) h(10)` 直接投稿，未做 `h(5 7 10 …)` 网格。
   - **Fix**：先默认 MSE 带宽；再 `foreach bw in 5 7 10 15 20 { rdrobust ..., h(\`bw') }` 看符号稳定。
   - **验证**：窄带宽 SE 变大但符号稳定，才算过关；`rdbwselect ..., all` 列出所有选择器。

6. **操纵检验用直方图目视，或手搓 McCrary**
   - **触发**：只画 histogram 说「没堆积」，或者用不再推荐的旧 McCrary。
   - **Fix**：`rddensity x, c(c0)`（Cattaneo–Jansson–Ma 局部多项式密度）；p 用 `e(pv_q)`。**不需要 `rddensity` 的内置图**（fragile），密度图自己用 `kdensity` 分侧合并。
   - **验证**：`rddensity` p > 0.05 只是「未发现堆积」，不是「证明没操纵」（不能证明原假设）。

7. **`rddensity` 依赖 `lpdensity`，且内置 plot 脆弱**
   - **触发**：`ssc install rddensity` 后跑 `rddensity` 报 `lpdensity not found`，或内置图崩。
   - **Fix**：`ssc install lpdensity, replace`；图自己用 `kdensity` 生成（左右两侧分别估计再合并画）。
   - **验证**：`which lpdensity` 有输出；密度图两侧接近 cutoff 处高度相近。

8. **离散 running variable / mass points**
   - **触发**：年龄（岁）、整数分数触发 `Mass points detected`，连续性框架变弱。
   - **Fix**：报告 mass points；考虑 `rdlocrand`（`rdwinselect` + `rdrandinf`），不要假装分数是连续的。
   - **验证**：`tab runningvar` 看是否只有少数取值；有则走 `references/extensions.md`。

9. **fuzzy 只加 `fuzzy(D)`、不审计 LATE gate**
   - **触发**：未按规则接受处理时，只看到 treatment probability 跳跃就把结果称为 LATE。
   - **Fix**：`rdrobust y x, c(c0) fuzzy(D)` 之外，逐项说明 first stage、exclusion、monotonicity、SUTVA / no interference，并把 estimand 限定为 cutoff 附近 compliers；任一 gate 失败返回 `stata-identification`。
   - **验证**：结果同时报告第一阶段与第二阶段，正文明确写出 exclusion、monotonicity、SUTVA / no interference 和 complier / local estimand，不出现全样本 ATE 外推。

10. **协变量不是识别条件**
    - **触发**：把中介 / 结果后代放进 `covs()`，或指望 `covs()` 弥补坏的识别。
    - **Fix**：`covs()` 只缩小 CI；把预处理变量当结果跑一遍 RD 做平衡（robust p 应不显著）。
    - **验证**：`foreach v in $covs { rdrobust \`v' x, c(c0) }` 看 p 值；不显著才平衡。

11. **把时间 cutoff 机械等同标准 RDD 或 DID**
    - **触发**：看到政策实施年月就直接跑 `rdrobust`，或反向地只因运行变量是时间就直接指定 DID。
    - **Fix**：返回 `stata-identification` router；按时间序列结构、可用 comparison units 与反事实证据区分 RDiT / ITS，只有具体 DID 设计的 comparison units 和 parallel trends 可辩护时才进入 DID。RDiT 不能沿用可操纵运行变量的密度检验，且需单独论证 cutoff 附近随时间变化的混淆因素。
    - **验证**：报告明确写出时间设计、comparison units 是否存在及 parallel-trends 依据；不能只用“政策前后”或“时间 cutoff”命名识别策略。

12. **placebo 手抄，或只跑 1 个假 cutoff**
    - **触发**：只放 1-2 个 placebo cutoff，或手工抄结果易错。
    - **Fix**：`postfile` 收集真 cutoff 附近的多个 placebo cutoff → `twoway rcap` 画图；真 cutoff 应显著、其余不显著。
    - **验证**：placebo 图只有真 cutoff 的 CI 不含 0；spillover（靠近真 cutoff 的 placebo 边际显著）可接受。

## ❌ Agent 不该做的事（黑名单）

> 与 ADR-0001 联动：本节是「主动反模式」。Agent 在写 RDD do-file 前必查一遍。RDD 的识别假设与 DID 不同，不要抄袭 DID 的坑。

- ❌ **不要把分数线 / 年龄门槛 / 地理边界改走 DID**：这些是阈值分配候选，不是时间处理。**替代**：先执行本 skill 的标准 RDD / 扩展方法本地 gate；失败返回 `stata-identification`。
- ❌ **不要在 sharp 场景用 `fuzzy(treat)`**：无交叉时 fuzzy 退化为 sharp，徒增无效假设。
- ❌ **不要只凭 first stage 把 fuzzy RDD 解释为 LATE**：**替代**：同时审计 exclusion、monotonicity、SUTVA / no interference，并限定 cutoff 附近的 complier / local estimand。
- ❌ **不要读 `e(tau)` 用 conventional，正确读 `e(tau_cl)` 用 robust**：主报告必须 robust CI。
- ❌ **不要用全样本高阶多项式当主结果**：`regress y c.x##i.treat` 或 3/4 次多项式在边界振荡。**替代**：`rdrobust` 局部线性主估计 + 低阶参数对照。
- ❌ **不要把 `rdrobust` 的负号直接说成「项目有害」**：符号是左→右跳跃方向。**替代**：先确认处理在哪一侧。
- ❌ **不要跳过 `rddensity`**：直方图目视不替代局部多项式密度检验。
- ❌ **不要用 `rddensity` 内置 plot**：fragile；自己用 `kdensity` 分侧合并。
- ❌ **不要把 RDD 解释成全样本 ATE**：是 cutoff 处 LATE。**替代**：写「局部到 cutoff」。
- ❌ **不要让 `covs()` 承担识别**：协变量只提效率，识别靠连续性。**替代**：预处理变量当结果跑 RD 平衡检验。
- ❌ **不要在离散 mass points 上假装连续性框架**：**替代**：`rdlocrand` 局部随机化。
- ❌ **不要把政策实施日期机械归为 RDiT、ITS 或 DID**：**替代**：按时间设计、comparison units 与 parallel-trends 依据返回 `stata-identification` router 判别。

## 🔍 错误码速查（错误码 → 触发 → 修复）

> 与上方「❌ Agent 不该做的事（黑名单）」互补：黑名单给原则，错误码给精准命中。Agent 看到 r(N) 时直接查本节定位。

- **`r(2001)`** — rdrobust 带宽无效（bw 太窄或 cutoff 处观测过少）。**修复**：看 e(h_l) / e(h_r)；用默认 MSE 带宽；或手动设 h(<value>)
- **`r(498)`** — rdplot 报矩阵奇异（运行变量 cutoff 附近方差为 0）。**修复**：在 cutoff 两侧 nudge 一段再画；rdplot y x, c(<cutoff>) grid(<n>)
- **`r(198)`** — rddensity 报 not estimable（操纵边界过近）。**修复**：看 e(T) 操纵检验统计量；p > 0.1 即无操纵；样本小换 rddensity ..., bin(<n>)

## 验证

- 本 skill 的 sharp + fuzzy + 密度检验由 `verify/verify-rdd.do` 覆盖：
  - 数据：`data/rdd/tutoring.dta`（sharp，cutoff=70，26029 字节；来源 Carlos Mendez，`data/rdd/README.md` 留档）。
  - 社区包契约（`run-verify.sh --community` 模式）：
    - `rdrobust`、`rddensity`：必需。
    - `lpdensity`：rddensity 依赖，未装则 sentinel（可选，不影响默认 PASS）。
    - 缺包分支用 `display "__COMMUNITY_PACKAGE_MISSING__<pkg>__"`，harness 用正则识别（见 `verify/run-verify.sh`）。
  - 断言：一次 `end of do-file`、无错误码、robust CI 存在、`rddensity` 跑过。
- 运行：`bash verify/run-verify.sh rdd`（默认）/ `bash verify/run-verify.sh rdd --community`（强制装包）。
- 全量 10 个 skill：`bash verify/run-verify.sh`。

## 参考文献

- **Calonico, Cattaneo & Titiunik (2014)** "Robust Data-Driven Inference in the Regression-Discontinuity Design." *Stata Journal* 14(4): 909–946. — `rdrobust` 原始实现。
- **Calonico, Cattaneo, Farrell & Titiunik (2017)** "rdrobust: Software for Regression Discontinuity Designs." *Stata Journal* 17(2): 372–404. — 大升级版：`rdplot` / `rdbwselect` / 聚类 / 协变量。
- **Cattaneo, Jansson & Ma (2018)** "Manipulation Testing Based on Density Discontinuity." *Stata Journal* 18(1). — `rddensity` / `rdbwdensity`。
- **Cattaneo, Idrobo & Titiunik (2020)** *A Practical Introduction to Regression Discontinuity Designs: Foundations.* Cambridge Elements. — 教学范本 + 复刻代码。
- **Cattaneo, Titiunik & Vazquez-Bare (2016)** *Stata Journal* [对应 `rdlocrand`]。 — 局部随机化。
- 教程：Carlos Mendez, *RDD in Stata: Evaluating a Tutoring Program.* https://carlos-mendez.org/post/stata_rd/ — 本 skill 数据与工作流来源。
- 官方手册：*Stata 19 Causal Inference and Treatment-Effects Estimation Reference Manual* — **无 RDD 命令**，只在识别策略判断层参考。

## ✅ 交付前自检清单（跑完命令后逐条核对）

- [ ] 六步强制路径命中：`tab treat` → `rdplot` → `rdrobust` → `rddensity` → 带宽敏感性 → placebo；未把工具箱全跑一遍
- [ ] 主估计 `rdrobust y x, c(c0)`；报告用 `e(tau_cl)`（robust），未误读 `e(tau)`
- [ ] 符号解读：先说清处理在 cutoff 哪一侧（左/右），未把负号直接说成「项目有害」
- [ ] fuzzy 已显式 `fuzzy(treat)` 并审计 first stage/exclusion/monotonicity/SUTVA，estimand 限定 cutoff 附近 compliers
- [ ] 未用全样本高阶多项式当主结果；未把 RDD 解释成全样本 ATE（用「局部到 cutoff」）
- [ ] 操纵检验跑了 `rddensity`（`lpdensity` 已装）；密度图用 `kdensity` 自画，未依赖内置 plot
- [ ] 离散 mass points 已报告并考虑 `rdlocrand`；时间 cutoff 未机械归为 RDiT/ITS/DID
- [ ] log 恰好一次 `end of do-file`，无 `r(错误码)`（r(2001)/r(498)/r(198) 已排查）
