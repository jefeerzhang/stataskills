---
name: stata-did-community-synth
description: 合成控制参考：synth + synth_runner。覆盖少数处理单元 + 长前期场景，placebo 置换推断（RMSPE 比排名），预测变量期段语法（numlist start(1)end）。主文件见 stata-did-community/SKILL.md。
---

# stata-did-community-synth

> **加载时机**：主 SKILL.md 决策树已读完，遇到"处理单位 1 个或极少数"或"需要 placebo 推断"时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 2. 合成控制：synth / synth_runner（少数处理单元 + 长前期）

适用场景：**处理单位只有一个（或极少数）**（加州控烟法、某省自贸区试点、某城市限行），且处理前期较长——此时普通对照组"谁都不像处理单位"，DID 的平行趋势假设很难令人信服。合成控制（Abadie, Diamond & Hainmueller 2010）从捐赠池（donor pool）里加权组合出一个"合成对照"，使其处理前轨迹与处理单位尽量重合。

```stata
ssc install synth, replace             // 社区包（自带示例数据 synth_smoking.dta）

use synth_smoking.dta, clear           // 加州 Prop 99（1989 年生效）经典案例
tsset state year

* state==3 为加州；1989 年起处理
synth cigsale beer(1984(1)1988) lnincome(1972(1)1988) retprice age15to24 ///
      cigsale(1988) cigsale(1980) cigsale(1975), ///
      trunit(3) trperiod(1989) xperiod(1980(1)1988) ///
      nested fig keep(synth_smoking_out)
```

语法要点：

- `trunit(#)`：处理单位的**数值型** id（字符串先 `encode`，见 `stata-did` skill 第 9 节）；`trperiod(#)`：首个处理期。
- 预测变量可加期段：`beer(1984(1)1988)` 取 1984–1988 均值（注意：synth 包的 numlist 是 `start(1)end` 形式，不是 `start:end`；后者会被 synth 报 `invalid numlist r(121)`），`cigsale(1988)` 取单年值；不带期段的变量按 `xperiod()` 范围取均值。**预测变量只能用处理前期的信息**——混入处理后期等于偷看未来。
- `nested`：嵌套优化（多局部最优时更稳，推荐常加）；`allopt` 更彻底但更慢。
- `keep(file)`：把实际值与合成值存成 `.dta` 供后续画图；`fig`：直接出趋势对照图。

结果解读：`e(W)` 是捐赠池权重（哪些州、各占多少），`e(V)` 是预测变量权重；处理后各期 `e(Y_treated) - e(Y_synthetic)` 即各期效应（gap）。**pre-period 拟合越好（RMSPE 越小），post 期 gap 越可信。**

**推断：synth 不给 SE**——标准做法是 placebo 置换（ADH 2015）：把处理"假装"分给每个控制单位重跑，看真实处理的 post/pre RMSPE 比在全部 placebo 分布里的排名。手工循环繁琐，用 `synth_runner`（Galiani & Quistorff 2017）自动化：

```stata
ssc install synth_runner, replace
synth_runner cigsale beer(1984(1)1988) lnincome retprice age15to24, ///
    trunit(3) trperiod(1989) gen_vars

single_treatment_graphs, trlinediff(-1)   // 真实效应 vs 全部 placebo 效应
effect_graphs , trlinediff(-1)            // 效应与 placebo 分布对照
pval_graphs                               // 各期 placebo p 值
```

`gen_vars` 生成 `effect`（各期 gap）、`pre_rmspe`、`post_rmspe`、`lead`（相对期）等变量，可直接二次作图。多处理单位、错时时点时用 `d(处理哑变量)` 选项替代 `trunit()/trperiod()`，逐单位估计并聚合。

