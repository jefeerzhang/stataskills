# 有限因变量工作流

## 1. 先分清机制

| 机制 | 数据中看见什么 | 路径 |
|---|---|---|
| 删失 | 样本仍在，但超出界限只记录界限值 | `tobit` |
| 真实零 | 零是经济行为的实际结果，正值过程另有机制 | 两部模型 / `churdle` |
| 样本选择 | selected 可观测，结果仅在 selected=1 时可见 | `heckman` / `heckprobit` |
| 截断 | 界外单位不在数据中 | 不直接套 Tobit；另核验截断模型 |
| 区间观测 | 只知结果所在区间 | 另核验区间回归 |

Heckman 的 outcome 在未选中时是不可观测，不必在经济意义上等于零。保留未选中者的 x/z/selected，核对共同样本；如果这些人整个不存在于文件，不能直接运行本路径。

## 2. Tobit 与边际效应

```stata
tobit censored c.x, ll(0) vce(robust)
predict double observed_mean, ystar(0,.)
predict double positive_mean, e(0,.)
predict double positive_prob, pr(0,.)
margins, dydx(x) predict(ystar(0,.))
margins, dydx(x) predict(pr(0,.))
```

下界为零、无上界时，observed_mean=positive_prob*positive_mean。beta 描述潜在结果线性指数，不等于 E(observed y|x) 的 AME。若上下界不同必须相应修改预测目标；不能沿用这个零下界乘积公式。

记录删失占比、上下界依据、潜在误差正态性与同方差假设，检查拟合零比例、观测尺度残差/均值、极端预测与敏感性。观测结果有边界质量点，不应机械对它做正态检验判断 Tobit。robust VCE 不能修复正态/方差或删失机制误设；不提供“单一检验通过即可”的结论。

## 3. Cragg hurdle 与两部模型

```stata
churdle exponential spending c.x, select(x z) ll(0) vce(robust)
predict double hurdle_mean, ystar
margins, dydx(x) predict(ystar)
```

这里 `select(x z)` 填解释变量，与 Heckman 的 `select(selected = x z)` 语法不同。Cragg 允许参与与正值强度的系数不同；指数模型适配正的偏斜强度。检查两个过程的拟合、正值尾部、边界、收敛与整体均值。它不等于一般的相关误差样本选择模型。

另一个实际两部实现：

```stata
logit participates c.x c.z, vce(robust)
predict double participation_prob, pr
glm spending c.x if participates, family(gamma) link(log) vce(robust)
predict double positive_spend, mu
gen double two_part_mean = participation_prob*positive_spend
```

`participates` 表示 spending>0，而非“结果是否被观测”。Gamma 部分只能使用严格正值。这里刻意给所有协变量完整的单位预测条件正值均值，然后乘参与概率，得到总体期望；只报告正值子样本的第二部系数不回答总体支出效应。整体 AME/CI 需传播两部估计不确定性，按受访者/cluster 重抽并每次重估两部，不能仅乘上第二部标准误。当前脚本验证整体均值计算，不声称已验证两部联合 bootstrap 区间。

## 4. Heckman 连续结果

```stata
heckman outcome c.x, select(selected = c.x c.z) vce(robust)
test [selected]z
test /athrho = 0
predict double selected_mean, ycond
predict double population_mean, xb
margins, dydx(x) predict(ycond)
heckman outcome c.x, select(selected = c.x c.z) twostep
```

z 仅进入选择方程，必须有不直接影响 outcome 的实质论证；显著性只关乎选择相关性，不证明排除有效。`test [selected]z` 的方程名来自选择指标名，以 `e(b)`/coeflegend 核对。`test /athrho=0` 是 ML 规格下独立方程的 Wald 检验；rho=0 与 athrho=0 等价，但不能直接对变换后点估计乱写系数名。

`ycond` 是给定 selected=1 的条件结果均值，`xb` 是模型隐含的总体结果均值线性部分，两者不要混报。检查选择方程预测支持、弱排除变量、rho 接近 +/-1、收敛和误差分布敏感性。两步法与 ML 的分布依赖/推断不同；两步不用常规 ML AIC/LR，不能把普通 OLS 的标准误用于生成的 IMR。

## 5. 二元样本选择

```stata
heckprobit binary_outcome c.x, select(selected = c.x c.z) vce(robust)
test /athrho = 0
predict double p_joint, p11
predict double p_select, psel
predict double p_cond, pcond
margins, dydx(x) predict(pcond)
```

`p11` 是 outcome=1 且 selected=1 的联合概率，`psel` 是被选概率，`pcond` 是被选条件下 outcome=1 的概率；应满足 p11=psel*pcond。总体 outcome 概率与这个条件概率不同。共同二元正态误差假设和选择排除变量仍需论证；不能把 observed-only probit 对照差异全归因于选择偏误。

## 6. 来源与验证

[Tobit](https://www.stata.com/manuals/rtobit.pdf)、[Cragg hurdle](https://www.stata.com/manuals/rchurdle.pdf)、[Heckman](https://www.stata.com/manuals/rheckman.pdf)、[heckprobit](https://www.stata.com/manuals/rheckprobit.pdf)，以本机 StataNow 19.5 help 和实测日志锁定语法。

`verify/verify-limited-dependent.do` 使用固定 seed、已知测量与选择机制的模拟样本，验证命令和估计目标的恒等式；不以一次模拟显著性证明模型正确，也不宣称未经验证的真实数据识别。
