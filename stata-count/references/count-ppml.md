# 计数与 PPML 工作流

## 1. 数据与估计对象

计数 y 是非负整数；PPML 只要求非负结果与正确指定的指数条件均值等条件，不要求结果真服从 Poisson，也不要求是整数。记录单位、零值、观测窗口、聚类单位和缺失处理。不能把均值模型本身称为因果识别。

## 2. Poisson、exposure 与 NB

变量为教学占位符；完整可执行 DGP 见 `verify/verify-count.do`。

```stata
poisson y c.x, exposure(exposure) vce(cluster id)
predict double mean_count, n
predict double rate, ir
margins, dydx(x) predict(n)
test x
```

模型为 E(y|x)=exposure*exp(xb)，exposure 必须严格正且不缺失。`exposure(exposure)` 等价于先生成自然对数再 `offset(log_exposure)`，offset 的系数固定为 1。`predict ..., n` 是当前窗口的次数，`ir` 是单位 exposure 的率。exp(beta) 为相同 exposure 下的率比；连续 x 的有限单位变化在对数均值上解释。

```stata
nbreg y_over c.x, exposure(exposure) vce(cluster id)
predict double nb_mean, n
margins, dydx(x) predict(n)
```

默认 NB2 对条件方差作额外参数化。报告 alpha 与不确定性；样本方差大于样本均值不是条件过度离散的充分证据。Poisson `estat gof` 的 Pearson/deviance 检查以相应分布假设为前提，cluster/非整数 PPML 不应机械使用其卡方 p 值。查看残差与 x、拟合值和 exposure 的系统关系；稳健 VCE 不修复均值误设。

## 3. 零膨胀

```stata
zip y_zero c.x, inflate(z) exposure(exposure) vce(cluster id)
predict double zip_p0, pr(0)
margins, dydx(x) predict(n)
zinb y_zero c.x, inflate(z) exposure(exposure) vce(cluster id)
predict double zinb_p0, pr(0)
estat ic
```

`inflate()` 描述结构零概率，计数过程也可能产生零。正的 inflation 系数通常增加结构零倾向，与 count 方程方向不同。检查零值预测、均值预测、收敛、极端系数与标准误。AIC/BIC 仅在相同 outcome、相同样本、可比完整似然下解释；不要把非整数 PPML 的伪似然当计数分布证据。Hurdle 把零/正过程分开，与零膨胀不同；连续结果 hurdle 见 `stata-limited-dependent`，离散 hurdle 需另核验截断计数命令。

## 4. 高维固定效应 PPML

[作者 GitHub](https://github.com/sergiocorreia/ppmlhdfe)、[官方包帮助](https://scorreia.com/help/ppmlhdfe.html)。2026-09-10 从 SSC 安装的 `ppmlhdfe` 为 2.3.3，依赖 `ftools` 和 `reghdfe`。逐个 `ssc install`，通过 `which` 记录版本；验证脚本不自动联网安装。

```stata
ppmlhdfe value c.x, absorb(id t) vce(cluster id) d(fe_sum)
predict double ppml_mu if e(sample), mu
```

`d(fe_sum)` 保存用于预测的 FE 总和。不要省略它后再误用不含 FE 的线性预测。检查 separation、singletons、全零 FE 组、共线性、e(sample)、迭代收敛与容差敏感性；不要盲目关闭分离检测或强留被剔除观测。样本剔除后目标总体可能变化，比较模型必须对齐共同样本。

可用相同 FE 的 `poisson value c.x i.id i.t, vce(cluster id)` 作小样本计算对照；这不是大规模分析的推荐实现。对含非整数结果只解释均值，不把预测 Poisson 概率当真实结果分布。多维 FE 能控制特定异质性，不能自动解决内生性。

## 5. 检验与报告清单

- 数据 gate：y 非负、计数模式才要求整数；exposure 正；缺失与真实零分开。
- 设定：Poisson/NB/ZI 的数据机制、链接与 exposure；HDFE 的 FE 和聚类层级。
- 拟合：条件过度离散、Pearson/deviance 的适用前提、观察/预测零比例、残差结构。
- 数值：收敛、分离、极端系数、被剔除样本与共同样本比较。
- 结果：系数/IRR 与原尺度 AME 区分，置信区间、样本量、单位和限制同时给出。

Stata 内置依据：[Poisson](https://www.stata.com/manuals/rpoisson.pdf)、[NB](https://www.stata.com/manuals/rnbreg.pdf)、[ZIP](https://www.stata.com/manuals/rzip.pdf)、[ZINB](https://www.stata.com/manuals/rzinb.pdf)，以本机 19.5 help 和验证日志为语法证据。
