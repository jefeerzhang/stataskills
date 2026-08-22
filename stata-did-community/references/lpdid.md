---
name: stata-did-community-lpdid
description: LPDiD 局部投影 DID 参考：Dube, Girardi, Jordà & Taylor (2025) 长差分 + 干净对照条件。覆盖方差加权 ATT、等权重 ATT、局部投影事件研究、非吸收处理（含冲击型 oneoff）、少聚类下 wild bootstrap。主文件见 stata-did-community/SKILL.md。
---

# stata-did-community-lpdid

> **加载时机**：主 SKILL.md 决策树已读完，遇到"想用局部投影估计任意 horizon 动态效应"、"冲击型处理（飓风/地震仅持续 1 期）"、"少聚类 (<50)"中任一场景时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 7. LPDiD：局部投影双重差分（Dube, Girardi, Jordà & Taylor 2025）

适用场景：想要**长差分事件研究**——用局部投影（local projections）估计动态效应，同时限制估计样本为"新处理单位 + 干净对照组"，避免 TWFE 负权重偏误。与 `csdid`/`hdidregress` 的"逐 cohort 估计后聚合"不同，LPDiD 直接跑长差分回归，每期一个方程，更灵活、更直观。

核心思想：把 `y_{t+h} - y_{t-1}`（h 期长差分）对 `ΔD`（处理变化）回归，只用"干净对照组"（D_{t+h}=0 的单位）。每个 horizon h 一个方程，系数就是该期的 ATT。

### 安装

```stata
ssc install lpdid, replace
* 依赖（一次性）
ssc install reghdfe, replace
ssc install ftools, replace
ssc install listreg, replace
ssc install boottest, replace
ssc install egenmore, replace
```

### 核心语法

```stata
lpdid Y, unit(varname) time(varname) treat(varname) pre(#) post(#) [options]
```

| 参数 | 含义 |
|---|---|
| `Y` | 结局变量 |
| `unit(varname)` | 单位 id（默认也是聚类变量） |
| `time(varname)` | 时间变量 |
| `treat(varname)` | 处理指示变量（0/1 二元） |
| `pre(#)` | 事件窗口前的期数（≥2） |
| `post(#)` | 事件窗口后的期数（≥0） |

### 主要选项

| 选项 | 含义 | 默认 |
|---|---|---|
| `rw` | 重新加权以估计等权重 ATT（而非方差加权 ATT） | 关闭 |
| `controls(varlist)` | 协变量 | — |
| `absorb(varlist)` | 额外固定效应（时间 FE 自动包含） | — |
| `ylags(#)` | 结局变量滞后项 | — |
| `dylags(#)` | 结局变量一阶差分滞后项 | — |
| `cluster(varname)` | 聚类变量 | 默认按 unit 聚类 |
| `nevertreated` | 仅用从未处理单位做对照 | 关闭（用所有干净对照） |
| `nocomp` | 排除跨期组合效应（保持同一对照组） | 关闭 |
| `pmd(#)` | 前均值差分版本（用多个 pre 期均值做基准） | 关闭 |
| `bootstrap(#)` | wild bootstrap 推断（少聚类时推荐） | 关闭 |
| `seed(#)` | bootstrap 随机种子 | — |
| `nonabsorbing(#, [opts])` | 非吸收处理（见下表） | — |
| `nograph` | 不出图 | 关闭 |
| `only_pooled` | 仅估计汇总效应（跳过事件研究） | 关闭 |
| `only_event` | 仅估计事件研究（跳过汇总效应） | 关闭 |

### 非吸收处理选项 `nonabsorbing()`

| 子选项 | 含义 |
|---|---|
| `nonabsorbing(#)` | 效应在 # 期后稳定；持久处理（入处后持续直到退出） |
| `nonabsorbing(#, notyet)` | 仅用 not-yet-treated 做对照 |
| `nonabsorbing(#, firsttreat)` | 仅估计首次处理的效应 |
| `nonabsorbing(#, oneoff)` | 冲击型处理（仅持续 1 期，如飓风） |
| `nonabsorbing(, firsttreat notyet)` | 首次处理 vs 从未处理（无需指定稳定期数） |

### 完整工作流示例

```stata
* 0. 安装（一次性）
ssc install lpdid, replace
ssc install reghdfe ftools listreg boottest egenmore, replace

* 1. 加载示例数据
use http://fmwww.bc.edu/repec/bocode/l/lpdidtestdata1.dta, clear

* 2. 基础事件研究（方差加权 ATT）
lpdid Y, time(time) unit(unit) treat(treat) pre(5) post(10)

* 3. 等权重 ATT（重新加权）
lpdid Y, time(time) unit(unit) treat(treat) pre(5) post(10) rw

* 4. 排除组合效应
lpdid Y, time(time) unit(unit) treat(treat) pre(5) post(10) rw nocomp

* 5. 仅用从未处理做对照
lpdid Y, time(time) unit(unit) treat(treat) pre(5) post(10) rw nevertreated

* 6. 前均值差分版本
lpdid Y, time(time) unit(unit) treat(treat) pre(5) post(10) pmd(max)

* 7. 含协变量
lpdid Y, time(time) unit(unit) treat(treat) pre(5) post(10) rw controls(gdp unemployment)

* 8. 少聚类时用 wild bootstrap
lpdid Y, time(time) unit(unit) treat(treat) pre(5) post(10) bootstrap(500) seed(20260817)

* 9. 非吸收处理（效果在 5 期后稳定）
use http://fmwww.bc.edu/repec/bocode/l/lpdidtestdata2.dta, clear
lpdid Y, time(time) unit(unit) treat(treat) pre(5) post(10) nonabs(5)

* 10. 冲击型处理（如飓风）
use http://fmwww.bc.edu/repec/bocode/l/lpdidtestdata3.dta, clear
lpdid Y, time(time) unit(unit) treat(treat) pre(5) post(10) nonabs(3, oneoff)

* 11. 自定义事件研究图
lpdid Y, time(time) unit(unit) treat(treat) pre(5) post(10) nograph
matrix R = e(results)
svmat R, names(col)
gen horizon = _n - (e(pre_window) + 1) if (_n - (e(pre_window) + 1))<=e(post_window)
twoway (rcap ci_high ci_low horizon, color(gs6)) ///
       (scatter coefficient horizon, color(blue)), legend(off)
```

### 方差加权 vs 等权重 ATT

| 版本 | 选项 | 权重 | 何时用 |
|---|---|---|---|
| 方差加权（默认） | 无 `rw` | 更精确的 cohort 权重更大 | 效应同质时最高效 |
| 等权重 | `rw` | 每个 treated obs 等权重 | 效应异质时更稳健 |

**bias-variance tradeoff**：方差加权有偏（不同 cohort 权重不同）但方差更小；等权重无偏但方差更大。默认方差加权的权重**严格为正**（不像 TWFE 可能为负），所以即使不加 `rw` 也比 TWFE 更可靠。

### LPDiD vs 其他估计量

| 场景 | 推荐 | 理由 |
|---|---|---|
| 长差分事件研究 + 干净对照 | **LPDiD** | 局部投影天然支持任意 horizon |
| 少聚类（<50） | **LPDiD** | `bootstrap()` wild bootstrap 内置 |
| 非吸收处理 + 持久型 | **LPDiD** `nonabsorbing(#)` | 专门设计 |
| 冲击型处理（飓风、地震） | **LPDiD** `nonabsorbing(#, oneoff)` | 专门设计 |
| 要 DR/IPW/Reg 三方法 | `csdid` | LPDiD 无此选项 |
| 要设计诊断 D 统计量 | `stacked` | LPDiD 无此功能 |
| 要非线性模型 | `jwdid` | LPDiD 仅支持线性 |

### 与 diff-diff 的对应关系

`lpdid` ≈ diff-diff 的 `LPDiD`。diff-diff 用 `lpdid` 作为 Stata 端的交叉验证锚点。

