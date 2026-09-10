---
name: stata-fractional
description: Stata 分数响应与比例结果：fracreg logit/probit、betareg、0/1 边界、平均边际效应、条件均值设定检验。触发词：比例、份额、fractional response、fractional logit、beta regression、fracreg、betareg。
compatibility: StataNow 19.5，主路径全部内置。
---

# Stata 分数响应模型

## 强制路径

1. y 是纯二元事件 → `stata-regression` 的 logit；是 alternatives 选择实验 → `stata-dce`。比例不等于二元事件。
2. y 是成功次数/已知试验次数 → 先判断是否需要 grouped-binomial 模型及分母信息；不自动把不同分母的比例等权处理，也不随意加权改变目标总体。
3. y 为 [0,1] 的份额且可含 0/1 → [fractional.md](references/fractional.md) 的 `fracreg` 路径。
4. y 严格在 (0,1) 且 beta 分布可辩护 → 同 reference 的 `betareg`；有边界时不得直接删掉或微调端点凑 beta。
5. 百分数先除以 100，检查量纲与端点；政策识别仍返回对应因果设计 skill。

```stata
version 19.5
```

## 运行 Stata 的方式

`stata-mp -b do "脚本.do"`；Windows 见 `docs/run-stata.md`。图表默认英文，中文需先询问用户。

## 详细参考

[fractional.md](references/fractional.md)：均值链接、边界、Beta、AME、设定检验与报告。

## 关键陷阱速查

1. **把百分数当份额** → 触发：y 为 0–100 → Fix：明确除以 100 → 验证：y 在 [0,1]，报告 AME 时区分份额与百分点。
2. **为 beta 删除边界** → 触发：0/1 导致 beta 报错 → Fix：fracreg 或另建端点机制 → 验证：端点计数与估计样本一致。
3. **系数当百分点** → 触发：直接把 logit-link beta 写成百分比变化 → Fix：`margins` → 验证：连续 x AME 与链接导数的样本均值一致。
4. **误用二元 GOF** → 触发：对连续比例做分类准确率/ROC → Fix：条件均值校准、残差及扩展链接项 Wald 检验 → 验证：报告预测目标，不把份额二分化。
5. **比较不同 outcome/样本的 AIC** → 触发：端点删除后的 beta 与完整 fracreg 排名 → Fix：同目标的预测/均值稳健性 → 验证：共同样本与可比模型假设。

## 可执行禁令

- 禁止对含端点份额直接取 logit(y)；替代：原始 y 上估计 fracreg。
- 禁止把 quasi-likelihood 当 beta 完整似然做常规 LR 排名；替代：同样本均值模型诊断和 AME 对照。
- 禁止声称 robust/cluster SE 解决均值误设或非线性固定效应偏差；替代：区分推断与模型假设。

## 验证与交付

`bash verify/run-verify.sh fractional` 覆盖端点保留、logit/probit、Beta、预测边界、AME 恒等式和均值设定 Wald 检验。报告端点计数、估计样本、链接、VCE、AME 及其单位。
