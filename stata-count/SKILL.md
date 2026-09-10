---
name: stata-count
description: Stata 计数与非负结果建模：Poisson、negative binomial、ZIP/ZINB、PPML、高维固定效应 ppmlhdfe、exposure/offset、IRR、零膨胀、分离诊断与边际效应。触发词：专利数、就医次数、贸易额、poisson、nbreg、zip、zinb、ppmlhdfe。
compatibility: StataNow 19.5；poisson/nbreg/zip/zinb 内置，ppmlhdfe 与 ftools/reghdfe 为社区依赖。
---

# Stata 计数模型与 PPML

## 强制路径

匹配到第一条后进入对应 reference 的本地检查，不机械估计所有模型。

1. 政策识别、错时处理的目标是 ATET → `stata-did` / `stata-did-community`，计数链接不能替代 DID 识别设计。
2. 比例受限于 [0,1] → `stata-fractional`；零是删失或选择性观测 → `stata-limited-dependent`。
3. 非负连续结果（含零的贸易额、支出）或高维固定效应 → [count-ppml.md](references/count-ppml.md) 的 PPML 路径；先审计条件均值、零值机制与固定效应可识别性。
4. 非负整数计数 → 同一 reference 的 Poisson 起点；观测窗口不同先定义 exposure，过度离散看 NB，只有独立结构零机制有依据才考虑 ZIP/ZINB。

```stata
version 19.5
```

## 运行 Stata 的方式

`stata-mp -b do "脚本.do"`；Windows 命令与路径见 `docs/run-stata.md`。图表默认英文，需要中文先询问用户。

## 详细参考

| 文件 | 内容 |
|---|---|
| [count-ppml.md](references/count-ppml.md) | 计数/PPML 选择、exposure、过度离散、结构零、HDFE、诊断与报告 |

## 关键陷阱速查

1. **取 log(y+1) 代替计数均值** → 触发：有零值就平移取对数 → Fix：根据原尺度条件均值选 Poisson/PPML → 验证：结果保留零值，明确原尺度 estimand。
2. **offset 用原始暴露量** → 触发：`offset(exposure)` → Fix：`exposure(exposure)` 或 `offset(log_exposure)` → 验证：两种正确规格系数一致。
3. **零多就 ZIP** → 触发：只根据零值比例选模型 → Fix：先论证结构零与计数过程 → 验证：分别报告两部分变量、预测零比例及同样本拟合。
4. **PPML 限于整数** → 触发：贸易额带小数被踢走 → Fix：非负连续结果可用 PPML 加 robust/cluster VCE → 验证：非整数 fixture 与 dummy-FE 基准一致。
5. **忽略分离与样本变化** → 触发：只读收敛标记 → Fix：报告被剔除的 separation/singleton 观测及 FE 层级 → 验证：核对 e(sample)、剔除数量和共同样本。
6. **过度离散就判 PPML 无效** → 触发：方差大于均值 → Fix：区分完整分布拟合与条件均值一致性 → 验证：稳健 VCE 与均值设定诊断分别报告。

## 可执行禁令

- 禁止对 PPML 使用负因变量、把缺失值填零；替代：审计测量与缺失来源。
- 禁止把 `exp(beta)` 当原尺度增加量；替代：计数模型说明 IRR，原尺度效应用 `margins`。
- 禁止用常规 LR 检验比较 robust QMLE、非嵌套或不同样本模型；替代：可比的预测与明确假设的检验。
- 禁止用 Vuong 的单个 p 值自动决定 ZIP/ZINB；替代：过程机制、样本与预测诊断。

## 验证与交付

`bash verify/run-verify.sh count`：验证 exposure/offset 等价、count/rate 恒等式、NB、ZIP/ZINB 概率边界、非整数 PPML，以及安装社区包后的 HDFE/dummy-FE 等价。具体 p 值不锁定为通过标准。报告 N、零值比例、暴露单位、FE、VCE、收敛、剔除与边际效应。
