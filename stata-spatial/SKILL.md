---
name: stata-spatial
description: Stata 空间计量：空间权重矩阵（spmatrix / spmat）、探索性空间自相关（Moran）、横截面空间回归（spregress / spivregress）、空间面板（spxtregress / xsmle / spregdpd / spxtivdfreg）、直接-间接-总效应分解。触发词：空间计量 / spatial econometrics / 空间权重矩阵 / spmatrix / spregress / spxtregress / xsmle / Moran / 空间溢出 / spatial spillover / SAR / SDM / 空间杜宾 / 空间自相关。
compatibility: >-
  适配 Claude Code / Codex / OpenClaw / SkillsMP；StataNow 19.5 MP（macOS / Windows / Linux）。
  内置 sp 命令族（Stata 15+）无需安装；社区包安装见「安装与版本」节，其中两个不在 SSC。
---

# Stata 空间计量

空间计量处理的是**空间依赖**（邻居的结果影响本单位），**不是因果识别**。空间滞后项显著不等于识别成立；它和遗漏变量、反向因果是两类问题。要做因果声明，先过 `stata-identification` 的 stop rules。

Stata 15 起内置了完整的 `sp` 命令族（`spregress` / `spivregress` / `spxtregress` / `spmatrix` 等），这是主路径。社区包只在三处补位：`xsmle`（空间面板 ML 的更多模型形式）、`spxtivdfreg`（含未观测共同因子的空间动态面板）、以及 Pisati 的 `sg162` 遗产工具（ESDA）。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`。平台路径见 `docs/run-stata.md`。
- **中文作图规矩**：需要图形命令（`spmap`、`spregress` 的 `estat impact` 图等）且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 安装与版本

```stata
version 19.5                                    // 本仓库版本政策：首行钉住

* ---- 内置：无需安装 ----
* spset / spshape2dta / spmatrix / spdistance / spgenerate / spbalance / spcompress
* spregress / spivregress / spxtregress（+ estat impact / estat moran）

* ---- 社区：在 SSC，可直接装 ----
ssc install xsmle, replace                      // 空间面板 ML：SAR/SDM/SAC/SEM，FE/RE，静态+动态
ssc install sppack, replace                     // 提供 spmat：另一套权重矩阵工具
ssc install spmap, replace                      // 专题地图
ssc install spregdpd, replace                   // 空间动态面板 GMM-FD

* ---- 社区：不在 SSC，必须换源 ----
net install xtivdfreg, from("http://www.kripfganz.de/stata/") replace
* ↑ 提供 spxtivdfreg（含共同因子的空间动态面板）；`ssc install xtivdfreg` 会失败（见陷阱 2）
net install sg162, from("http://www.stata.com/stb/stb60") replace
* ↑ Pisati 的 spatwmat / spatgsa / spatlsa / spatreg / spatdiag / spatcorr；SSC 无此包（见陷阱 1）
```

## 强制路径

匹配到第一条就停。不要把 `spregress` 的 `gs2sls` 与 `ml`、或 `xsmle` 与 `spxtregress` 全跑一遍当稳健性；只用命中的那条链。

**何时用**：结果变量存在**空间依赖**——邻接单元的同期结果会通过 `W·y`（空间滞后）或通过共同的空间冲击（空间误差）影响本单位；且你能为 **W 的设定**给出实质依据（地理邻接、距离、经济距离、贸易/网络权重）。

**何时踢走**：

- 只是想跑普通回归 / 固定效应 → `stata-regression`。
- 要做因果识别（随机化 / 阈值 / 工具变量 / 面板政策 / 选择） → `stata-identification`；空间模型不解决这些识别问题。
- 处理时点 / 政策错时 → `stata-did` / `stata-did-community`。
- 只想要地图可视化、不做空间回归 → `spmap`（见 `references/spatial-weights.md`）。
- 面板是**短 T 大 N 的动态面板**且没有空间依赖 → `stata-regression` 的动态面板 GMM 段，不要为了「面板」套空间模型。

### 空间计量六步强制路径

| 步骤 | 命令 | 目的 |
|---|---|---|
| 1. 声明空间数据 | `spset id, coord(x y)`（无 shapefile）或 `spshape2dta`（有 shapefile） | 建立 id ↔ 坐标 / 多边形 |
| 2. 构造 W | `spmatrix create idistance W, normalize(row)` 或 `... contiguity W, rook first` | 空间权重矩阵 |
| 3. 自相关诊断 | `regress y x` → `estat moran, errorlag(W)` | 残差是否空间相关（H0: i.i.d.） |
| 4. 主估计 | `spregress y x, gs2sls dvarlag(W)` 或 `..., ml dvarlag(W) errorlag(W)` | SAR / SDM / SEM / SARAR |
| 5. 效应分解 | `estat impact` | 直接 / 间接（溢出）/ 总效应 |
| 6. W 敏感性 | `foreach w in ...` 换 W 规格重跑 | 结论不依赖某一种 W 设定 |

**默认主估计**：`spregress y x, gs2sls dvarlag(W)`——GS2SLS 不依赖误差分布假设，是大样本下的稳健默认。需要 SARAR（同时含空间滞后与空间误差）或做似然比 / 信息准则比较时改用 `ml`。

### 模型形式怎么选

| 设定 | 含义 | 命令 |
|---|---|---|
| SAR（空间滞后） | 邻居的**结果**影响本单位 | `dvarlag(W)` |
| SEM（空间误差） | 未观测的**空间相关冲击** | `errorlag(W)` |
| SDM（空间杜宾） | 邻居的结果 **+ 邻居的协变量** | `dvarlag(W) ivarlag(W: x)` |
| SLX | 只有邻居的协变量 | `ivarlag(W: x)` |
| SARAR / SAC | 同时含空间滞后与空间误差 | `dvarlag(W) errorlag(W)` |

### 空间面板

```stata
* 内置：静态空间面板（FE / RE，ML）
xtset id t
spxtregress y x, fe dvarlag(W)
spxtregress y x, re dvarlag(W) errorlag(W)
estat impact

* 社区：xsmle，模型形式更多（SAR/SDM/SAC/SEM，含 dlag 动态）
xsmle y x, wmat(W) model(sdm) fe type(both) effects
```

**含未观测共同因子时必须换 `spxtivdfreg`**：`xsmle` 与 `spxtregress` 都假设（给定 W 后）截面独立，共同因子违反此假设。Kripfganz & Sarafidis (2025) 的实证中，漏掉共同因子使时间持续参数 ρ 从 0.290 翻到 0.594、Hansen J 检验 p<0.001 拒绝。详见 `references/spatial-panel.md`。

## 详细参考（references/）

主文件保留六步强制路径 + 关键陷阱 + 黑名单。扩展内容按需加载：

| 文件 | 内容 | 何时加载 |
|---|---|---|
| `references/spatial-weights.md` | W 的三种构造路径（内置 `spmatrix`、`spmat`、`sg162` 的 `spatwmat`）、归一化选择、ESDA（Moran / LISA）、`spmap` 出图 | 构造或更换 W、做探索性空间分析、出地图时 |
| `references/spatial-panel.md` | `spxtregress` / `xsmle` / `spregdpd` / `spxtivdfreg` 四者对照、共同因子诊断、短 T 动态空间面板 | 面板数据、含动态项或怀疑共同因子时 |

> **陷阱只在主文件集中维护**，references 不重复——避免漂移。

## 关键陷阱速查

> 统一格式：**陷阱 → 触发 → Fix → 验证**。每条给出可执行修复 + 验证。

1. **`ssc install spatwmat` / `spatgsa` 会失败**
   - **触发**：照抄教程 `ssc install spatwmat`，报 `not found at SSC`（实测 rc=601）。
   - **Fix**：Pisati 全套在 **STB-60 的 `sg162`**，用 `net install sg162, from("http://www.stata.com/stb/stb60")`。
   - **验证**：`which spatwmat` 有输出；`spatgsa` / `spatlsa` / `spatreg` / `spatdiag` / `spatcorr` 同时可用。

2. **`ssc install xtivdfreg` 会失败**
   - **触发**：`ssc install xtivdfreg` 报 `could not copy .../xtivdfreg_p.ado`（实测 rc=679）——SSC 归档缺文件。
   - **Fix**：`net install xtivdfreg, from("http://www.kripfganz.de/stata/") replace`。
   - **验证**：`which spxtivdfreg` 有输出（`spxtivdfreg` 由 `xtivdfreg` 包提供，本身不是独立 SSC 包）。

3. **`estat moran` 挂错估计量**
   - **触发**：`spregress ...` 后跑 `estat moran`，报 `not allowed`（实测 rc=321）。
   - **Fix**：`estat moran` 是 **`regress` 的后估计命令**；先 `regress y x`，再 `estat moran, errorlag(W)`。
   - **验证**：返回 `r(chi2)`、`r(p)`、`r(df)`；选项名是 `errorlag()`，写 `weights()` 会报 `options not allowed`。

4. **`spgenerate` 的星号两侧加了空格**
   - **触发**：`spgenerate wy = W * y`，报 `invalid syntax`（实测 rc=198）。
   - **Fix**：写成 `spgenerate wy = W*y`（语法是 `spmatname*varname`，无空格）；存储类型可省略，也可写 `spgenerate double wy = W*y`。
   - **验证**：`summarize wy` 有非缺失统计量。

5. **把空间系数直接读成溢出效应**
   - **触发**：SAR/SDM 的 `[W]y` 系数被写成「邻居增加 1 单位使本单位增加 β」。
   - **Fix**：`estat impact` 分解直接 / 间接 / 总效应；间接效应才是溢出。
   - **验证**：报告同时给出三者，且 `r(b_direct)`、`r(b_indirect)`、`r(b_total)` 都非缺失。

6. **W 只做一种设定**
   - **触发**：只跑 `spmatrix create contiguity W`（或只用距离矩阵）就下结论。
   - **Fix**：至少对照邻接 / 距离两类，并报告归一化方式（`normalize(row)` 等）。
   - **验证**：符号与显著性在两种 W 下一致；不一致时如实报告为不稳健。

7. **`xsmle` / `spxtregress` 在存在共同因子时被当作正确设定**
   - **触发**：面板有明显的宏观共同冲击，仍只用 ML 空间面板。
   - **Fix**：改用 `spxtivdfreg`；用 J 检验对照含 / 不含共同因子两个规格。
   - **验证**：`spxtivdfreg` 的 J 检验不拒绝，且含因子规格的 ρ 与协变量系数与不含因子规格有实质差异。

8. **`xsmle` / `spxtregress` 用来处理内生回归量**
   - **触发**：协变量内生，却直接放进 `spxtregress` / `xsmle`。
   - **Fix**：横截面用 `spivregress`；面板用 `spxtivdfreg` 的 `iv()` 选项。
   - **验证**：报告说明工具变量来源与过度识别检验。

9. **把空间滞后显著当作因果证据**
   - **触发**：`[W]y` 显著即声称「存在溢出效应，故政策 A 有效」。
   - **Fix**：空间依赖是**描述性结构**，识别仍要靠设计；返回 `stata-identification`。
   - **验证**：论文不出现「空间滞后显著 → 因果溢出」的措辞。

## ❌ Agent 不该做的事（黑名单）

> 与 ADR-0001 联动：本节是「主动反模式」。Agent 在写空间计量 do-file 前必查一遍。

- ❌ **不要用 `ssc install spatwmat` / `sg162`**：**替代**：`net install sg162, from("http://www.stata.com/stb/stb60")`。
- ❌ **不要用 `ssc install xtivdfreg`**：**替代**：从 `http://www.kripfganz.de/stata/` 安装。
- ❌ **不要用 `ssc install spregress` / `spmatrix` / `spxtregress`**：它们是**内置**命令，装了反而冲突。
- ❌ **不要在 `spregress` 之后跑 `estat moran`**：**替代**：先 `regress`，再 `estat moran, errorlag(W)`。
- ❌ **不要在 `spgenerate` 的 `*` 两侧加空格**：**替代**：`spgenerate newvar = W*x`。
- ❌ **不要把空间回归系数直接解释为溢出效应**：**替代**：`estat impact` 取直接 / 间接 / 总效应。
- ❌ **不要只报告一种 W 设定**：**替代**：邻接与距离两类 W 做对照，并说明归一化。
- ❌ **不要用 `xsmle` / `spxtregress` 处理含共同因子的面板**：**替代**：`spxtivdfreg` + J 检验。
- ❌ **不要让空间模型承担因果识别**：**替代**：返回 `stata-identification` 走设计 gate。
- ❌ **不要在短 T 动态面板上直接套静态空间面板**：**替代**：见 `references/spatial-panel.md` 的模型选择表。

## 🔍 错误码速查（错误码 → 触发 → 修复）

> 与上方黑名单互补：黑名单给原则，错误码给精准命中。

- **`r(198)`** — 语法错误。空间场景最常见的是 `spgenerate` 的 `*` 带空格，或 `estat moran` 选项写成 `weights()`。**修复**：按陷阱 3、4 改写法。
- **`r(321)`** — `estat moran not allowed`。**修复**：它是 `regress` 的后估计命令，不是 `spregress` 的。
- **`r(459)`** — `spregress` 报收敛失败（`ml` 专用）。**修复**：换 `gs2sls`；或检查 W 是否退化（孤立点、全零行）、是否与 `dvarlag`/`errorlag` 冲突。
- **`r(111)`** — 命令未找到。**修复**：区分内置（`spregress` 等，未找到说明 Stata < 15）与社区（按陷阱 1、2 装包）。
- **`r(679)`** — 安装时无法复制文件。**修复**：SSC 归档缺文件，换 `net install` 源（见陷阱 2）。
- **`r(601)`** — `ssc describe/install` 找不到包。**修复**：该包不在 SSC（`sg162`、`spxtivdfreg` 是典型），换源。

## 验证

- 本 skill 的完整路径由 `verify/verify-spatial.do` 覆盖，数据为 do-file 内生成的模拟数据（`sim:120x6`）：
  - **内置证据**（进 `VERIFY_MARKERS_REQUIRED`，无社区包也成立）：`spset` + `spmatrix create idistance` + `spregress` 的 `gs2sls` / `ml` + `estat impact` + `estat moran` + `spgenerate`。
  - **可选社区包**（未装则 sentinel，不进入必需清单）：`xsmle`、`spmat`（sppack）、`spmap`、`spregdpd`、`spatwmat`（sg162）、`spxtivdfreg`（xtivdfreg）。
- 运行：`bash verify/run-verify.sh spatial`（默认）/ `... spatial --community`（强制必需包）。
- 社区包契约登记在 `verify/lib/community.sh`，owner 为 `verify-spatial`。

## 参考文献

- **Belotti, F., Hughes, G. & Piano Mortari, A. (2017)** "Spatial Panel-Data Models Using Stata." *Stata Journal* 17(1): 139–180. — `xsmle`。
- **Kripfganz, S. & Sarafidis, V. (2025)** "Estimating Spatial Dynamic Panel Data Models with Unobserved Common Factors in Stata." *Journal of Statistical Software* 113(6). — `spxtivdfreg`。
- **Spinelli, D. (2022)** "Fitting Spatial Autoregressive Logit and Probit Models Using Stata: The `spatbinary` Command." *Stata Journal* 22(2): 292–318. — 空间二值因变量（不在 SSC）。
- **Pisati, M. (2001)** "Tools for Spatial Data Analysis." *Stata Technical Bulletin* 60: 21–37 (sg162). — `spatwmat` / `spatgsa` / `spatlsa` / `spatreg` / `spatdiag` / `spatcorr`。
- **LeSage, J. & Pace, R. K. (2009)** *Introduction to Spatial Econometrics.* CRC Press. — 直接 / 间接效应分解的理论来源。
- **Elhorst, J. P. (2014)** *Spatial Econometrics: From Cross-Sectional Data to Spatial Panels.* Springer.
- 官方手册：*Stata 19 Spatial Autoregressive Models Reference Manual*（`[SP]` 条目），本地 `help sp`。
- 教程：Carlos Mendez, *Spatial Dynamic Panels with Common Factors in Stata.* https://carlos-mendez.org/post/stata_spxtivdfreg/

## ✅ 交付前自检清单（跑完命令后逐条核对）

- [ ] 六步强制路径命中：`spset` → `spmatrix create` → `estat moran` → `spregress` → `estat impact` → W 敏感性；未把工具箱全跑一遍
- [ ] W 的设定有实质依据，且至少做了邻接 / 距离两类对照，报告了归一化方式
- [ ] `estat moran` 是在 `regress` 之后、用 `errorlag()` 跑的，未挂在 `spregress` 后
- [ ] `spgenerate` 写成 `W*x`（无空格）
- [ ] 溢出效应经 `estat impact` 分解，未把 `[W]y` 系数直接当溢出
- [ ] 面板含动态项或共同因子时已改用 `spxtivdfreg`，并报告 J 检验对照
- [ ] 社区包按正确来源安装（`sg162` 与 `xtivdfreg` 未用 `ssc install`）
- [ ] 未用空间模型承担因果识别；需要因果声明时已返回 `stata-identification`
- [ ] log 恰好一次 `end of do-file`，无 `r(错误码)`（r(198)/r(321)/r(459) 已排查）