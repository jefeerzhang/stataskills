---
name: stata-spatial-weights
description: 空间权重矩阵 W 的构造与探索性空间分析：spmatrix create（contiguity / idistance）、spmat（sppack）、sg162 的 spatwmat / spatgsa / spatlsa、Moran 检验与 spmap 出图。
---

# 空间权重矩阵与探索性空间分析

W 是空间计量的**唯一最重要的设定**：它定义「谁是谁的邻居」。换一个 W，系数与显著性都可能变。本文件覆盖 W 的构造、归一化、质量检查，以及探索性空间自相关（ESDA）。

## 1. 先声明空间数据

```stata
version 19.5

* 有坐标（无 shapefile）
spset id, coord(xcoord ycoord)

* 有 shapefile：spshape2dta 会生成「数据」与「坐标」两个文件
spshape2dta "china_province.shp", saving(china_province) replace
use china_province.dta, clear
```

`spset` 之后才能用 `spmatrix` / `spregress` / `spgenerate`。`spset` 无参数时显示当前设定。

## 2. W 的三种构造路径

### 2.1 内置 `spmatrix create`（主路径）

```stata
* 邻接（contiguity）：需要多边形；rook 只算共边，不含仅共顶点
spmatrix create contiguity Wc, rook first
spmatrix create contiguity Wc2, rook second(2)      // 二阶邻居

* 距离（idistance）：需要坐标；通常行标准化
spmatrix create idistance Wd, normalize(row)

* 从外部文件读入自定义 W（如经济距离、贸易权重）
spmatrix import Wcustom using "W.csv", replace
spmatrix create idistance ...
```

`spmatrix` 的常用子命令：`create` / `import` / `export` / `save` / `use` / `fromdata` / `normalize` / `summarize` / `copy` / `drop`。`spmatrix userdefined` 用于完全自定义的权重。

**归一化**：`normalize(row)` 使每行和为 1，是主流做法（间接效应的解释更干净）；不归一化时权重绝对值会进入系数尺度。`normalize(none)` 保持原值。归一化方式必须写进论文。

### 2.2 `spmat`（sppack，SSC）

```stata
ssc install sppack, replace

spmat contiguity Wc using "coords.dta", id(id) norm(row)
spmat idistance Wd LON LAT, id(id) norm(row)
spmat summarize Wd, links detail
spmat eigenvalues Wd
spmat save Wd using "wd.spmat"
spmat export Wd using "wd.txt"
```

`sppack` 的 `spmat` 与内置 `spmatrix` 是**两套互不兼容的对象**：`spmat` 生成的矩阵不能被 `spregress` 直接使用，反之亦然。选一条路径走到底，不要混用。

### 2.3 `spatwmat`（sg162，遗产路径）

```stata
net install sg162, from("http://www.stata.com/stb/stb60") replace

* 由坐标构造（band 给出距离带；bin 生成二元邻接）
spatwmat, name(W) xcoord(lon) ycoord(lat) band(0 3)
spatwmat, name(Wbin) xcoord(lon) ycoord(lat) band(0 1) bin
spatwmat, name(W) xcoord(lon) ycoord(lat) band(0 3) stand

* 读入外部矩阵
spatwmat using "altweights.dta", name(W)
```

`spatwmat` 生成的是普通 Stata 矩阵，只供 `sg162` 自己的 `spatgsa` / `spatreg` 使用，**不能**喂给 `spregress`。仅在复现旧文献或使用 Pisati 全套时走这条路。

> `ssc install spatwmat` **不可用**（实测 `not found at SSC`）；必须用上面的 `net install sg162`。

## 3. W 的质量检查

```stata
spmatrix summarize W, links detail      // 每行平均邻居数、孤立点
```

- **孤立点**（某行全为 0）会让空间滞后无定义，估计报错或产生偏误。必须检查并处理（剔除或改用 k 近邻）。
- **邻居数过多**（如距离阈值过宽）会让 W 接近全连接，空间参数失去意义。
- **W 的对照**：至少跑邻接与距离两类；符号与显著性一致才谈稳健。

## 4. 探索性空间自相关（ESDA）

### 4.1 全局 Moran（内置，挂在 `regress` 后）

```stata
regress y x
estat moran, errorlag(W)
```

返回 `r(chi2)`、`r(p)`、`r(df)`、`r(elmat)`。H0 是残差 i.i.d.；**不拒绝不等于没有空间相关**，只表示当前 W 下未发现。

⚠️ `estat moran` 是 **`regress` 的后估计命令**，不是 `spregress` 的。挂在 `spregress` 后会报 `estat moran not allowed`（实测 rc=321）。选项名是 `errorlag()`，不是 `weights()`。

### 4.2 全局与局部自相关（sg162）

```stata
spatgsa y, weights(W) moran          // 全局 Moran
spatgsa y, weights(W) geary          // 全局 Geary
spatgsa y, weights(W) moran go         // 全局 + 局部
spatlsa y, weights(W) moran            // 局部 Moran（LISA）
spatlsa y, weights(W) moran graph(moran)   // Moran 散点图
spatcorr y, weights(W)                 // 空间相关图
```

`spatgsa` / `spatlsa` 的输入是 `spatwmat` 生成的普通矩阵，不是 `spmatrix` 对象。

### 4.3 内置的 Moran 散点图与空间滞后

```stata
spgenerate wy = W*y                  // 注意：* 两侧不能有空格
spmatrix summarize W
twoway scatter wy y, msize(small)     // Moran 散点图的等价画法
```

## 5. 地图出图（`spmap`）

```stata
ssc install spmap, replace
ssc install shp2dta, replace         // 老式 shapefile 转换（spshape2dta 已内置，二者择一）

spmap y using "china_map.dta", id(id) fcolor(Blues) clmethod(quantile) clnumber(5)
```

`spmap` 只负责**画图**，不做估计。它需要「数据 + 坐标」两个文件，可由内置 `spshape2dta` 生成。中文标签作图前先询问用户（见主文件「运行 Stata 的方式」）。

## 6. 陷阱

1. **`spmat` 与 `spmatrix` 混用** → 触发：用 `spmat` 造 W 后直接 `spregress ..., dvarlag(W)` → Fix：二者对象不兼容，选定一条路径 → 验证：`spmatrix summarize` 只对 `spmatrix` 对象有效。
2. **孤立点未处理** → 触发：`spmatrix summarize` 显示 links 最小值为 0 → Fix：剔除或改 k 近邻 → 验证：每行邻居数 > 0。
3. **W 未归一化却按归一化解释** → 触发：不写 `normalize()` 就报告「邻居平均效应」 → Fix：显式归一化并写入论文 → 验证：`spmatrix summarize` 显示 Row-standardized: Yes。
4. **`estat moran` 挂在 `spregress` 后** → 见主文件陷阱 3。

## 7. 踢走

- 只想做空间回归 → 回主文件走六步强制路径。
- 想用 W 做因果识别（如「地理边界断点」） → 那是 `stata-rdd`；W 不是识别工具。
- 面板 W 不随时间变化而研究期很长 → 需说明「W 时不变」假设的合理性；否则考虑时变 W。