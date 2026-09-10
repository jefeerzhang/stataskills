# DCE 社区命令：来源、估计与预测

## 1. 已核实的发布来源

2026-09-10 已从 SSC 安装并读取本机帮助文件：

| 包 | 发布来源与作者 | 职责 |
|---|---|---|
| `wtp` | [SSC/RePEc S456808](https://ideas.repec.org/c/boc/bocode/s456808.html)，Arne Risa Hole；ado 1.0.2 | 比值型 WTP 的 delta、Fieller、Krinsky–Robb 区间 |
| `mixlogit` | [SSC package](http://fmwww.bc.edu/repec/bocode/m/mixlogit.pkg)，Arne Risa Hole；ado 1.4.0 | 最大模拟似然 mixed logit；附 `mixlpred` 选择概率预测 |
| `probcalc` | [SSC/RePEc S457344](https://ideas.repec.org/c/boc/bocode/s457344.html)，Leif E. Peterson | 二项、泊松、正态分布计算器，**不是 DCE 选择概率预测命令** |
| `lclogit` | [SSC/RePEc S457313](https://ideas.repec.org/c/boc/bocode/s457313.html)，Daniele Pacifico、Hong Il Yoo；ado 2.11 | EM 潜在类别 conditional logit；附 `lclogitpr` |

`findit wtp`、`findit probcalc` 是查找入口，不会自动安装，也不是模型命令。安装命令为 `ssc install wtp, replace`、`ssc install mixlogit, replace`、`ssc install probcalc, replace`、`ssc install lclogit, replace`。`membership()` 还需要 `ssc install fmlogit, replace`。可通过 `which` 和 `help` 核对当前安装版本。包发布较早不意味着命令只适用于旧版 Stata。

## 2. `clogit` 与 WTP

`clogit` 是有效的内置 conditional-logit 入口，无需 `cmset`。`group(grid)` 的 grid 必须跨受访者唯一标识一次选择任务，不能只放每人重复的 task=1,2,...。每人多次选择时按 `resp_id` 聚类。与默认包含 alternative constants 的 `cmclogit` 比较时，须对齐常数项与属性编码。

```stata
clogit selected price color_black, group(grid) vce(cluster resp_id)
wtp price color_black, delta
wtp price color_black, fieller
wtp price color_black, krinsky reps(1000) seed(1234)
```

`wtp` 第一项是成本分母，之后才是属性。`r(wtp)` 三行依次为估计值、下界、上界。多方程模型使用 `equation(choice1)` 等实际方程名。Krinsky–Robb 是基于系数与 VCE 的参数模拟，不是重抽受访者的非参数 bootstrap。价格系数接近零时 Fieller 区间可能无界，不能强行写成稳定 WTP；若随机价格跨零，比值分布尤其需要检查。

## 3. `mixlogit` 与预测

```stata
mixlogit selected price, group(grid) id(resp_id) rand(color_black) nrep(100)
mixlpred double mixed_pr, nrep(100)
```

`id()` 让同一受访者的选择序列共享随机偏好，不能用 clustered SE 代替该似然结构。固定系数变量放主 varlist，随机系数变量只放 `rand()`。`nrep()` 是 Halton draws；100 仅为验证规模，实证分析增加 draws 并检验数值稳定性。预测检查每个 choice set 中概率位于 [0,1] 且加总为 1。

## 4. 用户五类别模型

以下保留用户的变量映射；实际数据执行前先检查唯一键、缺失值、每组恰好一个 selected=1、属性基准水平，以及 `none` 是否为 opt-out 常数。opt-out 的属性编码要和效用定义一致。

```stata
lclogit selected storage4gb storage8gb screen_size6 screen_size7 ///
    color_silver color_black price none, group(grid) id(resp_id) ///
    ncl(5) seed(1234) membership(male age income)
```

`ncl(5)` 是 `nclasses(5)` 的合法缩写。`male age income` 必须在同一受访者全部 alternatives 和 tasks 间保持不变。不要先验认定五类最优：比较候选类别数的 AIC/BIC/CAIC、多个随机起点的 log likelihood、极小类别与可解释性。EM 达到迭代上限不等于收敛，单个 seed 不能证明全局最优；跨次拟合的类别编号可能置换。

## 5. 四种概率的精确定义

```stata
lclogitpr double Pr0, pr0
lclogitpr double PrC, pr
lclogitpr double H, up
lclogitpr double G, cp
```

| 选项 | 生成变量 | 含义与核验 |
|---|---|---|
| `pr0` | `Pr0` | 按先验 H 加权的总体选择概率；每个 choice set 加总为 1 |
| `pr` | `PrC` 及 `PrC1`–`PrC5` | 同时生成总体概率和各类条件选择概率；每一列按 choice set 加总为 1 |
| `up` | `H1`–`H5` | membership 模型给出的先验类别概率；每行跨类别和为 1，同一人不变 |
| `cp` | `G1`–`G5` | 用整个人的已观察选择序列更新的后验类别概率；每行跨类别和为 1，同一人不变 |

还应核验 `Pr0 = sum_c(Hc * PrCc)`。总体预测不应偷偷改为用后验 G 加权，否则使用了待预测选择的信息。`sum Pr0*` / `sum PrC*` 可做初查；汇总 H/G 或个体参数时先用 `egen person_tag = tag(resp_id)`，再 `summarize ... if person_tag`，避免任务较多的受访者权重偏大。

## 6. 后验加权参数与 WTP

用户的 `[choice1]price` 是 Stata 合法系数引用，并非仅概念写法。推荐显式 `_b[choice1:price]`，用 `matrix list e(b)` 核对方程名。修复用户消息中断开的 `///` 续行后，五类完整表达式为：

```stata
gen double b_price = _b[choice1:price]*G1 + _b[choice2:price]*G2 + ///
    _b[choice3:price]*G3 + _b[choice4:price]*G4 + _b[choice5:price]*G5
gen double b_color_black = _b[choice1:color_black]*G1 + ///
    _b[choice2:color_black]*G2 + _b[choice3:color_black]*G3 + ///
    _b[choice4:color_black]*G4 + _b[choice5:color_black]*G5
```

这是给定拟合模型与选择记录的后验平均偏好，不是分别为每个人重新估计参数。特别注意：`-sum(Gc*b_color_c)/sum(Gc*b_price_c)` 一般不等于 `sum(Gc*(-b_color_c/b_price_c))`。前者是平均系数的比值，后者是类别 WTP 的后验平均，必须按研究目标选择。

原始 `lclogit` EM 输出不提供通常的估计量 VCE；不能直接接 `wtp`/`nlcom` 宣称已有有效区间。作者提供 `lclogitml` 经 `gllamm` 获取 VCE，或按受访者重抽、每次重新拟合 membership 和类别模型；类别标签需对齐。当前验证不覆盖 `gllamm` 推断路径。

## 7. 验证范围

`verify/verify-dce.do` 验证 `clogit`、三种 `wtp` 区间、`mixlogit`/`mixlpred`、两类别 `lclogit` + `membership()`、四类概率的归一化/个体内一致性/先验加权恒等式、两种系数引用与后验加权。五类别手机属性模型是用户数据模板，未在缺失的真实数据上估计；两类别 fixture 用于验证命令契约。

`probcalc b 10 0.5 exactly 5` 的分布计算另作 smoke check，不纳入 DCE 概率结果。所有社区包缺失时显示 optional sentinel；包存在则必须真实运行并通过断言。
