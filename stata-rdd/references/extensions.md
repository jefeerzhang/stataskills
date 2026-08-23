---
name: stata-rdd-extensions
description: RDD 扩展方法浓缩：rdlocrand（离散分数/局部随机化）、rdmulti（多 cutoff/多 score）、rd2d（地理边界）、rdpower（功效）。主文件见 stata-rdd/SKILL.md。
---

# stata-rdd-extensions

> **加载时机**：主 `SKILL.md` 强制路径已读完，遇到「运行变量只有少数离散值（mass points）」「多个 cutoff」「地理/行政区边界」「wanting power 计算」时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流。所有陷阱统一收录在主 `SKILL.md` 的「关键陷阱速查」；不重复陷阱条目。

> **这些方法不作为主决策路径**。主路径只用 sharp + fuzzy + 密度检验 + placebo + 敏感性。本文件是「遇到更复杂设计」时的延伸，不是默认。

---

## 1. `rdlocrand`：离散运行变量 / 局部随机化

当运行变量只有少数取值（如年龄按整数岁、分数取整数），「连续性」框架变弱——rdrobust 的局部多项式假设分数在 cutoff 附近连续，但 mass points 会破坏它。**局部随机化**把 cutoff 附近窗口内的观测当作近似随机分配，用随机化推断（randomization inference）。

### 安装

```stata
ssc install rdlocrand, replace
```

### 核心命令

```stata
* 选窗口：数据驱动地找一个"处理近似随机"的窗口
rdwinselect y x, c(c0) wmin(n) wmax(m)

* 用选定窗口做随机化推断
rdrandinf y x, c(c0) wl(a) wr(b)

* 对窗口长度和零假设做敏感性
rdsensitivity y x, c(c0) wl(a) wr(b)
```

### 何时用

- 运行变量只有少数离散值（mass points）→ `rdwinselect` + `rdrandinf`。
- 截断样本、小样本、或想避开连续性假设 → 局部随机化更可信。
- **不要**：把连续性假设强套在有 mass points 的数据上。

### 关键点

`rdrandinf` 给出随机化 p 值与 window 内的处理效应估计。窗口必须预先/数据驱动选定，不要事后挑一个让结果显著的窗口。

---

## 2. `rdmulti`：多个 cutoff / 多个 score

### 安装

```stata
ssc install rdmulti, replace
```

### 核心命令

```stata
* 多 cutoff：pooled + 每个 cutoff 各自效应
rdmc y x, c(c1 c2 c3)

* 多 cutoff 图
rdmcplot y x, c(c1 c2 c3)

* 多 score（cumulative cutoffs；一个单元可能跨多个 cutoff）
rdms y x, c(c1 c2 c3)
```

### 何时用

- 一个阈值规则用在多个地点/时间（如多省同一分数线）→ 用全部 cutoff 提高功率，`rdmc` 给出 pooled + 各自效应。
- 多个累积 cutoff（如不同年级不同分数线）→ `rdms`（multi-score）。
- 需要多 cutoff 图 → `rdmcplot`。

### 关键点

`rdmc` 默认 pooling 所有 cutoff 到一个 RD 效应；要各自效应看单个 cutoff 列。`rdms` 处理一个单元可能同时跨两个 cutoff 的设计（如分数到不同档位对应不同处理强度）。

---

## 3. `rd2d`：地理 / 边界断点

### 安装

```stata
net install rd2d, from("https://raw.githubusercontent.com/rdpackages/rd2d/main/stata") replace
```

### 核心命令

```stata
* 地理边界 RD：运行变量是到边界的距离
rd2d y dist, c(0)
```

### 何时用

- 处理在**行政区边界**两侧不同（如不同省份同一政策不同），running variable = 到边界的距离。
- **不要**：把地理边界当线性 RDD 跑 `rdrobust`——`rd2d` 专门处理二维空间数据 & 边界。

### 关键点

地理边界 RDD 的识别关键是「边界附近的观测可比」；距离要外生、政策只在边界一侧。与时间断点一样，这是 RDD 的延伸，不是标准一维运行变量。

---

## 4. `rdpower`：功效 / 样本量 / 最小可检测效应

### 安装

```stata
ssc install rdpower, replace
```

### 核心命令

```stata
* 给定真实效应，算 power
rdpower tau, c(c0)

* 给定 power，算所需样本量
rdsampsi tau, c(c0) power(0.9)

* 最小可检测效应
rdmde, c(c0) rho(1) power(0.9)
```

### 何时用

- 研究设计阶段：预估 cutoff 处的离散度与样本，算「这个设计有没有 power」。
- 论文里报告「在给定窗口 MDE = X」——审稿人常问。

### 关键点

`rdpower` 的 `tau` 是你在 cutoff 处假设的真实效应。**不要**用事后估计的效应算 power（那是 post-hoc power 谬误）；用研究设计的计划效应。

---

## 参考文献（本文件）

- Cattaneo, Titiunik & Vazquez-Bare (2016). *Local Randomization RD.* Stata Journal. — `rdlocrand`。
- Cattaneo, Titiunik & Vazquez-Bare (2020). *Analysis of Regression-Discontinuity Designs with Multiple Cutoffs or Multiple Scores.* Stata Journal. — `rdmulti`。
- Cattaneo, Titiunik & Yu (2026). *Boundary Discontinuity Designs.* — `rd2d`。
- Cattaneo, Titiunik & Vazquez-Bare (2019). *Power Calculations for Regression-Discontinuity Designs.* Stata Journal. — `rdpower`。
