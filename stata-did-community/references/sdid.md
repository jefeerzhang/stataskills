---
name: stata-did-community-sdid
description: 合成 DID 参考：sdid（合成控制 × DID 结合）。适用于单个或多个处理单位及当前实现支持的多个处理日期；单处理单位只改变可用推断 / VCE，不是范围限制。主文件见 stata-did-community/SKILL.md。
---

# stata-did-community-sdid

> **加载时机**：主 SKILL.md 决策树已读完，确认面板政策公共 gate 后，进入 `sdid` 子分支时加载本文件；`sdid` 可处理单个或多个处理单位及当前实现支持的多个处理日期。

> **边界约定**：本文件只补详细方法签名与工作流示例。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 3. 合成 DID：sdid（合成控制 × DID 的结合）

Arkhangelsky et al. (2021, *AER*)：同时给**单位**（像 synth）和**时期**加权，再跑加权 DID。比 synth 多了单位固定效应（允许持久水平差），比 DID 多了数据驱动的权重。Stata 实现：`sdid`（Clarke & Pailañir，SSC）。它不是 standard DID 的平行趋势“补丁”：进入条件是公共面板政策 gate 已通过，随后单独审计 comparison units、weighting、latent-factor / regularity 和方法特定推断条件。

### 本地边界与识别条件

- **处理范围**：当前实现支持单个或多个处理单位，以及多个处理日期的处理结构；单处理单位不是 `sdid` 的范围限制。
- **comparison units**：必须有可辩护的 untreated 或 not-yet-treated comparison units，且其结果序列和处理前信息足以形成反事实；只凭“有一组对照”或变量名不能通过 gate。
- **weighting**：单位权重与时间权重共同构成估计量；检查权重是否集中、是否有有效 donor / comparison 支撑，并报告权重与 pre-fit，而不是把默认权重当作识别证明。
- **latent-factor / regularity**：需要能为潜在因子结构及正则性 / 稳定性条件提供制度或数据支持；pre-fit 诊断只是支持性证据，不能证明这些不可完全检验的条件。
- **推断**：推断必须匹配数据结构与实现：`vce(bootstrap)` 为通用路径，`vce(jackknife)` 只在面板且留出单位有意义时使用；单处理单位时 jackknife / placebo 的可用性和解释尤其受 donor 数量与结构限制，必要时使用 `vce(noinference)` 仅报告点估计并明确无推断。重复截面不要把面板 jackknife 当作可用默认。
- **失败动作（区分入口）**：用户点名 `sdid` 时，任一上述条件不能辩护可返回 `stata-identification`；若从 standard DID 失败进入 4b 后检查 `sdid`，则 `sdid` 失败不能立即离开面板政策支柱，必须继续检查 `synth` 的 donor pool、pre-fit 与推断条件。只有 `sdid` 和 `synth` 两个析取入口都失败，才返回 `stata-identification`；不要改称 standard DID 已成立，也不要随意换成其他 estimator 继续宣称因果。

```stata
ssc install sdid, replace

* 语法骨架：sdid 结局 组变量 时间变量 处理哑变量
* 处理哑变量 = 处理单位 × 处理后（treat_post 型 0/1，不是 cohort 成员变量！）

* 本地模拟例：39 个对照州 + 1 个处理州 × 20 期，第 15 期起处理
clear
set seed 20260817
set obs 800
gen state = ceil(_n/20)
gen year  = mod(_n-1, 20) + 1
gen treat = (state==1 & year>=15)
gen y     = 5 + 0.1*year + 0.5*(state==1) + 1.2*treat + rnormal(0, 1)

sdid y state year treat, vce(bootstrap) reps(50) seed(20260817) graph
```

常用选项：

- `vce()`：`bootstrap`（通用，默认推荐）/ `jackknife`（仅面板可用，更快）/ `placebo`（大捐赠池）/ `noinference`；单处理单位时这些是推断 / VCE 的特殊情形，不是方法范围限制。
- `method(sdid|sc|did)`：同一框架切换 合成 DID / 纯合成控制 / 普通 DID——**三方法一行对照**，与 diff-diff 的 `SyntheticDiD` / `SyntheticControl` / `DifferenceInDifferences` 一一对应；切换到 `did` 不会绕过本地 gate。
- `covariates(varlist, projected)`：协变量调整（`optimized` 为默认算法）。
- `graph`：效应图 + 权重图；结果存在 `e(ATT)`、`e(se)`、`e(series)`。
- 错时采用：v2+ 原生支持，按处理 cohort 分别估计后聚合（面板下可与 `hdidregress aipw` 互为稳健性对照）。

**何时用 sdid 而非 synth**：有充分 pre / post periods 与可辩护 comparison units，需要单位和时间双重 weighting；处理前持久水平差或需要方法特定标准误也可支持此选择。`synth` 则通常面向一个或极少处理单位、较长前期和清晰 donor pool。**何时用 sdid 而非 hdidregress**：latent-factor / regularity 与权重条件比 standard DID 的趋势反事实更可辩护，且需要透明报告 comparison-unit 与 time weights；处理单位少不是必要条件。

与 diff-diff 的对应关系：`sdid` ≈ `SyntheticDiD`（含 bootstrap 推断）；`synth` + synth_runner placebo ≈ `SyntheticControl` + `in_space_placebo()`。

