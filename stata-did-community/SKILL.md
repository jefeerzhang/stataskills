---
name: stata-did-community
description: Stata DID 社区包（10 个方法）：csdid / jwdid / did_imputation / synth / sdid / did_multiplegt(DCDH) / stacked / lpdid / reghdfe 事件研究 / trop。含决策树路由、特征对照矩阵、HAD v2.0.0 两条平行路线、csdid method(twostage) Gardner 2022 + Sun-Abraham IW 等价说明、面板 MDE / 功效分析模板。触发词：DID 社区包 / csdid / jwdid / 合成控制 / 可逆处理 / 局部投影 / 堆叠 DID / Sun-Abraham / Gardner twostage / did_had / TROP / 功效分析 / power analysis / MDE。
compatibility: >-
  适配 Claude Code / Codex / OpenClaw / SkillsMP；StataNow 19.5 MP（macOS / Windows / Linux）实测 PASS；
  触发即读本文，无需联网加载其他文件。需装 csdid / drdid / jwdid / hdfe / reghdfe / did_imputation / synth / sdid / stacked / lpdid / trop / nprobust / did_had（按方法选装；did_had 经 GitHub net install）。
---

# Stata 双重差分：社区包（reghdfe / csdid / jwdid / did_imputation / synth / sdid / did_multiplegt / stacked / lpdid）

本 skill 覆盖主流 DID 社区包，需 `ssc install`。Stata 内置 DID 命令（`didregress` / `xtdidregress` / `hdidregress` / `xthdidregress`）见 `stata-did` skill。

> **文档分层（ADR-0001 / coefplot 模式）**：主 `SKILL.md` 只保留「命令选择表 + 方法选择决策树 + 特征对照矩阵 + AI Agent 选择逻辑 + 事后命令速查 + 关键陷阱速查 + 参考文献 + 验证」。每个方法的**详细签名 + 完整工作流 + 安装步骤**下沉到 `references/<method>.md`。陷阱条目**只在主文件集中维护**一份，避免 references 重复带来漂移。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`。平台路径见 `docs/run-stata.md`。
- **中文作图规矩**：需要图形命令且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 强制路径

匹配到第一条就停。禁止把 10 个社区包都跑一遍当「稳健性」。详细签名见 `references/`；禁令见文末黑名单。

**何时用**：内置 `didregress` / `hdidregress` 不够用——处理单位极少、可逆/非二元处理、非线性结果、leaveout、合成对照、堆叠诊断、冲击型处理。
**合成分支本地 gate 与失败动作**：只有用户点名 `synth` / `sdid`，或从 standard DID 本地 gate 失败进入 4b 合成分支时，才执行这里的合成 gate。先确认面板政策公共 gate 可辩护；`synth` 通常要求少数处理单位、较长 pre-period 和可辩护 donor pool，`sdid` 要求充分 pre / post periods、untreated 或 not-yet-treated comparison units，并支持单个或多个处理单位及当前实现支持的多个处理日期。用户点名单一方法时，该方法 gate 失败可返回 `stata-identification`；从 standard DID 进入 4b 时，一个方法失败必须继续检查另一个——尤其 `sdid` 失败后仍须检查 `synth`，只有 `synth` 与 `sdid` 两个析取入口都失败才返回 router。普通 DID-community 方法选择不执行 4b 合成 gate，直接从 `did_multiplegt`、`jwdid`、`did_imputation`、`csdid`、`stacked` 或 `lpdid` 等既有路径开始；用户点名 `csdid`、`jwdid`、`did_imputation`、`did_multiplegt`、`stacked` 或 `lpdid` 时也直达对应路径，不先执行 4b。不要把 `synth` / `sdid` 当独立顶层识别支柱。完整判断只读 `stata-identification/references/identification-decision-tree.md`。
**何时踢走**：
- 分数线 / 年龄门槛 / 地理边界 → `stata-rdd`，**不要改走 `csdid` / `synth`**
- 简单 2×2 或默认错时 DID → 先 `stata-did`（`didregress` / `hdidregress aipw`）
- 只要多层 FE、不是事件研究 → `stata-regression` 的 `reghdfe`

默认错时（无下表特殊需求）→ **不要留在本 skill**，回 `stata-did` 跑 `hdidregress aipw`。

| 用户场景（自上而下，命中即停） | 强制命令链 |
|---|---|
| named `synth`，或 standard DID 失败进入 4b 后满足：少数处理单位 + 较长前期 + donor pool 可辩护 | `synth` → placebo / permutation；不要只报点估计 |
| named `sdid`，或 standard DID 失败进入 4b 后满足：充分 pre / post + untreated / not-yet-treated comparison units；单个或多个处理单位及当前实现支持的多个处理日期 | `sdid` → 匹配数据结构的 VCE；报告单位 / 时间权重与 pre-fit |
| 处理可逆 / 非二元 / 无 stayers | `did_multiplegt (dyn)`（位置参数，不是 `, mode(dyn)`） |
| 0/1 处理 + stayers + switchers（HAD 场景） | `did_multiplegt (had)` → 估计 DID_M（见 [references/dcdh.md](references/dcdh.md) § 两条平行路线） |
| 连续剂量 + 无 QUG（universal policy，所有单位 D > 0） | `did_had` v2.0.0 → `bandwidth(mse)` + `method(ll) ci(bc)`（见 [references/dcdh.md](references/dcdh.md) § 两条平行路线） |
| 错时 + 计数/二元结果 | `jwdid y, ivar(id) tvar(t) gvar(g) method(poisson) group` → `estat event` → `estat plot` |
| 错时 + leaveout / 单位趋势 / 灵活 FE | `replace Ei = . if never_treated` → `did_imputation y id t Ei, horizons(0/5) leaveout autosample` |
| 错时 + 要 DR/IPW/Reg 三方法对照 | `csdid y, ivar(id) time(t) gvar(g) notyet method(dr)` → `estat simple` → `estat event` |
| 错时 + 处理时点少（≤ 3 cohort）+ 想看 cohort-specific + 接受方差放大 | `csdid y, ivar(id) time(t) gvar(g) method(twostage) notyet` → `estat simple` → `estat event` → `estat group`（Gardner 2022 two-stage；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) § `csdid, method(twostage)`）|
| 错时 + TWFE 权重诊断 / 100M+ 行 | `save original.dta` → `stacked build` → `stacked kappa` → `stacked reg` |
| 冲击型（只持续 1 期）或聚类 < 50 | `lpdid y, ... pre(5) post(#)`；少聚类加 `bootstrap(500)` |

`gvar`/`Ei` 编码：`csdid`/`jwdid` 的从未处理用 `0` 或 `.`；`did_imputation` 的 `Ei` **必须是 `.`，不能是 `0`**。

## 命令选择表（社区包）

| 数据结构 | 处理时点 | 推荐命令 | 说明 |
|---|---|---|---|
| 面板（较长前期） | 一个或极少处理单位 + 可辩护 donor pool | `synth` | 合成控制；placebo / permutation 推断 |
| 面板（充分前后期） | 单个或多个处理单位；当前实现支持多个处理日期 | `sdid` | 合成 DID；需 comparison units、weighting、latent-factor / regularity 与方法特定推断条件 |
| 面板/重复截面 | 错时（staggered） | `csdid` | Callaway-Sant'Anna 估计量；DR/IPW/Reg 三方法；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| 面板/重复截面 | 错时（staggered） | `jwdid` | Wooldridge ETWFE；回归法框架；支持 poisson/logit 非线性；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| 面板/重复截面 | 错时（staggered） | `did_imputation` | BJS 插补法；`leaveout` 方差修正（唯一实现）；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |

## 详细方法参考（references/）

每个 references/ 文件聚焦一个方法或一组相关方法的详细签名、工作流、选项。所有陷阱条目统一在主文件的「关键陷阱速查」节维护，不在 references/ 重复。

| 场景需求 | references/ 文件 | 内容 |
|---|---|---|
| 错时 DID + DR/IPW/Reg 三方法 / 非线性 / leaveout / 灵活 FE | [csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) | `csdid` + `jwdid` + `did_imputation` 三个错时 DID 社区包详解 |
| 处理单位极少 + 长前期 + placebo 推断 | [synth.md](references/synth.md) | `synth` + `synth_runner` 合成控制 + ADH 2015 置换推断 |
| 充分前后期 + comparison units；单个或多个处理单位及当前实现支持的多个处理日期 | [sdid.md](references/sdid.md) | `sdid` 合成 DID（Arkhangelsky et al. 2021）|
| 想用 `reghdfe` 手动生成事件研究系数 + 多维聚类 | [reghdfe-event-study.md](references/reghdfe-event-study.md) | `reghdfe` + 手动相对时间哑变量 |
| 处理可逆 / 非二元处理 / 无 stayers | [dcdh.md](references/dcdh.md) | `did_multiplegt` 三模式（dyn / stat / had）|
| 想要 TWFE 偏误诊断 / 大数据 100M+ 行 | [stacked.md](references/stacked.md) | `stacked` 堆叠 DID + Q 权重 + D 统计量 |
| 局部投影事件研究 / 冲击型处理 / 少聚类 | [lpdid.md](references/lpdid.md) | `lpdid` 长差分 + 干净对照条件 |
| 完整 DID 研究项目工作流（目标→稳健性） | [workflow-8step.md](references/workflow-8step.md) | Baker et al. (2025) 8 步 practitioner 工作流 |
| 错时 DID + 高维共同因子 + 处理与潜在因子相关 | [trop.md](references/trop.md) | `trop` Triply Robust Panel Estimator（TROP）|
| 面板 MDE / 功效分析 / sample size justification | [power-analysis-template.do](references/power-analysis-template.do) | Bloom 1995 analytical MDE + Burlig et al. 2020 面板仿真 |

## 方法选择决策树

用户描述 DID 场景时，按以下逻辑自动推荐最合适的估计量。**优先级从上到下**——匹配到第一条就推荐，不要继续往下。

### 场景路由表

| 用户场景特征 | 推荐方法 | 理由 |
|-------------|---------|------|
| named `synth` 或 4b 上下文；少数处理单位 + 较长 pre-period + donor pool 可辩护 | `synth` | 以 donor pool 拟合合成对照，需 placebo / permutation 推断 |
| named `sdid` 或 4b 上下文；充分 pre / post + untreated 或 not-yet-treated comparison units；单个或多个处理单位、当前实现支持的多个处理日期 | `sdid` | 同时估计单位与时间权重；推断依赖方法特定 VCE / regularity 条件，不要求少数处理单位 |
| 简单 2x2 DID（一组处理、一组对照、单时点） | `didregress` / `xtdidregress`（见 `stata-did` skill） | 官方内置，最简单，estat 诊断丰富 |
| **处理可逆**（可开启也可关闭，如工会/补贴/政策撤销） | `did_multiplegt (dyn)` | **唯一**支持非吸收处理的 Stata DID 估计量；见 [references/dcdh.md](references/dcdh.md) |
| **处理非二元**（连续/离散多值，如最低工资幅度、补贴金额） | `did_multiplegt (dyn)` 或 `(stat)` | 支持非二元处理 + 归一化效应；见 [references/dcdh.md](references/dcdh.md) |
| **无 stayers**（所有单位最终都处理） | `did_multiplegt (had)` | 专为无 stayer 的异质性采用设计；见 [references/dcdh.md](references/dcdh.md) |
| 错时 DID + 结果变量是计数/二元（如就诊次数、是否住院） | `jwdid method(poisson)` 或 `jwdid method(logit)` | **唯一**支持非线性模型；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| 错时 DID + 想要 `leaveout` 方差修正（有限样本更准确） | `did_imputation, leaveout` | **唯一**实现 BJS 附录 A.9；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| 错时 DID + 想要单位特定趋势（unit-specific trends） | `did_imputation, unitcontrols(year)` | `unitcontrols()` 选项；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| 错时 DID + 想要灵活 FE 规格（如州×年 FE） | `did_imputation, fe(i t#state)` | `fe()` 任意组合；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| 错时 DID + 想做 DR/IPW/Reg 三方法对照 | `csdid method(dr)` | 唯一提供三种估计方法；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| 错时 DID + 想要设计诊断（看 TWFE 偏误来源） | `stacked` | D 统计量直接报告权重差距；见 [references/stacked.md](references/stacked.md) |
| 错时 DID + 大数据（100M+ 行） | `stacked` | DuckDB 后端秒级回归；见 [references/stacked.md](references/stacked.md) |
| 错时 DID + 少聚类（<50） | `lpdid bootstrap(500)` | wild bootstrap 内置；见 [references/lpdid.md](references/lpdid.md) |
| 冲击型处理（飓风、地震，仅持续 1 期） | `lpdid nonabsorbing(#, oneoff)` | 专门设计；见 [references/lpdid.md](references/lpdid.md) |
| 非吸收处理 + 持久型（可开启/关闭） | `lpdid nonabsorbing(#)` | 与 DCDH 互补：LPDiD 用长差分，DCDH 用事件研究；见 [references/lpdid.md](references/lpdid.md) |
| 错时 DID + 想要一键出图 | `jwdid` + `estat plot` | `estat plot` 一键事件研究图；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| 错时 DID + 想要内置平行趋势检验 | `jwdid` 或 `did_imputation` | `estat event, pretrend` 或 `pretrends(k)`；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| 错时 DID + 想要异质性约束 | `jwdid hettype(event/cohort/time)` | `hettype()` 选项；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| 错时 DID + 高维共同因子（单元 FE 不能吸收）+ 处理与潜在因子相关 | `trop, factors(k=auto)` | 多因子矩阵 + 核范数 + triply robust（任一组件 unbiased）；见 [references/trop.md](references/trop.md) |
| 错时 DID + 默认（无特殊需求） | `hdidregress aipw`（见 `stata-did` skill） | 官方内置，estat 诊断丰富，默认推荐 |

### 特征对照矩阵

#### 核心能力

| 特征 | didregress | hdidregress | csdid | jwdid | did_imputation | DCDH | stacked | lpdid |
|------|-----------|-------------|-------|-------|----------------|------|---------|-------|
| 内置命令 | ✅ | ✅ | ❌ SSC | ❌ SSC | ❌ SSC | ❌ SSC | ❌ GitHub | ❌ SSC |
| 错时 DID | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **可逆处理** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **唯一** | ❌ | ✅ nonabsorbing |
| **非二元处理** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **冲击型处理** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ oneoff |
| 非线性模型 | ❌ | ❌ | ❌ | ✅ poisson/logit | ❌ | ❌ | ❌ | ❌ |
| DR/IPW/Reg 方法 | ❌ | aipw | ✅ 三方法 | ❌ | ❌ | ❌ | ❌ | ❌ |
| leaveout 方差修正 | ❌ | ❌ | ❌ | ❌ | ✅ **唯一** | ❌ | ❌ | ❌ |
| 单位特定趋势 | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| 灵活 FE 规格 | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |

#### 诊断与人机工程

| 特征 | didregress | hdidregress | csdid | jwdid | did_imputation | DCDH | stacked | lpdid |
|------|-----------|-------------|-------|-------|----------------|------|---------|-------|
| **长差分+局部投影** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **唯一** |
| **设计诊断 D 统计量** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **唯一** | ❌ |
| **按 cohort 权重分解** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ bygroup | ❌ |
| **大数据（100M+）** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ DuckDB | ❌ |
| wild bootstrap | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| estat plot | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ dyn 自动出图 | ✅ stacked plot | ✅ 内置出图 |
| pretrend 检验 | estat ptrends | estat ptrends | 手动 | ✅ estat | ✅ pretrends | ✅ placebo 期 | ✅ screen D | ✅ pre 系数 |
| hettype 约束 | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| 控制组选择 | — | notyet | notyet/never | notyet/never | — | not-yet-switchers | both/never/notyet | all clean/never |
| 滞后效应 | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ dyn 模式 | ❌ | ❌ |

#### TROP 能力补充（按数据特征 / 估计目标选；plan 笔误修正：不加 TROP 列以避免现有 9 列结构 diff 过大）

| 特征 | `csdid` DR/IPW | `jwdid` ETWFE | TROP |
|---|---|---|---|
| 共同因子模型 | 不建模 | 单元固定效应 | 多因子矩阵 + 核范数 |
| 内生选择处理 | 不处理 | 不处理 | 处理 |
| Semiparametric efficient | 不追求 | 不追求 | 异质下也成立 |
| Stata 包名 | `csdid` | `jwdid` | `trop` |
| 安装方式 | `ssc install` | `ssc install` | `ssc install trop` |
| 必需基础包 | `drdid` | `reghdfe` | `nprobust` |

**如何选**：看你的**数据特征**和**估计目标**，不是"哪个更好"。
- 处理准随机 + 单元 FE 足够 → `csdid` / `jwdid` / `did_imputation` 都行
- 处理与潜在因子相关 / 高维共同因子不能被 FE 吸收 → TROP
- 单时点简单 DID → `didregress` / `xtdidregress`（见 `stata-did` skill）

详见 [references/trop.md](references/trop.md)。

### AI Agent 选择逻辑

当用户描述 DID 场景时，按以下顺序检查：

1. **合成分支入口（仅 named `synth` / `sdid` 或 standard DID 失败进入 4b 时执行）**：少数处理单位、较长 pre-period 且 donor pool 可辩护？ → `synth`；有充分 pre / post、untreated 或 not-yet-treated comparison units（可为单个或多个处理单位及当前实现支持的多个处理日期）且 weighting / latent-factor / regularity 条件可辩护？ → `sdid`。named 单一方法 gate 失败可返回 `stata-identification`；4b 上下文中一个入口失败必须继续检查另一个，两个入口均失败才返回 router。普通 DID-community 选择跳过本步，直接从第 2 步开始，不得让宽泛的 `sdid` 条件截断后续路径
2. **处理是否可逆**：处理可以开启/关闭（工会、补贴、政策撤销）？ → `did_multiplegt (dyn)`（见 [references/dcdh.md](references/dcdh.md)）
3. **处理是否非二元**：连续或多值处理（最低工资幅度、补贴金额）？ → `did_multiplegt (dyn)` 或 `(stat)`（见 [references/dcdh.md](references/dcdh.md)）
4. **无 stayers**：所有单位最终都处理？ → `did_multiplegt (had)`（见 [references/dcdh.md](references/dcdh.md)）
5. **处理时点**：单时点？ → `didregress` / `xtdidregress`（见 `stata-did` skill）
6. **结果变量类型**：计数/二元？ → `jwdid method(poisson/logit)`（见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md)）
7. **方差修正需求**：要 leaveout？ → `did_imputation, leaveout`（见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md)）
8. **FE 需求**：要灵活 FE（如州×年）？ → `did_imputation, fe()`（见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md)）
9. **估计方法需求**：要 DR/IPW/Reg？ → `csdid method(dr)`（见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md)）
10. **设计诊断需求**：要看到 TWFE 偏误来源 + cohort 权重分解？ → `stacked`（见 [references/stacked.md](references/stacked.md)）
11. **大数据需求**：数据 100M+ 行？ → `stacked` DuckDB 后端（见 [references/stacked.md](references/stacked.md)）
12. **冲击型处理**：处理仅持续 1 期（飓风、地震）？ → `lpdid nonabsorbing(#, oneoff)`（见 [references/lpdid.md](references/lpdid.md)）
13. **少聚类**：聚类数 < 50？ → `lpdid bootstrap(500)`（见 [references/lpdid.md](references/lpdid.md)）
14. **长差分需求**：想用局部投影估计任意 horizon 的动态效应？ → `lpdid`（见 [references/lpdid.md](references/lpdid.md)）
15. **出图需求**：要一键出图？ → `jwdid` + `estat plot`（见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md)）
15a. **Sun-Abraham / SA 2021 引用**：用户问 SA 2021 怎么做 / 论文需 SA 估计量 → `csdid method(dr)` + `estat event`（SA-IW 与 csdid DR/IPW 在 staggered 共同支撑下渐近等价；见 [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) § Sun-Abraham 等价说明）。**不要路由到 R `did_multiplegt_dyn` SA 选项**——R `did_multiplegt` 没有 SA 选项。
16. **默认**：`hdidregress aipw`（官方内置，最稳妥，见 `stata-did` skill）

## 事后命令速查

| 命令 | 适用估计 | 作用 |
|---|---|---|
| `estat simple` | csdid | 简单聚合 ATT（总体效应） |
| `estat group` | csdid | 按 cohort（首次处理年份）聚合 |
| `estat event` | csdid | 按事件时间聚合（事件研究系数） |
| `estat simple` | jwdid | 简单聚合 ATT（总体效应） |
| `estat group` | jwdid | 按 cohort 聚合 |
| `estat calendar` | jwdid | 按时间聚合（每年总体 ATT） |
| `estat event` | jwdid | 按事件时间聚合（事件研究系数） |
| `estat plot` | jwdid | 事件研究图（一键出图） |
| `estat event, pretrend` | jwdid | 平行趋势检验（pre-treatment ATT 联合为零） |
| `horizons(0/5)` | did_imputation | 按事件期报告 ATT（直接在估计时指定） |
| `pretrends(k)` | did_imputation | 平行趋势检验（k 个 pre-trend 系数 + F 检验） |
| `leaveout` | did_imputation | 有限样本方差修正（BJS 附录 A.9，唯一实现） |
| `effects(5)` | did_multiplegt (dyn) | 估计 5 期事件研究效应 |
| `placebo(2)` | did_multiplegt (dyn) | 2 期安慰剂检验（处理前） |
| `normalized` | did_multiplegt (dyn) | 归一化效应（可解释为"处理+1 单位"） |
| `design(0.5, console)` | did_multiplegt (dyn) | 显示 ≥50% switchers 的处理路径 |
| `by_path(all)` | did_multiplegt (dyn) | 按处理路径分别估计 |
| `stacked kappa` | stacked | 事件窗口权衡表 + D 统计量 |
| `stacked build` | stacked | 构建堆叠数据集 |
| `stacked reg` | stacked | Q 加权事件研究回归 |
| `stacked reg, model(att)` | stacked | 单一 ATT |
| `stacked reg, bygroup` | stacked | 按 cohort 分解 |
| `stacked reg, fe(interacted)` | stacked | 交互固定效应（规范设定） |
| `stacked summary` | stacked | 设计诊断：权重差距 + 恒等式 |
| `stacked plot` | stacked | 事件研究图 |
| `stacked plot, bygroup` | stacked | 按 cohort 分解图 |
| `lpdid Y, ... pre(#) post(#)` | lpdid | 方差加权事件研究 |
| `lpdid Y, ... rw` | lpdid | 等权重 ATT |
| `lpdid Y, ... pmd(max)` | lpdid | 前均值差分版本 |
| `lpdid Y, ... nonabsorbing(#)` | lpdid | 非吸收处理 |
| `lpdid Y, ... nonabsorbing(#, oneoff)` | lpdid | 冲击型处理 |
| `lpdid Y, ... bootstrap(500)` | lpdid | wild bootstrap 推断 |
| `matrix list e(results)` | lpdid | 查看事件研究系数 |
| `matrix list e(pooled_results)` | lpdid | 查看汇总效应 |

## 关键陷阱速查

> 统一格式：**陷阱 → 触发条件 → Fix 命令 → 验证命令** 四件套。每条陷阱都给出可执行的修复 + 验证；Agent 在 SKILL.md 读到警告时即拿到完整修复路径。

1. **`synth` 的 `trunit()` 只认数值 id，预测变量只能用处理前期**
   - **触发**：字符串州名/国名传入 `trunit()`；预测变量混入处理后期信息。
   - **Fix**：`encode country, gen(country_id)` → `synth ..., trunit(7) trperiod(1988)` → 期段写法 `beer(1984(1)1988)` 的上限 ≤ `trperiod()-1`。
   - **验证**：跑完查 pre-period RMSPE 与平衡表（处理 vs 合成的预测变量均值差）；RMSPE 过大说明合成对照失配。

2. **`synth` 没有内置 SE / p 值**
   - **触发**：只报 `synth` 点估计与 `fig` 图就投稿。
   - **Fix**：`synth_runner ..., gen_vars` 跑 placebo 置换推断，`single_treatment_graphs` + `pval_graphs` 报 RMSPE 比排名（ADH 2015 标准做法）。
   - **验证**：捐赠池 < 10 个控制单位时 placebo 排名分辨率不足，论文中明说推断粒度限制。

3. **`sdid` 的处理变量是 treat×post 哑变量，不是 cohort 成员变量**
   - **触发**：传入"是否属于处理州"（全期 = 1）会把处理前期也当处理后。
   - **Fix**：先 `gen treat = (state==1 & year>=15)` 再 `sdid y state year treat, ...`。
   - **验证**：面板数据用 `vce(jackknife)`（更快）；重复截面 jackknife 不可用、改用默认 `bootstrap`。

4. **`csdid` 的 `gvar()` 编码错误**
   - **触发**：从未处理单位编码为 `9999` 等哨兵值（应用 `0` 或 `.`）。
   - **Fix**：`replace first_treat = 0 if never_treated` 或 `replace first_treat = . if never_treated`。
   - **验证**：跑完 `tab first_treat` 确认 never-treated 组的编码；`gvar()` 只接受数值型，字符串先 `encode`。

5. **`jwdid` 的 `method()` 必须配合 `group` 选项**
   - **触发**：非线性模型（poisson/logit）下用个体固定效应导致 incidental parameter problem。
   - **Fix**：`jwdid y x, ivar(id) tvar(t) gvar(g) method(poisson) group`。
   - **验证**：线性模型（默认 reghdfe）不需要 `group`，但加了也不报错——`group` 只在非线性时有意义。

6. **`did_imputation` 的 `Ei` 编码错误（与 csdid/jwdid 不同）**
   - **触发**：从未处理单位的 `Ei` 用 `0` 或 `9999`（应用 `.` 缺失）。
   - **Fix**：`replace Ei = . if never_treated`。
   - **验证**：跑完 `tab Ei, missing` 确认 never-treated 组的编码是 `.`（缺失），不是 `0`。注意：`did_imputation` 的 `Ei` 用 `missing()` 识别 never-treated，与 `csdid`/`jwdid` 的 `gvar` 编码（`0` = 从未处理）**不同**。

7. **`did_multiplegt` 的模式参数是位置参数，不是选项**
   - **触发**：写成 `did_multiplegt Y G T D, mode(dyn)`。
   - **Fix**：固定写作 `did_multiplegt (dyn) Y G T D, ...`。
   - **验证**：`(stat)` / `(had)` / `(old)` 同理。

8. **`did_multiplegt (dyn)` 的时间变量需等间距**
   - **触发**：数据有缺失年份（如 2018 跳到 2020），命令报错或结果错误。
   - **Fix**：先 `tsfill` 填充缺失期；或确认数据中所有组的时间变量都等间距。
   - **验证**：跑完 `xtset id t` 应无 gap。

9. **`did_multiplegt (dyn)` 的 `placebo()` 不能超过 `effects()`**
   - **触发**：`placebo(5) effects(3)`。
   - **Fix**：`placebo(#)` 的 `#` 必须 ≤ `effects(#)` 的 `#`。
   - **验证**：先确认 effects 数目再写 placebo 期数。

10. **`did_multiplegt (dyn)` 的 `bootstrap()` 参数用逗号分隔**
    - **触发**：写成 `bootstrap(100 seed(20260817))`。
    - **Fix**：`bootstrap(reps,seed)`——如 `bootstrap(100,20260817)`；留空默认 50 次无 seed。
    - **验证**：两个参数都必须写（即使留空保留逗号）。

11. **`stacked` 未上 SSC**
    - **触发**：`ssc install stacked` 失败。
    - **Fix**：`net install stacked, from("https://raw.githubusercontent.com/hollina/stacked/main/Stata") replace`。
    - **验证**：本地安装后确认 `which stacked` 有输出；CI 环境需预装或缓存。

12. **`stacked build` 会替换内存中的数据**
    - **触发**：运行后原始面板被堆叠数据集覆盖。
    - **Fix**：`save original.dta, replace` → `stacked build ...` → 分析完 `use original.dta, clear` 恢复。
    - **验证**：在 build 前后各跑一次 `describe` 比对 obs 数。

13. **`stacked kappa` 的 `kpost` 太大会丢弃最新 cohort**
    - **触发**：最新 cohort 的 post 期不足 `kpost` 时被静默丢弃。
    - **Fix**：先跑 `stacked kappa` 看哪些 `(kpre, kpost)` 组合保留所有 cohort；选 `n_sub_exp` 最大的组合。
    - **验证**：跑完查 `stacked kappa` 输出的 cohort 保留表。

14. **`stacked reg, fe(interacted)` 需要 `reghdfe`**
    - **触发**：未安装 `reghdfe` 时 `fe(interacted)` 报错。
    - **Fix**：`ssc install reghdfe, replace`；或用默认 `fe(saturated)`（无 FE，不需要 `reghdfe`）。
    - **验证**：`which reghdfe` 应有输出。

15. **`lpdid` 的 `pre()` 必须 ≥2**
    - **触发**：`pre(1)` 报错。
    - **Fix**：`pre(5)` 或更大；最少 2 期。
    - **验证**：事件研究系数的最小 horizon 应 ≥ -pre+1。

16. **`lpdid` 的 `nonabsorbing()` 与 `rw` 组合时用回归调整**
    - **触发**：含协变量 + `rw` 时走 RA 路径（DGJT §4.1.1）；不含 `rw` 时直接加入 OLS（需效应与协变量独立假设）。
    - **Fix**：有协变量时优先用 `rw`（RA 路径假设更弱）。
    - **验证**：跑完读 `help lpdid` §4.1.1 确认路径选择。

17. **`lpdid` 的结果存在 `e(results)` 矩阵中，不是 `e(b)`**
    - **触发**：`estat` 等标准 post-estimation 命令不适用。
    - **Fix**：`matrix list e(results)` 看事件研究系数；`matrix list e(pooled_results)` 看汇总效应；自定义图用 `svmat` 提取。
    - **验证**：`matrix list e(results)` 应输出 horizon × coefficient 矩阵。
18. **`estat ptrends` 的 p > 0.05 不证明 PT 成立**（Roth 2022 "Pretest with Caution"）
    - **触发**：simple 2x2 跑完 `estat ptrends` p > 0.05 就当作 PT 成立的证据；或 staggered 设计用 `estat ptrends` 检验加总 pre-trend。
    - **Fix**：简单 2x2 — p > 0.05 仅是"必要不充分条件"（功效不足永远不显著）；staggered — `estat ptrends` 检验的是加总 pre-period 系数，与 staggered 异质处理所需的 pre-trend-by-cohort 检验不同，正确做法是看 CS/SA 事件研究的 pre-period 系数（`estat event` 的 e<0 部分联合检验）。post-selection CI 偏宽，正式 pretest-adjusted CI 需 R `pretrends` 包——**Stata 无等价包**。
    - **验证**：论文 method 节应明说 staggered pre-trend 检查用 `csdid estat event` e<0 联合检验，不单报 `estat ptrends` 的 p 值。见 [references/workflow-8step.md](references/workflow-8step.md) 步骤 3。
19. **不要把 `did_had` 当作 `did_multiplegt (had)` 的"升级版"**
    - **触发**：用户研究 universal policy（连续剂量）时默认路由到 `did_had` v2.0.0；或反过来研究 0/1 处理 + stayers 时被引导到 `did_had`。
    - **Fix**：两者估计**不同参数**——`did_multiplegt (had)` 估计 DID_M（一个 scalar ATT）；`did_had` 估计 WAS_d̲（dose-response 斜率族）。两者依赖**不同识别假设**——`did_multiplegt (had)` 用 PT w/ quasi-stayer；`did_had` 在无 QUG 时用 boundary identification（无需 PT）。按**数据特征**（0/1 vs 连续；QUG 是否存在）和**研究问题**（ATT vs dose-response curve）分叉选择，不存在"哪个更先进"。
    - **验证**：决策树命中哪个路由，对照 [references/dcdh.md](references/dcdh.md) § 数据特征分叉决策树，不要直接报"`did_had` 更现代所以用它"。
20. **`did_multiplegt (had)` 要求 quasi-stayer 必须存在**
    - **触发**：universal policy 设计（全国最低工资、普惠补贴，所有单位都收到处理 D > 0）跑 `did_multiplegt (had)` 报"DID_M 未识别"或结果怪异。
    - **Fix**：quasi-stayer（剂量约等于 0 的单位）是 `did_multiplegt (had)` 的必要条件；如果所有单位 D > 0 严格正，DID_M 在该框架下未识别。**改用 `did_had` v2.0.0 的 boundary identification**——只需剂量分布在 0 附近连续或最小剂量 d > 0 附近连续，不依赖 PT。安装：`net install did_had, from("https://raw.githubusercontent.com/Credible-Answers/did_had/main") replace`。
    - **验证**：跑前先 `tab D` 看是否有 D ≈ 0 的单位（QUG），无则改 `did_had`。见 [references/dcdh.md](references/dcdh.md) § 识别假设对比（关键）。
21. **`trop` 的因子个数 k 不要盲用默认**
    - **触发**：直接 `trop ..., factors(k=3)` 不看 IC 表，或跳过 `factors(ic=bic)`。
    - **Fix**：先 `trop ..., factors(ic=bic)` 看 IC 表再定 k；需要固定 k 时再写 `factors(k=# method=nuclear)`。
    - **验证**：对照 IC 表所选 k 与报告的因子数一致；见 [references/trop.md](references/trop.md)。
22. **`trop` 的 nuclear-norm lambda 需 CV，默认可能过拟合**
    - **触发**：用默认 lambda 在高维因子设定下点估计偏大 / 方差偏小。
    - **Fix**：`trop ..., lambda(cv)` 走 cross-validation。
    - **验证**：报告 CV 选出的 lambda；敏感时再扫一小组 lambda。
23. **`trop` bootstrap reps 过少会让 CI 偏窄**
    - **触发**：multiplier bootstrap `reps` < 200 就报正式 CI。
    - **Fix**：建议 `reps(500)`（或至少 ≥ 200）。
    - **验证**：提高 reps 后 CI 宽度稳定；见 [references/trop.md](references/trop.md)。
24. **`trop` + `nprobust` 小样本带宽不稳**
    - **触发**：聚类数 < 30 时仍依赖 nprobust 默认带宽做推断。
    - **Fix**：少聚类时改用更稳健的推断路径或增大样本；带宽需 ≥ 30 cluster 才较稳。
    - **验证**：`tab`/`distinct` 聚类数；不足则在论文中声明带宽限制并换方法（如 `lpdid bootstrap`）。

## 🔍 错误码速查（错误码 → 触发 → 修复）

> 与上方「❌ Agent 不该做的事（黑名单）」互补：黑名单给原则，错误码给精准命中。Agent 看到 r(N) 时直接查本节定位。

- **`r(503)`** — csdid / jwdid 小样本 conformability（已知 csdid 限制）。**修复**：用 capture estat group/event 包住；详见 CHANGELOG scripts capture 包住段
- **`r(111)`** — did_imputation 报 not sorted。**修复**：sort id t；面板必须按 id-time 排序
- **`r(301)`** — did_imputation 报 endogenous，leaveout 修正缺失。**修复**：did_imputation ..., leaveout autosample；horizon 外样本不足时降 horizons

## 参考文献与延伸阅读

> 完整文献清单（含 `[csdid-jwdid-imputation]` / `[synth-sdid]` / `[dcdh]` / `[stacked]` / `[lpdid]` 标签）见各 `references/*.md` 末尾。本节只列跨方法的核心综述。

- **Bertrand, Duflo & Mullainathan (2004)** "How much should we trust differences-in-differences estimates?" *QJE* 119(1): 249-275. — DID 推断问题的奠基讨论（cluster SE、必要聚类数等）。
- **Roth, Sant'Anna, Bilinski & Poe (2022)** "What's Trending in Difference-in-Differences? A Synthesis of the Recent Econometrics Literature." — 错时 DID 的最新综述。
- **Baker et al. (2025)** "How Practice Meets Theory in DiD: An 8-Step Practitioner's Workflow." — [diff-diff 仓库](https://github.com/igerber/diff-diff) 提炼的实操工作流（详见 [references/workflow-8step.md](references/workflow-8step.md)）。
- **Rambachan & Roth (2023)** "A More Credible Approach to Parallel Trends." *Review of Economic Studies*. — Honest DiD（平行趋势违反下的稳健 CI）。
- **Princeton DSS 教程**：https://libguides.princeton.edu/stata-did — wdipol.dta 案例数据来源。

各方法专论文献见对应 references/：

- 错时 DID 三件套 → [references/csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) 末尾
- 合成控制 + 合成 DID → [references/synth.md](references/synth.md) + [references/sdid.md](references/sdid.md) 末尾
- DCDH 三模式 → [references/dcdh.md](references/dcdh.md) 末尾
- StackedDiD → [references/stacked.md](references/stacked.md) 末尾
- LPDiD → [references/lpdid.md](references/lpdid.md) 末尾

## ❌ Agent 不该做的事（黑名单）

> 与 ADR-0001 联动：本节是「**主动反模式**」清单——「关键陷阱速查」是被动警告，本节是主动规范。Agent 在写 DID 社区包 do-file 前必查一遍。Stata 内置 DID 反模式见 `stata-did/SKILL.md` 同名节；本节只覆盖社区包特有反模式。

- ❌ **不要在错时 DID + 传统 TWFE**（见 `stata-did` skill 第 6 条陷阱）。**替代**：`hdidregress aipw`（默认） / `csdid` / `jwdid` / `did_imputation`（按决策树选）。
- ❌ **不要在 `synth` 用 `trunit("California")` 字符串 id**：`trunit()` 只认数值。**替代**：`encode country, gen(country_id)` → `synth ..., trunit(7)`。
- ❌ **不要在 `sdid` 把 `treat` 写成"是否属于处理州"**（全期=1）：偷看未来，系数偏到零。**替代**：`gen treat = (state==1 & year>=15)`；面板用 `vce(jackknife)`，重复截面用 `bootstrap`。
- ❌ **不要在 `csdid` / `jwdid` 用 `9999` 作哨兵值**：never-treated 应用 `0` 或 `.`。**替代**：`replace first_treat = 0 if never_treated`；`tab first_treat` 验证。
- ❌ **不要在 `did_imputation` 用 `0` 作 never-treated Ei**：与 `csdid` / `jwdid` 编码**相反**——did_imputation 用 `missing()` 识别 never-treated。**替代**：`replace Ei = . if never_treated`；`tab Ei, missing` 验证。
- ❌ **不要在 `did_multiplegt` 写成 `, mode(dyn)`**：模式是位置参数，不是选项。**替代**：`did_multiplegt (dyn) Y G T D, ...`；`(stat)` / `(had)` / `(old)` 同理。
- ❌ **不要在 `stacked` 用 `fe(interacted)` 而不装 `reghdfe`**：报错。**替代**：`ssc install reghdfe`；或用默认 `fe(saturated)`（不需要 reghdfe）。
- ❌ **不要在 `lpdid` 用 `pre(1)`**：报 `pre() must be >= 2`。**替代**：`pre(5)` 或更大；最少 2 期。
- ❌ **不要在 `stacked` 跑前不 `save original.dta`**：`stacked build` 替换内存数据。**替代**：`save original.dta, replace` → `stacked build ...` → `use original.dta, clear` 恢复。
- ❌ **不要在 `synth` 预测变量混入处理后期信息**：让合成单位偷看未来，估计失效。**替代**：`beer(1984(1)1988)` 的上限 ≤ `trperiod()-1`；预测变量期段写法严格在处理前。
- ❌ **不要只跑 `synth` 不跑 placebo 推断**：没有 SE / p 值，投稿会被打回。**替代**：`synth_runner ..., gen_vars` 跑 placebo 置换推断（ADH 2015 标准做法）。
- ❌ **不要把 10 个社区包都跑一遍当稳健性**：强制路径命中第一条就停。**替代**：按下表只跑命中的那条命令链；默认错时回 `stata-did` 的 `hdidregress aipw`。
- ❌ **不要把分数线 / 年龄门槛 / 地理边界改走 `csdid` / `synth`**：不是时间断点，合成对照也救不了。**替代**：转到 `stata-rdd`。

## 验证

- 本 skill 的社区包（csdid / jwdid / did_imputation / synth / sdid）由 `verify/verify-synth-sdid.do` 覆盖：
  - 数据：`csdid` 部分用本地模拟数据（40 units × 10 periods，2 cohorts，`set seed` 固定）；`data/synth/synth_smoking.dta`（加州 Prop 99 经典案例，47045 字节，来源 scunning1975/mixtape，MIT 许可；下载脚本 `data/synth/download_synth_smoking.sh`，字节校验 EXPECTED_SIZE=47045，变化需团队确认）；`sdid` 部分用本地模拟数据（800 obs，39 对照 + 1 处理 × 20 期）。
  - 模式：
    - `bash verify/run-verify.sh did`（默认）：社区包已装则 PASS；未装则用 `cap which` 跳过关键命令、log 末尾打 `__COMMUNITY_PACKAGE_MISSING__<pkg>__` sentinel，仍 PASS（适合 CI / 网络受限环境）。
    - `bash verify/run-verify.sh did --community`：缺任一必需包（csdid / jwdid / did_imputation / synth / sdid）即 BAD，强制本地"真验证"。
    - `synth_runner` / `drdid` / `hdfe` 标记为可选——缺包仅打 sentinel，不影响 PASS。
  - 网络受限时本节方法与 `synthdid` R 包 / diff-diff 的 `SyntheticDiD` 同源，可跨语言替代。
- 运行：`bash verify/run-verify.sh did-community`（默认）/ `bash verify/run-verify.sh did-community --community`（强制）；全量 10 个 skill：`bash verify/run-verify.sh`。

## ✅ 交付前自检清单（跑完命令后逐条核对）

- [ ] 方法选择命中决策树单条链，未把 10 个社区包全跑一遍当稳健性；错时默认回 `stata-did` 的 `hdidregress aipw`
- [ ] 编码契约：`csdid`/`jwdid` 的 never-treated 用 `0`/`.`；`did_imputation` 的 `Ei` 用 `.` 缺失（两套编码未混用）
- [ ] `synth`：`trunit()` 数值 id；预测变量期段 ≤ `trperiod()-1`；跑了 placebo 置换推断（`synth_runner`），不只报点估计
- [ ] `sdid`：处理变量是 treat×post 哑变量（未把「属于处理组」当全期处理）；面板 `vce(jackknife)`、重复截面用默认
- [ ] `did_multiplegt`：模式是位置参数 (dyn)；`placebo(#)` ≤ `effects(#)`；时间变量已 `tsfill` 等间距
- [ ] `stacked`：跑前 `save original.dta`；`fe(interacted)` 已装 `reghdfe`；`lpdid` 用 `pre()` ≥ 2 且结果读 `e(results)`
- [ ] log 恰好一次 `end of do-file`；`--community` 模式下无必需包（csdid/jwdid/did_imputation/synth/sdid）sentinel
