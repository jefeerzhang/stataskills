---
name: stata-did-community-reghdfe-event-study
description: reghdfe 手动哑变量事件研究参考：高维固定效应 + 手动生成相对时间哑变量 + 估计事件研究系数。需 ssc install reghdfe。主文件见 stata-did-community/SKILL.md。
---

# stata-did-community-reghdfe-event-study

> **加载时机**：主 SKILL.md 决策树已读完，遇到"想用 reghdfe 手动生成事件研究系数 + 多维聚类"时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 4. `reghdfe` 事件研究（手动哑变量）

`hdidregress` / `xthdidregress` 是 Stata 18+ 内置的错时 DID 异质性估计；Stata 17 及更早，社区包 `reghdfe`（Sergio Correia）的事件研究写法是主流——构建"相对时间"哑变量、手动选参考期、用 `reghdfe` 跑。这条脉络对阅读旧论文与维护旧代码至关重要。

```stata
* 1. 构造相对时间（事件时间）
gen rel_time = year - treat_year if treated == 1
replace rel_time = 0 if treated == 0     // 对照组所有期都映射到参考期

* 2. 生成每期一个哑变量（除参考期）
tab rel_time, gen(time_to_event)
drop time_to_event11                      // 假设 rel_time=-1 作参考期

* 3. 跑事件研究（双向 FE + 聚类稳健 SE）
reghdfe y (time_to_event*), absorb(id year) cluster(id)
coefplot, keep(time_to_event*) vertical ///
    yline(0) xline(-0.5, lpattern(dash)) ///
    title("Event study (reghdfe manual dummies)") ///
    scheme(s1mono)
```

`coefplot` 画出的每点对应一个相对时间的事件期系数；pre-treatment 期（负 rel_time）应不显著、落在零线附近，post-treatment 期（正 rel_time）开始显著——这就是"事件研究图"的视觉判读。

**Fix**：参考期选择影响整张图的解读——常选 `rel_time = -1`（处理前一期）；太长或太短的参考期都会让事件期系数估计有偏。

