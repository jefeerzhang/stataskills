# DCE 参考路径

## 数据布局与 `cmset`

使用 long format：`respondent task alternative chosen price quality`。一次 choice task 的 case id 是 `respondent task`，alternative 是方案编号。单次任务可写：

```stata
cmset caseid alternative
```

重复选择可写：

```stata
cmset respondent task alternative
```

先验证 `isid respondent task alternative`、每个 case 的 alternative 数量，以及 `bysort respondent task: egen nchosen=total(chosen)` 后 `assert nchosen==1`。

## Conditional logit

```stata
cmclogit chosen price quality, vce(cluster respondent)
```

alternative-specific attributes 进入主 varlist；case-specific covariates 用 `casevars()`，避免把不随 alternative 变化的变量误当作 alternative attribute。报告效用系数、VCE、base alternative 与样本结构。

## Mixed logit 与 panel mixed logit

```stata
cmmixlogit chosen price, random(quality) ///
    intmethod(random) intpoints(20) intseed(20260910) ///
    vce(cluster respondent)
```

随机参数分布必须有理论依据；增加 integration points 或更换 seed 做数值稳定性检查。重复 choice task 使用 `cmxtmixlogit` 的 panel 设定，或至少按 respondent 聚类；不能把一个 respondent 的多个选择当独立个体。

## WTP

Preference-space 中：`WTP_quality = -_b[quality] / _b[price]`。可用 `nlcom` 做一阶 delta-method；分布偏斜、价格系数不稳定或 mixed logit 下更建议 respondent bootstrap / simulation。价格系数接近 0、符号与支付含义冲突或存在大量 protest responses 时，不应机械给出 WTP 点估计。

## 社区工具链与潜在类别

`clogit`、`wtp`、`mixlogit`/`mixlpred` 和 `lclogit`/`lclogitpr` 的核实来源、安装依赖、五类别模板与概率检验统一见 [community.md](community.md)。`probcalc` 只计算常见统计分布，不能用于 DCE 选择概率预测；这些社区命令不依赖 `cmset`，但仍须检查 choice-set 结构。

## IIA 与模型诊断

IIA 是 conditional logit 的结构假设。Hausman-McFadden 类检验可能受替代方案删除、非正定 VCE 与样本变化影响；不把一个 p 值当唯一判据。应同时报告替代方案设计是否合理、conditional logit 与 mixed/panel mixed logit 的系数和预测选择概率是否稳健。

诊断至少覆盖：choice-set 完整性、chosen 唯一性、价格符号、随机系数标准差/分布、integration method/points/seed、按 respondent 的推断，以及必要时的 latent-class 或 WTP-space 敏感性规格。

## 社区与 GitHub 兼容路径

官方 `cm*` 与社区命令按模型和复现需求选择。GitHub 示例用于补充研究思路；安装入口与参数语法以 SSC 作者帮助文件为准，见 [community.md](community.md) 的核实来源。
