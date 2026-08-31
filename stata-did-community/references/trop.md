---
name: stata-did-community-trop
description: Triply Robust Panel Estimator (TROP) — Athey-Imbens-Qu-Viviano 2025。
高维共同因子 + 处理与因子相关场景；Stata 包 trop。详细签名见主 SKILL.md 决策树第 17 条。
---

# stata-did-community-trop

> **加载时机**：主 SKILL.md 决策树已读完，遇到"高维共同因子（单元 FE 不能充分吸收）+ 处理与潜在因子相关"或"想用 semiparametric efficiency"场景时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 何时用（数据特征 → 估计量）

TROP 不是"什么情况都能用"的万能估计量——它针对的是其他错时 DID 估计量
（`csdid` / `jwdid` / `did_imputation`）难以覆盖的场景：

- **高维未观测共同因子**：协变量 / 单元 FE 不能充分控制的潜在因子（NAICS × year、行业-地区结构）。
- **处理选择与因子相关**：处理不是"准随机"的，与潜在因子相关（endogenous treatment selection）。
- **想用 semiparametric efficiency**（不是必需——是希望）：异质性处理效应 + 缺失数据机制下追求 efficient 估计。

不适用场景：

- 简单 2×2 DID / 单时点处理 → `didregress` / `xtdidregress`（见 `stata-did` skill）
- 错时 DID + 单元 FE 足够 → `hdidregress aipw` / `xthdidregress aipw`（见 `stata-did` skill）
- 错时 DID + 想做 DR/IPW/Reg 三方法对照 → `csdid`（见 `references/csdid-jwdid-imputation.md`）
- 错时 DID + 非线性结果变量（计数 / 二元） → `jwdid method(poisson/logit)`
- 错时 DID + 想 leaveout 方差修正 / 灵活 FE → `did_imputation, leaveout`
- 少数处理单位 + 长 pre-period → `synth`；充分 pre/post + untreated 对照 → `sdid`
- 冲击型 / 少聚类 → `lpdid`

## 与 csdid / jwdid / did_imputation 的差异（**中性对比，不是优劣**）

| 特征 | `csdid` DR/IPW | `jwdid` ETWFE | `did_imputation` BJS | TROP |
|---|---|---|---|---|
| 共同因子模型 | 不建模 | 单元固定效应 | 不建模 | 多因子矩阵 + 核范数 |
| 内生选择处理 | 不处理 | 不处理 | 不处理 | 处理 |
| Semiparametric efficient | 不追求 | 不追求 | 同质效应下成立 | 异质效应下也成立 |
| Stata 包名 | `csdid` | `jwdid` | `did_imputation` | `trop` |
| 安装方式 | `ssc install` | `ssc install` | `ssc install` | `ssc install trop` |
| 必需基础包 | `drdid` | `reghdfe` | `reghdfe` | `nprobust`（带宽） |
| Stata 版本 | 17+ | 17+ | 17+ | 17+ |

**如何选**：看你的**数据特征**和**估计目标**，不是"哪个更好"。

- 处理准随机 + 单元 FE 足够 → `csdid` / `jwdid` / `did_imputation` 都行，按估计目标选
- 处理与潜在因子相关 / 高维共同因子不能被 FE 吸收 → TROP
- 没有共同因子 + 处理准随机 + 单时点 → 内置 `didregress` / `xtdidregress`（见 `stata-did` skill）

---

## 完整语法

```stata
* ---- 安装（一次性）----
ssc install trop, replace
ssc install nprobust, replace        // 带宽

* ---- 基础估计 ----
trop y, id(id) time(t) treat(D) covariates(x1 x2) ///
    factors(k=3 method=nuclear)       // k 个因子，nuclear norm 调整
estat effects                        // ATT(g,t) 矩阵
estat aggregate                      // 总体 ATT
estat placebo                        // 安慰剂检验
```

## 与 LCA / honestdid 联动

```stata
* TROP 估计上做 Rambachan-Roth 敏感性分析
trop y, id(id) time(t) treat(D) covariates(x1 x2) factors(k=3)
honestdid, m(0.5)                   // 在 TROP 估计上做敏感性
```

## 文献

- Athey, S., Imbens, G.W., Qu, Z., & Viviano, D. (2025). "Triply Robust Panel Estimators."
  arXiv:2508.21536.
- Stata 包: `trop` (SSC s459786, Stata 17+, Athey-Imbens-Qu-Viviano 2025). 论文作者参考实现。
