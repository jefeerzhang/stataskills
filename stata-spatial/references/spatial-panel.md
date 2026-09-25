---
name: stata-spatial-panel
description: 空间面板模型：spxtregress（内置 FE/RE ML）、xsmle（SSC，SAR/SDM/SAC/SEM + 动态）、spregdpd（SSC，空间动态面板 GMM-FD）、spxtivdfreg（含未观测共同因子的去因子 IV）四者对照与选择。
---

# 空间面板模型

面板的空间设定要同时回答两个问题：**空间依赖怎么进模型**（滞后 / 误差 / 杜宾）和**是否还有时间维度**（静态 / 动态）。本文件给出四个命令的对照与选择规则。

## 1. 四者对照

| | `spxtregress` | `xsmle` | `spregdpd` | `spxtivdfreg` |
|---|---|---|---|---|
| 来源 | **内置**（Stata 15+） | SSC | SSC | Kripfganz 站点（`xtivdfreg` 包） |
| 估计方法 | 拟 ML | ML | GMM-FD（一阶差分 GMM） | 去因子 IV / GMM |
| 模型形式 | SAR / SEM / SDM | SAR / SDM / SAC / SEM | 空间动态面板 | 空间动态面板 |
| 静态 / 动态 | 静态 | 静态 + 动态（`dlag`） | 动态 | 动态 |
| FE / RE | `fe` / `re` | `fe` / `re` | FE（差分） | `absorb()` 吸收 FE |
| 未观测共同因子 | ❌ | ❌ | ❌ | ✅ 估计并去因子 |
| 内生回归量 | 有限 | ❌ | ✅（GMM） | ✅（`iv()`） |
| 偏误修正 | 不需要 | 需要 Lee-Yu 修正 | — | 不需要 |
| 异质斜率 | ❌ | ❌ | ❌ | ✅（`mg`） |

**选择规则**：

1. 静态、无共同因子 → `spxtregress`（内置，最省事）。
2. 需要 SAC / 动态 `dlag` / 更多模型形式对照 → `xsmle`。
3. 短 T、含滞后因变量、可能有内生回归量 → `spregdpd` 或 `spxtivdfreg`。
4. **怀疑未观测共同因子**（宏观冲击、同期共同趋势） → 只能 `spxtivdfreg`。

## 2. `spxtregress`（内置）

```stata
version 19.5
xtset id t

* 固定效应 SAR
spxtregress y x, fe dvarlag(W)
* 随机效应 SARAR
spxtregress y x, re dvarlag(W) errorlag(W)
* 空间杜宾
spxtregress y x, fe dvarlag(W) ivarlag(W: x)

estat impact
```

- `fe` 与 `re` 二选一；`re` 需要个体效应与协变量不相关的假设。
- 后估计 `estat impact` 给出直接 / 间接 / 总效应。
- W 必须是 `spmatrix` 对象（不能是 `spmat`）。

## 3. `xsmle`（SSC）

```stata
ssc install xsmle, replace

* 语法：xsmle depvar [indepvars], wmat(name) model(sar|sdm|sac|sem) [options]
xsmle y x, wmat(W) model(sar) fe type(both) effects
xsmle y x, wmat(W) model(sdm) fe type(both) effects
xsmle y x, wmat(W) emat(W) model(sac) re effects
```

- `wmat()` 是空间滞后权重，`emat()` 是空间误差权重；SAC 需要两者。
- `model()` 取 `sar` / `sdm` / `sac` / `sem`。
- `fe` / `re`；`type(ind|time|both)` 控制双向固定效应。
- `effects` 输出直接 / 间接 / 总效应。
- `dlag(#)` 引入被解释变量的时间滞后（动态设定），此时 ML 的 Lee-Yu 偏误修正更关键。

## 4. `spregdpd`（SSC，空间动态面板 GMM-FD）

```stata
ssc install spregdpd, replace
help spregdpd
```

一阶差分 GMM 路线，适用于**短 T、大 N** 且含滞后因变量的空间面板。与 `stata-regression` 的动态面板 GMM 同源（Arellano-Bond 思路），差别是额外引入空间滞后项。

⚠️ 具体选项随版本变动，**以 `help spregdpd` 为准**，不要照抄二手教程。

## 5. `spxtivdfreg`（含未观测共同因子）

```stata
net install xtivdfreg, from("http://www.kripfganz.de/stata/") replace
* ↑ `ssc install xtivdfreg` 会失败（SSC 归档缺文件，实测 rc=679）

spxtivdfreg y x1 x2, absorb(id) splag tlags(1) spmatrix("W.csv", import) ///
    iv(z1 x1 x2, splags lag(1)) std
```

- `splag` 引入空间滞后；`tlags(1)` 引入时间滞后。
- `spmatrix("W.csv", import)` 读入外部权重矩阵（也支持已声明的 `spmatrix` 对象）。
- `iv(...)` 声明工具变量；`splags lag(1)` 用空间滞后的滞后作工具。
- `std` 标准化变量；`mg` 切换均值组（异质斜率）估计；`factmax(#)` 限制共同因子个数。
- 后估计：`estat impact, sr`（短期）/ `estat impact, lr`（长期）。

### 共同因子为什么关键

`xsmle` 与 `spxtregress` 都假设「给定 W 后截面独立」。存在未观测共同因子（宏观冲击、同期共同趋势）时该假设被违反，估计会有实质偏误。Kripfganz & Sarafidis (2025) 的银行信贷风险实证：

| 规格 | ρ（时间持续） | ψ（空间滞后） | Hansen J |
|---|---|---|---|
| 含共同因子 | 0.290 | 0.394 | p = 0.468 |
| 不含共同因子 | **0.594** | 0.288 | **p < 0.001** |

漏掉共同因子使 ρ 翻倍、J 检验拒绝。**诊断做法**：分别估计 `factmax(0)` 与默认规格，若 J 检验在无因子规格被拒绝，说明必须保留共同因子。

### 短期 vs 长期效应

含时间滞后与空间滞后时，长期总效应 ≈ β / [(1−ρ)(1−ψ)]，远大于同期系数。用 `estat impact, sr` 与 `estat impact, lr` 分别报告，不要把同期系数当总效应。

## 6. 陷阱

1. **在含共同因子的面板上只用 `xsmle` / `spxtregress`** → 触发：面板有宏观共同冲击 → Fix：`spxtivdfreg` + J 检验对照 → 验证：含 / 不含因子两规格的 ρ 与系数差异被如实报告。
2. **用 `xsmle` / `spxtregress` 处理内生协变量** → 触发：协变量内生 → Fix：`spxtivdfreg` 的 `iv()`（面板）或 `spivregress`（横截面）→ 验证：报告工具来源与过度识别检验。
3. **短 T 动态面板直接套静态空间面板** → 触发：含 `L.y` 却用 `spxtregress` → Fix：走 `spregdpd` / `spxtivdfreg` → 验证：报告时间持续参数 ρ 及其显著性。
4. **把 `xsmle` 的 ML 结果当作无需修正** → 触发：FE 且 T 小 → Fix：应用 Lee-Yu 偏误修正或改用 IV 路线 → 验证：报告修正前后的对照。
5. **W 时不变假设未说明** → 触发：研究期长、空间结构明显变化 → Fix：说明假设或构造时变 W → 验证：论文写明「W 在研究期内视为不变」及其理由。

## 7. 踢走

- 没有空间依赖、只是普通面板 → `stata-regression`（含动态面板 GMM 段）。
- 处理时点 / 政策评估 → `stata-did` / `stata-did-community`。
- 想做因果识别 → `stata-identification`。
- 只是横截面空间回归 → 回主文件的六步强制路径。