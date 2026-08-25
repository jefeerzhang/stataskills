---
name: stata-regression-iv-identification
description: IV 识别与论文解释：联合秩条件、relevance/independence/exclusion/monotonicity/SUTVA、LATE/complier、第一阶段-简约式-2SLS 结果三角、Wald ratio、OLS-IV 差异与最低报告规范。主文件见 stata-regression/SKILL.md。
---

# 10.10 IV 识别与论文解释（扩展，教材未覆盖）

> 主 SKILL.md 路由 IV 命令选择时仍读 [iv.md](iv.md)、检验体系时仍读 [iv-testing.md](iv-testing.md)；本文承担「识别假设 / LATE / 结果三角 / 论文解释」四项实证论文必需的语义，避免把这些规则再次散落在命令/检验文档里。

## 1. 先画识别图

写任何 IV 命令之前，先用 ASCII 图把识别假设画给读者：

```
            Z (工具)
           / \
          /   \
         v     v
   D (内生)    (Z->Y 直通？)
         \     /
          v   v
            Y (结果)
```

**凡有 Z->Y 直通的可能路径，必须先在论文中堵住**。这是写「识别图」的目的：把每条可能的旁路写出来，再对每条旁路写出机构 / 时间 / 个体 / 地理 / 制度上的阻断论证。任何一条未阻断，就回到工具选择阶段。

## 2. 哪些条件能诊断，哪些只能论证

把识别假设分为两列，方法完全不同：

| 条件 | 性质 | 数据诊断手段 | 论文必须做的事 |
| --- | --- | --- | --- |
| relevance | 数据可诊断 | 第一阶段 Z->D、KP rk LM、Wald F、Shea 偏 R2 | 报第一阶段、偏 R2、排除性 F |
| independence | 仅靠制度 | 几乎无（过度识别只是噪声子集的间接信号） | 讲清工具分配机制；列出所有可能 Z->Y 旁路并逐一论证阻断 |
| exclusion | 仅靠制度 | 同上 | 工具只通过 D 影响 Y 的机制叙述 + 安慰剂 / 伪结局 |
| monotonicity | 制度 / 设计论证 | 部分可由边界点处行为差异旁证 | 若用 LATE 解释，需明确 defiers 不存在 |
| SUTVA | 设计论证 | 可用稳健性（替换工具 / 子样本） | 明确无 spillover 与 stable unit value |

**过度识别检验（Hansen J、Sargan、C 统计量）只是「工具子集之间是否一致」的统计噪声测试**；不拒绝 ≠ 工具外生。Reduced form Z->Y 显著也不是排除限制的证据；它只是「工具能走通整条因果链」的必要信号。任何「J 不拒绝所以排除限制成立」「reduced form 显著所以识别成立」的写法都是逻辑错位。

## 3. 多内生变量：数量条件不是秩条件

- 必要条件：工具数 L ≥ 内生数 K。
- 真实识别条件：排除性工具与内生变量组成的**条件相关矩阵满秩**。`(x1 x2 = z1 z2)` 不是给 x1 配 z1、给 x2 配 z2 的一一映射，而是 z1、z2 联合识别 x1、x2。
- 单个内生变量显著不等于系统已被识别。报第一阶段时用 `estat firststage, all`（官方）或 `ivreg2 ..., ffirst`（社区）看「联合 F / 条件 F」与「每个内生变量的偏 F」是否都拒绝。
- 实务：先把工具集与内生变量集画矩阵图，工具与内生变量尽量一一对应；不能一一对应时跑联合识别检验。

## 4. IV 系数估计谁：LATE 与 complier

在**二元工具 Z ∈ {0,1} 与二元处理 D ∈ {0,1}**、且上述五项假设成立时：

- **always-takers**：Z=0 与 Z=1 时都取 D=1。
- **never-takers**：Z=0 与 Z=1 时都取 D=0。
- **compliers**：Z=0 取 D=0、Z=1 取 D=1。
- **defiers**：Z=0 取 D=1、Z=1 取 D=0——monotonicity 排除。

`ivregress 2sls` 在该设置下识别的是 **compliers 的局部平均处理效应（LATE）**——`β_IV = E[Y_i(1) - Y_i(0) | complier]`。

**禁止**把 `β_IV` 默认写成全样本 ATE、ATT 或全样本平均效应，除非：

- 处理效应同质（任意子样本效应相等）；或
- 有可辩护的额外假设（如 Imbens-Angrist 1994 的单调性 + 处理效应单调，或完全独立 + 完全外生下的外推）。

多值/连续处理或异质效应下，`ivregress 2sls` 估计的是**工具诱导的加权局部平均效应**（LATET 框架），不是 ATE。

**外推限制**：LATE 仅在当前样本与当前工具推动的 compliers 上成立。换样本、换工具、换时代，都需要新的论证。

## 5. 结果三角：第一阶段、简约式与 2SLS

**主表必须**按同一设定（**相同样本、外生控制、固定效应、权重、VCE**）报告三类回归：

1. **第一阶段** `regress D Z X, vce(...)`：报告排除性工具系数、偏 R2、排除性 F / KP F。
2. **简约式** `regress Y Z X, vce(...)`：报告工具对结果的直接效应，用于检查结果链一致性。
3. **2SLS** `ivregress 2sls Y X (D = Z), vce(...) first`：报告内生变量系数 + 弱工具稳健 CI（AR 或 KP CI）。

**恰好识别（L = K）** 时三者满足代数恒等式：

```
β_2SLS = β_reduced_form(Z) / β_first_stage(Z)
```

`verify/verify-regression.do` 的 `ch10.10` 段对这条恒等式用 `assert` 做了数值断言（`iv_triangle_wald=...`）。

**这个恒等式只检查结果链一致，不检验排除限制**——若 `assert` 失败意味着代码或模型设置错了；若通过只意味着三个回归共享样本与控制，不能用来「证明外生性」。

## 6. 论文主表、正文与限制模板

### 6.1 主表最小列

| 列 | 内容 |
| --- | --- |
| Panel A: 第一阶段 | 工具系数（SE）、KP rk LM (p)、KP rk Wald F、偏 R2 |
| Panel B: 主结果 | OLS（β、SE）+ 2SLS/LIML/Fuller（β、SE）+ 95% CI 或弱工具稳健 CI（AR/KP CI） |
| 控制 | 同第一节列出的外生控制、FE 指示变量、权重声明 |
| 聚类 | VCE 层级（个体 / 县 / 年份等） |
| N | 估计样本量（必须三者一致） |

### 6.2 正文与脚注可改写模板

> 工具 Z 通过**已建立的制度通道**影响处理 D（引用具体制度设计），而**不直接影响**结果 Y：列出我们已排除的所有 Z->Y 旁路并对每条给出阻断论证。

> 在二元工具与二元处理下，2SLS 系数识别的是 compliers 的局部平均处理效应（LATE），并不自动代表全样本 ATE。compliers 的范围受样本、工具与时代限制，外推须谨慎。

> 第一阶段 KP rk Wald F = <值>，对照 Stock-Yogo 10% maximal IV size 临界值 <值>（多工具 / 多内生变量时直接抄脚注临界值）。当 F 低于临界值时，主表改报 LIML 或 Fuller(λ)，并补充 Anderson-Rubin 95% CI（恰好识别时 AR 与 CLR 等价）。

### 6.3 限制与不可外推声明（至少写一句）

> 本估计仅在 <样本 / 工具 / 时代> 范围内识别 compliers 的 LATE；处理效应异质或工具变化会改变估计人群与效应大小，谨慎外推到其他人群。

### 6.4 禁止的写法（与黑名单联动）

- ❌ 「Hansen J 不拒绝，所以工具外生。」——J 不拒绝≠外生。
- ❌ 「Reduced form 显著，所以 IV 系数有效。」——显著≠排除限制。
- ❌ 「OLS 与 IV 的差异证明 OLS 偏误。」——差异可来自内生性与处理效应异质性两源。
- ❌ 「因为 `ivregress` 报告了系数，所以是 ATE。」——除非附加论证，默认是 LATE。

## 7. 与命令/检验文档的边界

- 命令选择、语法、依赖：见 [iv.md](iv.md)。
- 统计检验、弱工具推断、过度识别检验、出表：见 [iv-testing.md](iv-testing.md)。
- 多层 FE + IV 语法的命令级细节：见 [ivreghdfe.md](ivreghdfe.md)。
- 高维 FE OLS：见 [reghdfe.md](reghdfe.md)。

本文**只承担**识别假设、LATE、结果三角、论文解释与最低报告规范；不在此复制命令签名或检验公式。
