---
name: stata-regression
description: Stata 回归建模：ANOVA / ANCOVA / 多元回归 / 逻辑回归 / margins 边际效应 / reghdfe 高维固定效应 / ivreghdfe IV 估计 / fect 错时 DID 偏差修正。对应教材第 9–11 章。触发词：回归 / ANOVA / margins / reghdfe / ivreghdfe / fect / 逻辑回归 / 固定效应。
---

# Stata 方差分析与回归建模（本书第 9–11 章）

本 skill 浓缩自《A Gentle Introduction to Stata》第 6 版第 9–11 章。覆盖：方差分析全家族、多元回归与诊断、逻辑回归与结果解读、各类功效分析。

> **文档分层（ADR-0001 / coefplot 模式）**：主 `SKILL.md` 只保留「强制路径 + references 路由 + 关键陷阱速查 + 黑名单」。每个章节/扩展方法的详细签名、完整工作流、安装步骤下沉到 `references/`。四件套陷阱统一在主文件「关键陷阱速查」维护；各扩展方法自身的「已知陷阱 / Things to be aware of」随方法留在对应 references。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`，内含全部输出。平台二进制路径与 Windows 等价命令见 `docs/run-stata.md`。
- 数据在仓库 `data/agis6/`；示例命令中的 `use 文件名, clear` 假定已 `cd` 到该目录。
- **中文作图规矩**：生成图形命令且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 强制路径

匹配到第一条就停。第 9–11 章与扩展方法语法见「详细参考（references/）」；禁令见文末黑名单。

**何时用**：ANOVA / ANCOVA、多元回归诊断、逻辑回归、`margins`、多层 FE（`reghdfe`）、多层 FE 下的 2SLS（`ivreghdfe`）。
**何时踢走**：
- 政策评估 / 平行趋势 / 错时 DID → `stata-did`（默认 `hdidregress aipw`）
- `fect` 是错时 DID 偏差修正，**不是**本 skill 的主估计；用户要 `fect` 时转到 `stata-did` / `stata-did-community`
- 分数线 / 年龄门槛 / 地理边界 → `stata-rdd`，不要用普通回归或 DID 冒充
- `ivreghdfe` 只是「吸收多层 FE 的 2SLS 语法」，不是完整 IV 识别（弱工具、排除限制、LATE）。没有识别策略就不要把系数写成因果
- 只要系数图 → 估完后转 `stata-coefplot`

| 用户场景 | 最短命令链 |
|---|---|
| ANCOVA（连续协变量） | `anova y i.group c.x`（`c.` 必写）或 `regress y i.group c.x` → `margins group, at(x=(...))` |
| 多元回归 | `regress y x1 x2` → `rvfplot` / `estat vif` / `estat hettest` → 需要图时 `estimates store` 后转 `stata-coefplot` |
| 逻辑回归 | `logit y x, or` → `margins, dydx(*)`；OR 不是风险比 |
| 2+ 层 FE / 多向聚类 | `reghdfe y x, absorb(fe1 fe2) vce(cluster cl1 cl2)`；先 `ftools, compile` |
| 多层 FE + 2SLS | `ivreghdfe y x (endog = iv), absorb(fe1 fe2)`；报告第一阶段，但不要把本命令当成 IV 设计本身 |
| 显著交互 / 二次项 | 禁止读主效应；`margins, dydx(*) at(...)` → `marginsplot` |

`fect`（10.7，见 [references/fect.md](references/fect.md)）仅作「错时 TWFE 有偏」的指针，新分析不要从这里起步。

## 详细参考（references/）

主文件只保留强制路径 + references 路由 + 关键陷阱速查 + 黑名单。每个章节/扩展方法的**详细签名 + 完整工作流 + 安装步骤**下沉到 `references/`，按需加载。

| 章节 / 方法 | references/ 文件 | 内容 |
|---|---|---|
| 第 9 章 方差分析（ANOVA） | [anova.md](references/anova.md) | 单因素 ANOVA / ANCOVA / 双因素与交互 / 重复测量 / ICC / 功效 |
| 第 10 章 多元回归 | [regression.md](references/regression.md) | 基本模型 / 半偏相关 / 正态性 / 残差诊断 / 加权 / 因子变量 / 交互 / 二次项 / 功效 |
| 第 11 章 逻辑回归 | [logistic.md](references/logistic.md) | logit/logistic / OR 解读 / 假设检验 / margins / 嵌套 / 功效 |
| 10.5 `reghdfe`（扩展，教材未覆盖） | [reghdfe.md](references/reghdfe.md) | 高维固定效应 OLS/IV、多向聚类、Driscoll-Kraay、compact |
| 10.6 `ivreghdfe`（扩展，教材未覆盖） | [ivreghdfe.md](references/ivreghdfe.md) | IV/2SLS/LIML/GMM2S + 多层 FE |
| 10.7 `fect`（扩展，教材未覆盖） | [fect.md](references/fect.md) | 错时 DID 的 TWFE 偏差修正（IFE / matrix completion） |

## 关键陷阱速查

> 统一格式：**陷阱 → 触发 → Fix → 验证** 四件套。每条陷阱都给出可执行的修复 + 验证；Agent 在 SKILL.md 读到警告时即拿到完整修复路径。

1. `anova` 中连续协变量必须 `c.` 前缀
   - **触发**：`anova y i.group age` 把连续变量 age 按分类处理，结果报"变量 age 重编码为 categorical"——错估自由度、结果不可信。
   - **Fix**：`anova y i.group c.age`（连续加 c. 前缀）；自检：`anova y i.group age` 应报"变量 age 重编码为 categorical"——见此提示就改 `c.age`。
   - **验证**：连续变量应保留小数位数值，不是整数分类；与 `regress y i.group c.age` 结果应一致。

2. 存在显著交互/二次项时：不直接读主效应/线性系数
   - **触发**：跑 `regress y i.group c.x c.x2` 后直接说"x 主效应 = b1"——交互/二次项存在时 b1 失去意义。
   - **Fix**：跑 `margins, dydx(*) at(...)` + `marginsplot`；解读只说"在某 X 取值下 Y 的变化"，不说"主效应"；删二次项若不再显著。
   - **验证**：报告必含 `marginsplot` 图 + 在具体 X 值下的边际效应；只报 b1 = 不完整报告。

3. pseudo-R² 不是解释方差；OR 不是风险比
   - **触发**：写"逻辑回归解释 50% 的方差"——pseudo-R² 与 OLS R² 不可比；"OR = 2 意味着风险翻倍"——OR 不是 RR。
   - **Fix**：逻辑回归报 OR 时用 `logit y x, or`；单位变化 >1 时 `display exp(b*X)`；pseudo-R² 仅作样本内拟合参考，**写报告明确写"伪 R²，不与 OLS R² 比较"**。
   - **验证**：报告应明说"伪 R²"；OR 解读应明说"发生比"而非"风险"。

4. nestreg 不支持因子变量记法
   - **触发**：写 `nestreg: regress y (c.x##c.x)` 报 `factor variables not allowed`。
   - **Fix**：先 `gen x2 = x^2` 显式生成；再用 `nestreg: regress y (x x2)`；不要写 `c.x##c.x` 进 nestreg。
   - **验证**：`nestreg, trace` 输出应逐块包含 x 与 x2；无 `factor variables not allowed` 错误。

5. 加权回归自动用稳健 SE；检查 sum of wgt 合理性
   - **触发**：用 `[aw=weight_var]` 跑回归，权重极端（如 sum of wgt 与 N 比值 < 0.5 或 > 2）导致 SE 估计异常。
   - **Fix**：跑前 `summarize [aw=weight_var]` 看 sum of wgt 与 N 比值；权重极端时改 `pw` 或归一化。
   - **验证**：sum of wgt / N 应接近 1；偏离过大时改用 `pw` 或归一化权重。

6. 不要跨群体比较标准化 β/相关
   - **触发**：分组比较标准化 β（如女性组 β=0.3 vs 男性组 β=0.5）说"男性效应更强"——标准化 β 跨组不可比。
   - **Fix**：分组比较只比原始系数 b（标尺相同）或 CI 重叠；标准化 β 仅在同一样本内不同变量间比，**不跨样本/跨组**。
   - **验证**：报告跨组比较时使用原始系数 b + CI 重叠检验；标准化 β 仅在同一样本内使用。

7. Stata 峰度正态值=3（SAS/SPSS 报减 3 值）
   - **触发**：跨软件比较峰度时，Stata 报 3.0（正态）而 SAS 报 0.0（正态）——被误读为分布形态不同。
   - **Fix**：跨软件比较峰度时 `display r(kurtosis) - 3` 转换；解读永远用 Stata 原值。
   - **验证**：报告峰度时标注"Stata 原值"；跨软件时用减 3 后值。

8. p 值报告 p<0.001
   - **触发**：同 descriptives 第 1 条——输出 `Prob = 0.0000`，复制到报告不符合 APA/Sci 惯例。
   - **Fix**：同 descriptives 第 1 条——`outreg2, pformat(%9.3f)` + 论文正文不用 0.000。
   - **验证**：导出表格 p 列均为 `<0.001`、`[0.001, 0.01)`、`[0.01, 0.05)`、`[0.05, 1)` 四档之一；无 `0.000`。

## ❌ Agent 不该做的事（黑名单）

> 与 ADR-0001 联动：本节是「**主动反模式**」清单——「关键陷阱速查」是被动警告，本节是主动规范。Agent 在写 do-file 前必查一遍。

- ❌ **不要把连续协变量不加 `c.` 前缀**：写 `anova y i.group age` 把 age 按分类处理，错估自由度。**替代**：`anova y i.group c.age`；与 `regress y i.group c.age` 结果应一致。
- ❌ **不要把逻辑回归的 OR 说成"风险比"**：OR ≠ RR（odds ratio 不是 risk ratio）。**替代**：报 OR 时明说"发生比"；横断面数据可用 OR，队列数据需 RR 时用 `cs` / `cc` 命令。
- ❌ **不要跨样本/跨组比较标准化 β**：β 仅在同一样本内不同变量间可比，跨组不可比。**替代**：跨组比较用原始系数 b（标尺相同）+ CI 重叠检验。
- ❌ **不要用 nestreg + `c.x##c.x`**：报 `factor variables not allowed`。**替代**：先 `gen x2 = x^2` 显式生成；用 `nestreg: regress y (x x2)`。
- ❌ **不要简单加更多控制变量平衡平行趋势**：可能引入 bad control（中介变量 / 后处理变量）。**替代**：按优先级：(1) `estat trendplot` 判断真趋势差；(2) 加**先验**协变量（非中介）；(3) 改 `hdidregress aipw`；(4) 三角化论证。
- ❌ **不要比较 pseudo-R² 与 OLS R²**：pseudo-R² 不解释方差，仅作样本内拟合参考。**替代**：报告必明说"伪 R²，不与 OLS R² 比较"。
- ❌ **不要在显著交互/二次项存在时读主效应/线性系数**：b1 失去意义。**替代**：`margins, dydx(*) at(...)` + `marginsplot`；解读只说"在某 X 取值下 Y 的变化"。
- ❌ **不要在本 skill 里把 `fect` 当政策评估主估计**：`fect` 是错时 DID 偏差修正，识别假设不在回归章。**替代**：政策 / 平行趋势 / 错时 → `stata-did`（默认 `hdidregress aipw`）或 `stata-did-community`。
- ❌ **不要把 `ivreghdfe` 写成完整 IV 识别**：它只吸收多层 FE 的 2SLS 语法，不检查弱工具、排除限制或 LATE。**替代**：报告第一阶段；没有识别策略就只解释为相关。分数线 / 年龄门槛不要用 IV 或回归冒充。
## 🔍 错误码速查（错误码 → 触发 → 修复）

> 与上方「❌ Agent 不该做的事（黑名单）」互补：黑名单给原则，错误码给精准命中。Agent 看到 r(N) 时直接查本节定位。

- **`r(131)`** — 回归系数发散（完全多重共线性）。**修复**：corr x* 查共线；剔除冗余或 regress, noabsorb 排查
- **`r(498)`** — FE 估计时变量组内方差为 0。**修复**：时不变变量跑 xtreg fe 自动 drop；改 regress i.id, noconstant
- **`r(7)`** — reghdfe 报 option absorb() not allowed。**修复**：reghdfe 吸收 FE 必放 absorb() 而非 i.；详见 references/reghdfe.md

