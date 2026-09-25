---
name: stata-identification-sensitivity-analysis
description: 未观测混杂 / 遗漏变量偏误的敏感性分析：Oster 比例选择（psacalc）、Cinelli-Hazlett OVB（sensemakr）、Frank ITCV/RIR（konfound）、符号翻转 breakdown（regsensitivity）、E-value（evalue）、Rosenbaum bounds（rbounds）。
---

# 未观测混杂的敏感性分析

本文件是 `identification-common-assumptions.md` 的量化补充：共同假设审计回答「交换性是否可辩护」，本文件回答「如果它被破坏，需要多强的未观测混杂才能推翻结论」。两者都不能把假设变成已证明。

## 1. 先分流：三个不同的问题，三套命令

「敏感性分析」在文献里指三件互不通用的事。选错工具是本节最常见的错误。

| 你在问什么 | 工具族 | 命令 |
|---|---|---|
| ① 回归系数对**遗漏变量**的稳健性 | OVB / 比例选择 | `psacalc`、`sensemakr`、`konfound`、`regsensitivity` |
| ② 因果效应的 **E-value**（需多强混杂才能解释掉） | E-value | `evalue` |
| ③ **匹配设计**的隐藏偏误 | Rosenbaum bounds | `rbounds`（社区另有 `mhbounds` / `sensatt`） |

分流规则：

- 主结果是线性回归 + 连续处理 → ①。
- 主结果是比值尺度（RR / OR / HR）或 SMD → ②。
- 主结果是 PSM / 匹配得到的 ATT → ③。
- DID 的平行趋势偏离 → **踢走**，见 `stata-did` 的 `honestdid`，不是本文件。

## 2. 命令总表

| 命令 | 方法 | 回答什么问题 | 关键返回 | 安装 |
|---|---|---|---|---|
| `psacalc` | Oster (2019) 比例选择 | δ（相对选择程度）与 β*（偏差校正系数） | `r(delta)`、`r(beta)`、`r(rmax)`、`r(type)`、`r(dist)`、`r(altsol1)` | SSC |
| `sensemakr` | Cinelli & Hazlett (2020) OVB | 稳健值 RV、处理-结果 partial R²、benchmark 混杂的界 | `e(rv_q)`、`e(rv_qa)`、`e(r2yd_x)`、`e(treat_coef)`、`e(dof)`（**`e(cmd)` 未设**） | SSC |
| `konfound` | Frank (2000) ITCV + RIR | 推翻结论所需的混杂相关阈值；需替换多少比例样本 | `r(itcv)`、`r(rir)`、`r(thr)`、`r(r_xcv)`、`r(r_ycv)`、`r(RsqXZ)`、`r(RsqYZ)`、`r(unconitcv)` | SSC（另需 `indeplist`、`matsort`、`moss`） |
| `regsensitivity` | Diegert-Masten-Poirier (2022)；含 Oster (2019) 与 Masten-Poirier (2022) | 系数界与**符号/归零 breakdown point** | `e(breakdown)`（**仅 `bounds` 子命令**）、`e(analysis)`、`e(subcmd)`、`e(idset)` | SSC |
| `evalue` | VanderWeele & Ding (2017) | 需多强的 RR 关联才能解释掉效应 | `r(eval_est)`、`r(eval_ci)` | SSC |
| `rbounds` | Rosenbaum bounds | Γ 临界值（**仅 1×1 配对**） | `r(N)`、`r(alpha)`、`r(outmat)`、`r(rvar)` | SSC |
| `mhbounds` | Becker & Caliendo (2007) | Γ + MH 检验统计量 | — | **不在 SSC**，作者页下载 |
| `sensatt` | Ichino-Mealli-Nannicini (2006) | 模拟混杂后的 ATT 分布 | — | SSC（依赖 `pscore` / `attnd` / `attnw` / `atts` / `attk`） |

```stata
ssc install psacalc, replace
ssc install sensemakr, all replace
ssc install konfound, replace
ssc install indeplist, replace
ssc install matsort, replace
ssc install moss, replace
ssc install regsensitivity, replace
ssc install evalue, replace
ssc install rbounds, replace
```

`mhbounds` 不在 SSC 归档（实测 `ssc install mhbounds` 不可用），只由作者在 <http://sobecker.de/stata.html> 发布。

## 3. 语法

本节语法已在本机 StataNow 19.5 MP 实测通过（见 §7 的实测环境与版本）。

```stata
version 19.5

* ---- ① Oster 比例选择：post-estimation 用法 ----
* rmax() 必须是 (R2_controlled, 1] 区间的**字面量**；不接受表达式，也不接受标量名。
* 惯用写法是宏展开，让 rmax 在解析前被替换成数字：
regress y x z1 z2
psacalc delta x, rmax(`=min(1.3 * e(r2), 1)')     // r(delta) r(rmax)
psacalc beta  x, rmax(`=min(1.3 * e(r2), 1)') delta(1)   // r(beta)
* 默认 rmax(1) 也可直接用：psacalc delta x
* stand-alone 形式：psacalc beta x z1 z2, model(regress) rmax(0.99)

* ---- ① Cinelli-Hazlett ----
* benchmark() 可选；benchmark 变量过强时会报 r(3498)，此时去掉该选项。
sensemakr y x z1 z2, treat(x)
sensemakr y x z1 z2, treat(x) benchmark(z1)       // 仅在 benchmark 较弱时可用
* 可选 contourplot / tcontourplot / extremeplot 出图

* ---- ① Frank ITCV / RIR：必须紧接模型，中间不得插入其他命令 ----
regress y x z1 z2
konfound x, indx("IT")      // r(itcv) 等
konfound x, indx("RIR")     // 默认索引；r(rir) r(thr)

* ---- ① 系数界与 breakdown point：必须有 depvar indepvar controls ----
regsensitivity bounds y x z1 z2, oster table        // e(breakdown) e(analysis)
regsensitivity bounds y x z1 z2, table              // dmp（默认）
regsensitivity breakdown y x z1 z2, oster           // 只显示，不存 e(breakdown)
regsensitivity y x z1 z2, noplot                    // 无子命令：默认 DMP + Oster 前沿

* ---- ② E-value ----
evalue rr 1.8, lcl(1.2) ucl(2.7)            // r(eval_est) r(eval_ci)
evalue or 2.1, lcl(1.4) ucl(3.1) common     // 常见结局
evalue hr 1.6, lcl(1.1) ucl(2.3) common
evalue smd 0.35, se(0.10)
evalue rd 4 10 20 30                        // a b c d 四格

* ---- ③ Rosenbaum bounds：输入是配对内的结果差分 ----
gen double delta = y_treated - y_control
rbounds delta, gamma(1 (0.05) 2) alpha(.90)
```

`psacalc` 的 `rmax(#)` 默认 1.0，指「若所有不可观测变量都进入回归时能达到的最大 R²」；Oster 惯例的 `1.3 × R²_controlled` 必须由使用者先算好再传入。`mcontrols(varlist)` 用于「与 x 无关的已观测控制」。

## 4. 必报量

- **`psacalc`**：报 δ 与 β*，并给出 β* 的识别集。δ 是「相对选择程度」，不是显著性；必须同时报告 β* 的符号与区间是否含 0。
- **`sensemakr`**：报 partial R²（处理对结果）与 RV 的两个版本 —— `rv_q`（把点估计打到 0 所需）与 `rv_qa`（打到不再显著所需，必然 ≤ `rv_q`）。RV 用「解释掉处理或结果残差方差的百分比」表述，比 δ 更可解释。
- **`konfound`**：报 ITCV 的相关系数阈值与 RIR 的「需替换的观测比例」。RIR 比 ITCV 更一般。
- **`regsensitivity`**：报 breakdown point。它可能**小于**「归零」点，因此只报 Oster 的 δ 会系统性高估稳健性；用 `oster` 与 `dmp` 两套参数分别报。
- **`evalue`**：报点估计与 CI 限（取更靠近 null 的那侧）两个 E-value。
- **`rbounds`**：报 Γ 临界值（结论开始翻转的 Γ），并说明配对结构。

## 5. 陷阱四件套

1. **`rmax()` 写法错误** → **触发**：写 `rmax(1.3)`（超过 1）、`rmax(1.3*e(r2))`（表达式）或 `rmax(r2max)`（标量名） → **Fix**：`rmax()` 只接受 `(R²_controlled, 1]` 的字面量，用宏展开 `` rmax(`=min(1.3*e(r2),1)') `` → **验证**：日志中 `R_max` 行等于预期值（实测 `0.98720065`），且 `r(rmax)` 非缺失。
2. **`sensemakr` 的 `benchmark()` 过强** → **触发**：用强预测变量作 benchmark，报 `r(3498) Implied bound on r2yz_dx greater than 1` → **Fix**：去掉 `benchmark()`，或改用较弱的 benchmark → **验证**：命令 rc=0 且 `e(rv_q)` 非缺失。
3. **`regsensitivity` 缺 varlist** → **触发**：照抄 `regsensitivity, noplot` 或 `regsensitivity breakdown`，报 `r(100) varlist required` → **Fix**：写成 `regsensitivity bounds depvar indepvar controls, oster|dmp` → **验证**：`e(breakdown)` 非缺失。
4. **`konfound` 中间插了命令** → **触发**：`regress` 与 `konfound` 之间执行了别的命令 → **Fix**：`konfound` 必须紧接模型，中间不得插入任何命令 → **验证**：日志中 `regress` 与 `konfound` 相邻。
5. **只报 δ 不看符号** → **触发**：δ > 1 即宣称结论稳健 → **Fix**：同时报 β* 的识别集，并用 `regsensitivity` 检查符号翻转点 → **验证**：论文同时给出归零点与符号翻转点。
6. **`rbounds` 用在非 1×1 匹配上** → **触发**：核匹配 / 多对一匹配后直接 `rbounds` → **Fix**：改用 `mhbounds` 或 `sensatt`；`rbounds` 只实现 1×1 配对 → **验证**：`r(N)` 等于配对数，论文说明匹配结构与所选 bounds 命令一致。
7. **`mhbounds` 误写 `ssc install`** → **触发**：照抄网上教程 `ssc install mhbounds` → **Fix**：从作者页下载；SSC 无此包 → **验证**：安装步骤与 `help mhbounds` 可得。
8. **把敏感性分析当识别证明** → **触发**：E-value 大或 δ 大即写「已排除未观测混杂」 → **Fix**：只写「需要多强的混杂才能推翻」，属支持性证据 → **验证**：措辞中不出现「证明 / 排除 / 无混杂」。

## 6. 踢走规则

- 平行趋势偏离的量化 → `stata-did`（`honestdid`），不用本文件的工具。
- 动态面板 GMM 的规格敏感性 → `stata-regression` 的 `dynamic-panel.md`。
- 面板 PSM / IPWRA 的匹配质量 → `stata-selection`；本文件只在其后做未观测混杂的量化。
- 需要修复设计本身（重新设计识别策略）→ 回 `identification-decision-tree.md`；敏感性分析不能替代设计。
- 只想报描述或关联 → 不需要敏感性分析，也不需要因果措辞。

## 7. 验证契约

`verify/verify-sensitivity.do` 落地两类证据。

**内置闭式恒等式**（无社区包也成立，进入 `VERIFY_MARKERS_REQUIRED`）：

| 标记 | 内容 | 实测值 |
|---|---|---|
| `OVB_IDENTITY_OK` | `β_short − β_long = β_z × δ̂`（OLS 正交代数恒等式） | 0.37876470 = 0.37876470 |
| `PARTIAL_R2_IDENTITY_OK` | `(R²_full − R²_red)/(1 − R²_red) = t²/(t² + df)` | 0.49166294 = 0.49166294 |
| `EVALUE_CLOSED_FORM_OK` | `E = RR + sqrt(RR(RR−1))`，锚点取自 `evalue` 帮助正文 | 7.26303434 / 3.0 |

**社区包交叉校验**（可选包，未安装时输出 `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__<pkg>__`，不进入必需清单，ADR-0003）：

- `evalue rr 1.8, lcl(1.2) ucl(2.7)` 的点估计与 CI 限必须复现内置闭式（实测 `r(eval_est)=3.0`、`r(eval_ci)=1.68989795`）。
- `sensemakr` 的 `e(r2yd_x)` 必须等于内置 partial R² 恒等式的结果（实测三方一致：`0.49166294`）。
- `psacalc delta`（`rmax=1`）与 `regsensitivity bounds, oster` 的 breakdown point 必须一致——两个独立实现给出同一个 Oster δ（实测均为 `1.08701819`）。
- `psacalc` / `konfound` / `rbounds` 的 stored results 必须非缺失；`rbounds` 另断言 `r(N)` 与 `r(outmat)` 行数。

**实测环境**：StataNow 19.5 MP（Windows），2026-09 本地 SSC 安装：`psacalc` 2.1、`sensemakr` v13、`konfound`（2025-02 版）、`evalue` 1.3.0、`rbounds` 1.1.6、`regsensitivity` 1.2.0。默认模式（未装包）只跑内置恒等式并通过；`--community` 模式不强制可选包。