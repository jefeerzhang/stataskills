---
name: stata-limited-dependent
description: Stata 有限因变量：删失 Tobit、截断与区间观测边界、Cragg hurdle、两部模型、Heckman 样本选择、heckprobit、选择方程排除变量与边际效应。触发词：tobit、churdle、heckman、heckprobit、样本选择偏误、零支出、删失、two-part。
compatibility: StataNow 19.5，主路径全部内置；与 stata-selection 的处理选择及 ATET 路径独立。
---

# Stata 删失、两部与样本选择模型

## 强制路径

先确定为何观测到零或缺失。按第一条成立的机制进入 [limited-dependent.md](references/limited-dependent.md)，不把所有方法当稳健性套餐。

1. 目标是二元处理的 ATET，结果对处理组/对照组都可观测 → `stata-selection`；Heckman 不是 PSM 的同义词。
2. 有明确定义的潜在连续结果，被测量/记录规则压在上下界 → Tobit；先确认界限、删失比例及正态/同方差假设。
3. 真实零支出与正支出属于不同参与/强度过程 → 两部模型或 Cragg hurdle；零不能当未观测 outcome。
4. 结果只对 selected=1 可见，但 selected=0 的选择变量与协变量可观测 → 连续 outcome 用 Heckman，二元 outcome 用 heckprobit。先论证选择方程排除变量和联合分布；两者都不足时停止把模型称作已解决选择偏误。
5. 样本在界外彻底不进入数据 → 截断，不能套普通 Tobit；区间值只知上下限 → 区间回归。这两个扩展目前只识别边界，不提供未验证模板。

```stata
version 19.5
```

## 运行 Stata 的方式

`stata-mp -b do "脚本.do"`；Windows 路径见 `docs/run-stata.md`。默认英文图表，中文先询问用户。

## 详细参考

[limited-dependent.md](references/limited-dependent.md)：数据机制、命令链、不同预测目标、排除限制、检验与推断。

## 关键陷阱速查

1. **零值就 Tobit** → 触发：支出等于零 → Fix：检查真实零、删失、选择性缺失的产生机制 → 验证：记录编码与测量规则。
2. **把缺失工资填成零** → 触发：非就业者工资不可见 → Fix：保持缺失，单独定义 selected → 验证：选择指标与 outcome 的可观测性相符。
3. **把 PSM 与 Heckman 混同** → 触发：都含 selection 一词 → Fix：区分处理分配与结果可观测性 → 验证：两个模型的研究对象分别写明。
4. **只靠函数形式识别** → 触发：选择方程和结果方程完全同变量 → Fix：寻找有实质依据的排除变量并做敏感性说明 → 验证：它影响可观测性、不直接影响结果的论证独立于 p 值。
5. **手工 IMR 后用 OLS SE** → 触发：自行两阶段回归 → Fix：官方 `heckman, twostep` 或合适的重抽流程 → 验证：考虑生成回归量的不确定性。
6. **系数当观测均值 AME** → 触发：直接解释 Tobit beta/Heckman xb → Fix：明确 ystar、ycond、xb、pcond 的目标 → 验证：预测恒等式及对应 margins。
7. **两部模型只传播第二部 SE** → 触发：概率乘条件均值后套单模型区间 → Fix：联合估计或整条两部链重抽 → 验证：重抽包含两个模型，按抽样单位处理依赖。

## 可执行禁令

- 禁止把 rho 检验不拒绝当成“没有样本选择问题”的证明；替代：机制、排除变量、样本支持及敏感性证据。
- 禁止只保留 selected=1 再估计选择模型；替代：保留未选中者的选择指标与协变量。
- 禁止对 `heckman, twostep` 做 ML 似然比较；替代：区分两步和 ML 推断。
- 禁止把选择修正当成处理内生性的通用解法；替代：另行确定 IV/处理效应设计。

## 验证与交付

`bash verify/run-verify.sh limited-dependent` 验证 Tobit、Cragg hurdle、两部均值、Heckman ML/两步和 heckprobit；断言检验截限下观测均值和正值概率的关系、样本状态、联合与条件概率恒等式。报告数据机制、排除变量、收敛、rho/相关检验、预测目标及边际效应。
