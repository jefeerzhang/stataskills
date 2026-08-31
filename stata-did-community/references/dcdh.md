---
name: stata-did-community-dcdh
description: DCDH 可逆处理 DID 参考：did_multiplegt 三个模式——(dyn) 事件研究支持可逆/非二元处理、(stat) 静态 ATT 支持非二元处理、(had) 无 stayer 设计。de Chaisemartin & D'Haultfœuille 系列论文。主文件见 stata-did-community/SKILL.md。
---

# stata-did-community-dcdh

> **加载时机**：主 SKILL.md 决策树已读完，遇到"处理可逆（可开可关）"、"处理非二元"、"无 stayers"中任一场景时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 5. DCDH：可逆处理 DID（de Chaisemartin & D'Haultfœuille）

适用场景：**处理可以开启也可以关闭**（如工会会员、政策实施后又撤销、补贴发放后又停止），或**处理是连续/离散多值**而非 0/1 二元。传统 DID 估计量（`csdid`/`jwdid`/`did_imputation`）都假设处理是吸收的（absorbing：一旦处理，永不撤销）；`did_multiplegt` 是 Stata 中**唯一**同时支持可逆处理和非二元处理的 DID 估计量。

`did_multiplegt` 是一个统一入口，通过 `mode` 参数调用四个子估计量：

| mode | 子命令 | 核心论文 | 用途 |
|---|---|---|---|
| `dyn` | `did_multiplegt_dyn` | de Chaisemartin & D'Haultfoeuille (2026) | **推荐默认**。事件研究估计量，支持可逆/非二元/滞后效应 |
| `stat` | `did_multiplegt_stat` | de Chaisemartin & D'Haultfoeuille (2020); de Chaisemartin et al. (2022) | 静态 ATT，支持连续处理 + IV-DID |
| `had` | `did_had` | de Chaisemartin & D'Haultfoeuille (2024b) | 异质性采用设计（无 stayers，仅 quasi-stayers） |
| `old` | `did_multiplegt_old` | de Chaisemartin & D'Haultfoeuille (2020) | 旧版，**不推荐**，用 `dyn` 替代 |

### 安装

```stata
ssc install did_multiplegt, replace
* 也可单独安装 dyn 模式：
ssc install did_multiplegt_dyn, replace
```

`did_multiplegt` 会自动更新子包（平均每 100 次运行更新一次），用 `no_updates` 选项可关闭。

### 核心语法（dyn 模式）

```stata
did_multiplegt (dyn) Y G T D [if] [in] [, options]
```

| 参数 | 含义 |
|---|---|
| `Y` | 结局变量 |
| `G` | 组变量（面板单位 id） |
| `T` | 时间变量（需等间距） |
| `D` | 处理变量（可二元/离散/连续，可随时间变化） |

### 主要选项

| 选项 | 含义 | 默认 |
|---|---|---|
| `effects(#)` | 估计事件研究效应的期数 | 1 |
| `normalized` | 归一化效应（可解释为"处理增加 1 单位的效应"） | 关闭 |
| `normalized_weights` | 显示归一化权重（当前处理 vs 各滞后） | 关闭 |
| `placebo(#)` | 安慰剂检验期数（处理前） | 0 |
| `same_switchers` | 限制为所有效应都可估计的 switchers | 关闭 |
| `only_never_switchers` | 仅用从未变换单位做对照 | 关闭（用所有 not-yet-switchers） |
| `controls(varlist)` | 时变协变量 | — |
| `trends_lin` | 允许组特定线性趋势 | 关闭 |
| `trends_nonparam(varlist)` | 非参数组特定趋势（如 industry×year） | — |
| `cluster(varname)` | 聚类变量 | 默认按 G 聚类 |
| `bootstrap(reps,seed)` | bootstrap 推断 | 关闭（用解析 SE） |
| `by(varname)` | 按组级变量分组估计 | — |
| `design(float, string)` | 显示 switchers 的处理路径 | — |
| `by_path(#)` | 按最常见处理路径分别估计 | — |
| `switchers(string)` | 仅估计 switchers-in 或 switchers-out | 全部 |
| `graph_off` | 不出图 | 关闭 |
| `save_results(path)` | 保存结果到 .dta | — |
| `save_sample` | 生成 `_did_sample` 标记估计样本 | — |

### 完整工作流示例

```stata
* 0. 安装（一次性）
ssc install did_multiplegt, replace

* 1. 数据准备
* 工会会员对工资的影响（可逆处理：入会/退会）
bcuse wagepan, clear

* 2. 事件研究：5 期效应 + 2 期安慰剂
did_multiplegt (dyn) lwage nr year union, ///
    effects(5) placebo(2) cluster(nr) graph_off

* 3. 归一化效应（可解释为"工会会员增加 1 期的效应"）
did_multiplegt (dyn) lwage nr year union, ///
    effects(5) normalized cluster(nr) graph_off

* 4. 查看 switchers 的处理路径
did_multiplegt (dyn) lwage nr year union, ///
    effects(5) design(0.5, console) cluster(nr)

* 5. 按路径分别估计（如 0→1→0 vs 0→1→1→...）
did_multiplegt (dyn) lwage nr year union, ///
    effects(5) by_path(all) cluster(nr) graph_off

* 6. 静态 ATT（stat 模式）
did_multiplegt (stat) lwage nr year union, ///
    exact_match cluster(nr)

* 7. 含协变量的估计
did_multiplegt (dyn) lwage nr year union, ///
    effects(5) controls(educ exper) cluster(nr) graph_off
```

### dyn vs stat 模式选择

| 场景 | 推荐模式 | 理由 |
|---|---|---|
| 要事件研究图（动态效应） | `dyn` | 直接输出各期效应 + 安慰剂 |
| 要静态 ATT（单个汇总效应） | `stat` | 更简洁，支持 IV-DID |
| 处理可逆 + 要滞后效应 | `dyn` | `stat` 假设过去处理不影响当前结局 |
| 连续处理 + 有 stayers | `stat` | `stat` 支持连续处理的 IV 估计 |
| 无 stayers（所有单位最终都处理） | `had` | 专为无 stayer 设计 |

### 与 diff-diff 的对应关系

`did_multiplegt (dyn)` ≈ diff-diff 的 `ChaisemartinDHaultfoeuille`（别名 `DCDH`）。diff-diff 用 `did_multiplegt` 作为 Stata 端的交叉验证锚点。

### Heterogeneous Adoption Design 的两条平行路线

`did_multiplegt (had)` 和 `did_had v2.0.0` **不是替代关系**——它们是同主题
（"无 stayers / 无对照组的 HAD 设计"）下的**两条互补路径**，目标参数、识别假设和适用场景都不同。
选择哪条取决于**数据特征**和**研究问题**，不是"哪个更好"。

#### 目标参数对比

| 维度 | `did_multiplegt (had)` | `did_had v2.0.0` |
|---|---|---|
| 文献 | de Chaisemartin-D'Haultfœuille (2024b) | de Chaisemartin-Ciccia-d'Haultfœuille-Knau (2026, arXiv:2405.04465v6) |
| 目标参数 | **DID_M**（一个 scalar） | **WAS_d̲**（一族，d̲ 可选 → dose-response curve） |
| 目标参数含义 | "最后处理组" vs "stayers" 的 ATT | E[(Y_2(D_2) − Y_2(0)) / D_2 \| D_2 ≥ d̲]——剂量-反应斜率的加权平均 |
| 设计 | 部分 stayers + 部分 switchers；或 0/1 处理 | 所有单位 D > 0；处理连续 |
| 估计量 | DID 矩估计（DCDH 2020 框架） | 局部线性 + MSE-optimal bandwidth（`nprobust`） + Bell-McCaffrey HC2 SE |

#### 识别假设对比（关键）

| | `did_multiplegt (had)` | `did_had v2.0.0` |
|---|---|---|
| Case 1: 有 QUG | **PT w/ quasi-stayer 组**（quasi-stayer 充当对照组） | **PT w/ QUG** + boundary identification |
| Case 2: 无 QUG | ❌ **DID_M 未识别**（quasi-stayer 是必要条件） | ✅ **Boundary identification**（无需 PT，靠剂量-结果函数在边界处连续——RDD 风格） |

**为什么不能互相替代**：
- `did_multiplegt (had)` 的 HAD 估计量在无 QUG 时根本**算不出来**——quasi-stayer 必须存在
- `did_had v2.0.0` 在 Case 1（QUG 存在）能算但**没有优势**——PT + QUG 已经够好，引入局部线性反而带来带宽选择的额外不确定性
- 两者**估计不同参数**：DID_M（一个 ATT 数字）vs WAS_d̲（剂量-反应曲线）。把它们当成"同一问题的两种解"是常见误解

#### 数据特征分叉决策树（**不是"哪个更好"**）

```
研究问题：要 ATT 还是 dose-response curve？
├─ 要 ATT（一个数字）+ 有 stayers/switcher
│   ├─ 处理是 0/1               → did_multiplegt (had)        ← 唯一可走
│   └─ 处理是连续 + 有 QUG       → did_multiplegt (had)        ← 简单；无需 bandwidth
├─ 要 dose-response curve        → did_had v2.0.0              ← 唯一可走
└─ 连续剂量 + 无 QUG（universal） → did_had v2.0.0              ← 唯一可走；did_multiplegt (had) 失效
```

#### `did_had v2.0.0` 完整语法

```stata
net install did_had, from("https://raw.githubusercontent.com/Credible-Answers/did_had/main") replace

did_had y, id(id) time(t) dose(D_g2) bandwidth(mse)             // MSE-optimal bandwidth
did_had y, id(id) time(t) dose(D_g2) method(ll) ci(bc)           // 局部线性 + bias-corrected CI
did_had, pretest(qug)                                             // QUG pretest（Case 1/2 分流诊断）
did_had, dose_grid(0(0.1)2)                                       // 画 dose-response curve（多个 d̲）
```

#### 文献

- de Chaisemartin, C. & D'Haultfœuille, X. (2024b). "Two-way Fixed Effects and
  Differences-in-Differences Estimators in Heterogeneous Adoption Designs."
- de Chaisemartin, C., Ciccia, D., D'Haultfœuille, X., & Knau, F. (2026).
  "Difference-in-Differences Estimators When No Unit Remains Untreated."
  arXiv:2405.04465v6.

