---
name: stata-did-community-sdid
description: 合成 DID 参考：sdid（合成控制 × DID 结合）。Arkhangelsky et al. (2021) 实现，单处理单位下用 vce(noinference) 或 vce(jackknife) 跑点估计。主文件见 stata-did-community/SKILL.md。
---

# stata-did-community-sdid

> **加载时机**：主 SKILL.md 决策树已读完，遇到"处理单位 1 个 + 长前期 + 想结合 DID 推断"时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 3. 合成 DID：sdid（合成控制 × DID 的结合）

Arkhangelsky et al. (2021, *AER*)：同时给**单位**（像 synth）和**时期**加权，再跑加权 DID。比 synth 多了单位固定效应（允许持久水平差），比 DID 多了数据驱动的权重——通常 pre-period 拟合与稳健性都更好。Stata 实现：`sdid`（Clarke & Pailañir，SSC）。

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

- `vce()`：`bootstrap`（通用，默认推荐）/ `jackknife`（仅面板可用，更快）/ `placebo`（大捐赠池）/ `noinference`。
- `method(sdid|sc|did)`：同一框架切换 合成 DID / 纯合成控制 / 普通 DID——**三方法一行对照**，与 diff-diff 的 `SyntheticDiD` / `SyntheticControl` / `DifferenceInDifferences` 一一对应。
- `covariates(varlist, projected)`：协变量调整（`optimized` 为默认算法）。
- `graph`：效应图 + 权重图；结果存在 `e(ATT)`、`e(se)`、`e(series)`。
- 错时采用：v2+ 原生支持，按处理 cohort 分别估计后聚合（面板下可与 `hdidregress aipw` 互为稳健性对照）。

**何时用 sdid 而非 synth**：处理前存在持久水平差（synth 拟合不动）、或想要标准误而不只 placebo 排名。**何时用 sdid 而非 hdidregress**：处理单位极少、需要权重透明可展示（论文里报告哪些对照单位进入了合成）。

与 diff-diff 的对应关系：`sdid` ≈ `SyntheticDiD`（含 bootstrap 推断）；`synth` + synth_runner placebo ≈ `SyntheticControl` + `in_space_placebo()`。

### did_imputation 详解：BJS 插补法

`did_imputation` 是 Borusyak, Jaravel & Spiess (2024) 实现的**插补法** DID 估计量（SSC）。与 `csdid`/`jwdid` 的"逐组×逐期估计后聚合"或"饱和交互回归"不同，`did_imputation` 采用**三步插补法**：先用未处理观测估计 Y(0) 模型，再外推到处理观测得到 tau = Y - Y(0)，最后聚合。其独特卖点是 `leaveout` 方差修正（BJS 附录 A.9），这是**唯一**的 Stata 实现。

#### 安装

```stata
ssc install reghdfe, replace         // 依赖（如果未装）
ssc install did_imputation, replace  // 主包
```

#### 核心语法

```stata
did_imputation Y i t Ei [if] [in] [aw], ///
    [fe(i t)] [controls(varlist)] [unitcontrols(varlist)] ///
    [horizons(numlist)] [leaveout] [autosample] ///
    [pretrends(#)] [shift(#)] [cluster(varname)]
```

| 参数/选项 | 含义 | 默认 |
|---|---|---|
| `Y` | 结局变量 | 必填（位置参数 1） |
| `i` | 面板单位 id | 必填（位置参数 2） |
| `t` | 时间变量 | 必填（位置参数 3） |
| `Ei` | 首次处理期（缺失 = 从未处理） | 必填（位置参数 4） |
| `fe(i t)` | 固定效应结构 | 默认 `fe(i t)`（双向 FE） |
| `controls(varlist)` | 时变协变量 | — |
| `unitcontrols(varlist)` | 单位特定趋势 | — |
| `horizons(numlist)` | 报告哪些事件期（0, 1, 2, ...） | 默认仅报告总体 ATT |
| `leaveout` | **有限样本方差修正**（BJS 附录 A.9） | 默认关闭 |
| `autosample` | 自动剔除无法插补的观测 | 默认关闭（报错） |
| `pretrends(k)` | 平行趋势检验（k 个 pre-trend 系数） | 0（不检验） |
| `shift(#)` | 预期效应期数 | 0 |
| `cluster(varname)` | 聚类变量 | — |

#### 语法对比：did_imputation vs csdid/jwdid

| 维度 | `did_imputation` | `csdid` / `jwdid` |
|------|------------------|-------------------|
| 参数风格 | **位置参数** `Y i t Ei` | **命名参数** `y, ivar() tvar() gvar()` |
| 从未处理编码 | `Ei` 缺失（`.`） | `gvar = 0` 或 `.` |
| FE 规格 | `fe(i t)` 灵活组合 | 固定（个体 + 时间） |
| 事后聚合 | `horizons(0/5)` 直接报告 | `estat event` 事后聚合 |
| 方差修正 | `leaveout`（唯一实现） | 无 |

#### 完整工作流示例

```stata
* 0. 安装（一次性）
ssc install reghdfe, replace
ssc install did_imputation, replace

* 1. 数据准备
* first_treat = 首次处理期；缺失 = 从未处理
use my_panel, clear

* 2. 基本估计（总体 ATT）
did_imputation y id year first_treat

* 3. 事件研究（按 horizon 报告）
did_imputation y id year first_treat, horizons(0/5) autosample

* 4. leaveout 方差修正（推荐）
did_imputation y id year first_treat, horizons(0/5) leaveout autosample

* 5. 平行趋势检验（5 个 pre-trend 系数）
did_imputation y id year first_treat, pretrends(5)
* 结果：pre1-pre5 系数 + e(pre_F) + e(pre_p) + e(pre_df)

* 6. 预期效应（anticipation = 2 期）
did_imputation y id year first_treat, horizons(0/5) shift(2)

* 7. 单位特定趋势
did_imputation y id year first_treat, horizons(0/5) unitcontrols(year)

* 8. 灵活 FE（如：州×年 FE）
did_imputation y id year first_treat, fe(i t#state) horizons(0/5)
```

#### `leaveout` 方差修正：为什么重要？

BJS 附录 A.9 指出：标准插补法的方差估计在有限样本下有偏（因为处理观测也参与了 Y(0) 模型的估计）。`leaveout` 选项通过留一法修正此偏：

- **无 `leaveout`**：方差可能低估（过于乐观）
- **有 `leaveout`**：方差更准确（有限样本一致）

**这是 `did_imputation` 的独特卖点**——其他包（csdid/jwdid/hdidregress）都没有此选项。diff-diff 的 Python 实现 `ImputationDiD(leave_one_out=True)` 是唯一的跨语言对应。

#### `fe()` 灵活 FE 规格

`did_imputation` 支持任意 FE 组合，比 csdid/jwdid 更灵活：

```stata
* 标准双向 FE
did_imputation y id year Ei, fe(i t)

* 州×年 FE（县级数据）
did_imputation y county year Ei, fe(i t#state)

* 无 FE（仅控制变量）
did_imputation y id year Ei, fe(.)

* 单位×星期几 FE（高频数据）
did_imputation y id date Ei, fe(i#dow t)
```

#### 何时用 did_imputation vs csdid/jwdid

| 场景 | 推荐 | 理由 |
|---|---|---|
| 想要最高效估计（同质效应） | **`did_imputation`** | 插补法在同质效应下标准误最小 |
| 想要 `leaveout` 方差修正 | **`did_imputation`** | **唯一实现** |
| 想要单位特定趋势 | **`did_imputation`** | `unitcontrols()` 选项 |
| 想要灵活 FE 规格 | **`did_imputation`** | `fe()` 任意组合 |
| 想要 DR/IPW/Reg 三方法 | `csdid` | 唯一提供 |
| 非线性结果变量 | `jwdid` | 唯一支持 poisson/logit |
| 想要一键出图 | `jwdid` | `estat plot` |
| 想要 hettype 约束 | `jwdid` | `hettype()` 选项 |
| 官方内置 | `hdidregress` | Stata 18+ |

#### 与 diff-diff 的对应关系

`did_imputation` ≈ diff-diff 的 `ImputationDiD`（Python 估计量）。diff-diff 用 `did_imputation` 作为 Stata 端的交叉验证锚点，确认 Python 实现与 Stata 参考一致（SE 精度 ~1e-9，leaveout SE 精度 ~1e-9）。

