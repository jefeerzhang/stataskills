---
name: stata-dce
description: Use for discrete choice experiments with choice sets, alternatives, attribute levels, conditional logit, mixed logit, panel choice, latent classes, and WTP; triggers include DCE, discrete choice experiment, cmset, cmclogit, cmmixlogit, cmxtmixlogit, asclogit, mixlogit, lclogit, and willingness to pay.
compatibility: >-
  适配 StataNow 19.5。官方 cm* 为默认入口；用户点名 clogit、wtp、mixlogit 或 lclogit 时直达社区参考与相应数据 gate。
---

# Stata 离散选择实验（DCE）

DCE 让受访者在多个 choice set 中从若干 alternatives 选择一个方案。每行是一个 alternative，`chosen==1` 表示该 choice set 的被选方案；attributes/levels 描述方案，respondent 与 choice set 标识重复选择结构。

```stata
version 19.5
```

## 运行 Stata 的方式

- 批处理接口：`stata-mp -b do "脚本.do"`；Windows 路径见 `docs/run-stata.md`。
- 需要图形时默认英文标签；如需中文图表，先询问用户。

## 强制路径

1. **设计与数据 gate**：确认 respondent、choice set、alternative、chosen、attributes、levels 和价格变量；long 数据中每个 choice set 必须有至少两个 alternatives 且恰好一个 `chosen==1`。同一 respondent 的重复 choice task 不能当作 iid 横截面。
2. **声明 choice data**：一次选择任务用 `cmset caseid alternative`；重复选择用 `cmset respondent task alternative`。先检查唯一键、choice-set 完整性和 chosen 计数，再估计。
3. **基准模型**：用 `cmclogit chosen attributes, casevars(case_covariates)`；说明 base alternative、VCE 和效用尺度。
4. **偏好异质性**：固定系数变量与 `random()` 中的变量分开；`intseed()` 只搭配 `intmethod(random)`。重复选择且偏好跨任务共享时用 `cmxtmixlogit` 或社区 `mixlogit ..., id(resp_id)`；按 respondent 聚类只调整推断，不能替代 panel likelihood。
5. **WTP 与解释**：preference-space 中 `WTP_k=-beta_k/beta_price`。先检查价格系数符号、显著性和非零性，再用 `nlcom`、bootstrap 或 simulation 给出不确定性；不要把 utility coefficient 直接称作货币 WTP。
6. **潜在类别扩展**：若假设离散的偏好类别，使用可选社区包 `lclogit`；先确认 `group()` 是全局唯一 choice set、`id()` 是 respondent、`ncl()` 是类别数。`membership()` 依赖 `fmlogit`，变量须在同一人全部任务间不变。用 `lclogitpr` 生成总体选择概率（`pr0`）、总体及类别条件概率（`pr`）、先验类别概率（`up`）和后验类别概率（`cp`）。
7. **诊断与稳健性**：报告 choice-set invariant、替代方案合理性、IIA 的设计与模型证据、随机系数分布、simulation settings，以及 conditional logit、mixed/panel mixed logit 与 latent-class 的敏感性比较。

## 详细参考（references/）

| 文件 | 只承担的职责 |
|---|---|
| [dce.md](references/dce.md) | 数据结构、cmset、conditional/mixed/panel mixed logit、WTP 与诊断 |
| [community.md](references/community.md) | clogit、wtp、mixlogit/mixlpred、lclogit/lclogitpr、五类别加权与 probcalc 边界 |

## 关键陷阱速查

1. **把 DCE 当普通 `mlogit`** → **触发**：没有 choice-set/alternative 结构 → **Fix**：整理 long alternatives 并先 `cmset` → **验证**：每个 choice set 恰好一个 chosen。
2. **choice set 多个或零个 chosen** → **触发**：编码或合并错误 → **Fix**：按 respondent/task/alternative 检查 `bysort` 计数 → **验证**：chosen 总和为 1。
3. **重复选择当 iid** → **触发**：同一 respondent 完成多个 task → **Fix**：`cmxtmixlogit` 或 respondent cluster → **验证**：报告面板结构与 VCE。
4. **把 WTP 当系数** → **触发**：遗漏价格分母或价格系数接近 0 → **Fix**：`-beta_attribute/beta_price` 并用 delta/bootstrap 不确定性 → **验证**：价格符号和可识别性先通过。
5. **机械宣称 IIA 通过/失败** → **触发**：只依赖单个 Hausman 检验 → **Fix**：结合设计、替代方案相似性和 mixed-logit 稳健性 → **验证**：报告检验限制与模型比较。
6. **未报告模拟设定** → **触发**：mixed logit 只给系数 → **Fix**：记录 distribution、integration method、points、seed → **验证**：结果可复现。
7. **混淆先验与后验类别概率** → **触发**：把 `up` 或 `cp` 当成同一个量 → **Fix**：分别报告 H 与 G，`pr` 同时生成总体及各类别条件选择概率 → **验证**：H/G 跨类别加总为 1 且同一人不变，总体选择概率等于按 H 加权的类别条件概率。
8. **把 probcalc 当 DCE 预测** → **触发**：发现名称含 probability 就套用 → **Fix**：它是常见分布计算器，DCE 用 mixlpred/lclogitpr → **验证**：检查帮助文件与选择概率按 choice set 加总为 1。

## 可执行禁令

- ❌ 禁止在未检查 choice-set 完整性前估计；替代：先 `cmset`、唯一键和 chosen 计数检查。
- ❌ 禁止把 DCE 的 `chosen` 直接送入普通个体 `logit/mlogit` 作为主路径；替代：使用 `cmclogit`/`cmmixlogit`。
- ❌ 禁止把 IIA 单一检验当作模型真理；替代：结合设计与替代模型稳健性。
- ❌ 禁止价格系数为零或符号不合理时报告常规 WTP；替代：先修正设计/编码或明确 WTP 不可识别。
- ❌ 禁止混淆 preference-space 与 WTP-space；替代：写清参数化和转换方法。
- ❌ 禁止把 `lclogitpr` 的 `pr0`、`pr`、`up`、`cp` 混为一种概率；替代：按 choice、class、prior、posterior 四个层级分别命名和核对。

## 错误码速查

- **`r(198)`**：`cmset` 或 choice-model 语法/选项错误；核对官方 help 与 case/alternative 变量。
- **`r(459)`**：choice-set 结构、重复键或估计条件不满足；回到数据 gate。
- **`r(2000)`**：共同样本为空或 chosen/attributes 缺失；检查 `misstable summarize` 与完整 choice set。

## 验证

- `bash verify/run-verify.sh dce` 在 Stata 19.5 上验证 `cmset`、choice-set invariant、`cmclogit` 与 `cmmixlogit`。
- `wtp`、`mixlogit`、`lclogit`（membership 依赖 `fmlogit`）已纳入实际估计与预测断言；缺包使用 optional sentinel。`probcalc` 单独验证分布计算，不能当 DCE 后估计。`mixlogitwtp` 尚未纳入执行验证。
