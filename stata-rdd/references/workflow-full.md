---
name: stata-rdd-workflow-full
description: RDD 完整工作流参考：协变量 covs()、聚类 vce(nncluster/ cluster)、rdrobust 的 _cl 三套输出、rdbwselect 带宽选择器、参数对照模型。主文件见 stata-rdd/SKILL.md。
---

# stata-rdd-workflow-full

> **加载时机**：主 `SKILL.md` 六步强制路径已跑通，需要在主结果上加协变量、聚类、或做完整稳健性（三套输出、多带宽选择器、参数对照）时加载本文件。

> **边界约定**：本文件只补详细签名与工作流。所有陷阱统一收录在主 `SKILL.md` 的「关键陷阱速查」；不重复陷阱条目。

---

## 1. `rdrobust` 的三套输出：`_cl` / 无后缀 / `_r` 语义

`rdrobust` 默认同时输出三套推断，主报告应取 **robust**（`_cl` 后缀）：

| 输出 | 返回名（`e()`） | 含义 |
|---|---|---|
| conventional | `e(tau)` / `e(se_tau)` | 忽视偏误校正，局部多项式常规带宽 |
| bias-corrected | `e(tau_bc)` / `e(se_tau_bc)` | 加偏误项但未做方差修正 |
| **robust** | **`e(tau_cl)` / `e(se_tau_cl)`** | 偏误校正 + 方差修正，**推荐报告** |

### 取数命令

```stata
rdrobust y x, c(c0)
local coef   = e(tau_cl)
local se     = e(se_tau_cl)
local pv     = e(pv_cl)
local ci_l   = e(ci_l_cl)
local ci_r   = e(ci_r_cl)
local h_l    = e(h_l)        // 左侧带宽
local h_r    = e(h_r)        // 右侧带宽
local N_h_l  = e(N_h_l)      // 左侧有效样本
local N_h_r  = e(N_h_r)
```

## 2. 协变量：`covs()` 只提精度，不识别

协变量**不能**识别 RDD（识别靠连续性），只用来缩小方差、提高精度。

```stata
* 主估计（无协变量）
rdrobust y x, c(c0)

* 加协变量（同一带宽下，看 CI 长度变化）
qui rdrobust y x, c(c0)
local len = e(ci_r_cl) - e(ci_l_cl)
rdrobust y x, c(c0) covs(z1 z2 z3)
di "CI length change: " (e(ci_r_cl)-e(ci_l_cl))/`len'*100-100 "%"
```

**平衡检验**：协变量当结果跑 RD（预处理变量 should 不显著）：

```stata
foreach z in z1 z2 z3 {
    rdrobust `z' x, c(c0)
    di "`z' RD: " %9.3f e(tau_cl) "  p=" %6.3f e(pv_cl)
}
```

若某个「协变量」在 cutoff 显著跳跃，说明它实际上被处理影响——**不是好的平衡变量**，可能还是 bad control。

## 3. 聚类：`vce(nncluster)` / `vce(cluster)`

当处理在**集群**水平分配（如班级、州、行政区），标准误必须聚类。

```stata
* 最近邻聚类（匹配运行变量近邻，默认）
rdrobust y x, c(c0) vce(nncluster cluster_var)

* 指定聚类变量
rdrobust y x, c(c0) vce(cluster state)
```

- `nncluster`：K 近邻聚类，通常更合适（处理在阈值附近分配）。
- `cluster var`：直接按变量聚类。
- 聚类数 < 50 时更依赖稳健推断。

## 4. 带宽选择器：`rdbwselect ... , all`

`rdbwselect` 列出一整组数据驱动带宽选择器。主估计默认 `mserd`，稳健性报告 `all`。

```stata
rdbwselect y x, c(c0) all
```

选择器（`bwselect()` 选项）：

| 值 | 全称 | 用途 |
|---|---|---|
| `mserd`（默认） | MSE 最优，方差项经 robust 校正 | 主估计 |
| `msetwo` | 两侧带宽不同（MSE） | 两侧样本不对称时 |
| `cerrd` / `certwo` | coverage-error 最优 | 更窄、更保守 CI |
| `cercomb` | 组合 CE 最优 | 折中 |

**手动指定带宽**：

```stata
* 对称带宽
rdrobust y x, c(c0) h(10)

* 不对称带宽（左 8，右 12）
rdrobust y x, c(c0) h(8 12)
```

**带宽敏感性**（放进主 SKILL 的步骤 5）：

```stata
foreach bw in 5 7 10 15 20 {
    quietly rdrobust y x, c(c0) h(`bw')
    di "`bw'" _col(10) %9.3f e(tau_cl) _col(23) %9.3f e(se_tau_cl) _col(36) %6.3f e(pv_cl)
}
```

## 5. 参数对照模型（低阶，非主结果）

参数模型只做**对照**（尤其是「两侧不同斜率」捕捉斜率差异），不做主估计。Cattaneo 强烈反对全局高阶多项式。

```stata
* 同斜率
reg y x treat, robust

* 不同斜率（交互项）
gen interact = centered * treat
reg y centered treat interact, robust

* 二次（允许两侧）
gen centered2 = centered^2
reg y c.centered##i.treat c.centered2##i.treat, robust

estimates table m1 m2 m3, b(%9.3f) se(%9.3f) stats(r2 N)
```

**解释**：参数全样本估计与 `rdrobust` 局部估计必然不同（scope：全局 vs 局部），不是分歧。若参数模型想更接近 `rdrobust`，就用 `rdrobust` 作为主估计并报告。

## 6. 核函数

`rdrobust` 默认三角核（triangular）。对比核函数的稳健性：

```stata
rdrobust y x, c(c0) kernel(triangular)      // 默认
rdrobust y x, c(c0) kernel(uniform)
rdrobust y x, c(c0) kernel(epanechnikov)
```

三角核通常最优（在局部线性下接近 MSE 最优）；uniform / epanechnikov 做敏感性。

## 参考文献

- Calonico, Cattaneo, Farrell & Titiunik (2017). *rdrobust: Software for Regression Discontinuity Designs.* Stata Journal 17(2): 372–404.
- Calonico, Cattaneo & Titiunik (2014). *Robust Data-Driven Inference in the Regression-Discontinuity Design.* Stata Journal 14(4): 909–946.
- Cattaneo, Idrobo & Titiunik (2020). *A Practical Introduction to RDD: Foundations.* Cambridge Elements.
