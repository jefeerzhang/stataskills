# Python 补位：无 Stata 版本的 4 个 DID 估计量

本文件是 `stata-did-community` 的**退化路径**。主路径仍是 Stata：26 个 diff-diff 估计量中 22 个在 Stata 有可用实现（见下方对照表）。剩下 4 个没有可信的 Stata 实现，本仓库用 `python/did_py.py` 调用 `diff-diff` 补齐，并把结果写成 Stata 可直接 `use` 的 `.dta`。

> **归档来源**：`diff-diff` v3.13.0（2026-10-17，PyPI）。本机 Python 3.13.3 实测：四个子命令全部跑通，见 `verify/verify-did-python.sh`。

## 何时进入本文件

**强制路径**：命中以下任一条件，就必须走 Python 补位，不得在 Stata 里凑近似。

| 场景 | Python 子命令 | 为什么不能留在 Stata |
|---|---|---|
| 连续处理剂量 + 想看剂量反应曲线 / ACRT | `continuous` | 只有 R 包 `contdid`（alpha），Stata 无对应命令 |
| 高维协变量 + 需要正交化（Neyman-orthogonal）调整 | `dml` | `ddml` 是通用 DML 引擎，无 DiD 得分模型 |
| 想要半参数有效（EIF）估计与更紧的 CI | `efficient` | 未发布 Stata 包 |
| 结果是「进入吸收态的时间」（失业持续期、刑满释放再犯） | `duration` | 作者只发布 `durationdid.ado` 自托管，不在 SSC |

**不得**用以下 Stata 命令冒充上表四个方法：

- 不得用 `didregress` 的连续处理当作 `continuous`——那是 TWFE 线性规格，Callaway-Goodman-Bacon-Sant'Anna (2024) 明确说它的系数不能读成剂量反应。
- 不得用 `ddml` 的 `partial` 模型当作 `dml`——那只做交叉拟合的部分线性模型，不是 Chang (2020) 的 DiD 正交得分。
- 不得用 `csdid` 的池化估计当作 `efficient`——目标参数不同，前者是 ATT(g,t) 加权平均，后者是半参数有效估计。
- 不得用 `cloglog` / `streg` 的普通生存模型当作 `duration`——`duration` 识别的是**未处理风险之比/差**的平行趋势，不是 Cox 的 PH 系数。

## 安装

```bash
pip install diff-diff        # 实测 3.13.0
```

`did_py.py` 只用 `diff-diff` + `pandas` + `numpy`，无其他依赖。`numpy` / `pandas` / `scipy` 已由 `diff-diff` 的依赖声明带入。

## 通用数据契约

所有子命令共用四列：

| 列 | 含义 |
|---|---|
| `--outcome` | 数值结果变量 |
| `--unit` | 单位标识 |
| `--time` | 整数期标 |
| `--first-treat` | 首次处理期；**从未处理用 `0`**（`duration` 改收 `--treatment`，0/1 组别） |

`--data` 支持 `.dta` 与 `.csv`。写入用 `-o`，格式由 `--format` 选择：

| `--format` | 产物 | 用途 |
|---|---|---|
| `json`（默认） | 头部结果 + 分块表 | 脚本后续处理 |
| `csv` | 长表，`block` 列区分头部/曲线/事件研究 | Excel / 二次加工 |
| `dta` | 一行 Stata 数据集 | Stata 直接 `use` |

## 四个子命令

### 1. `continuous` — ContinuousDiD（Callaway, Goodman-Bacon & Sant'Anna 2024）

```bash
python stata-did-community/python/did_py.py continuous \
  --data data/did-python/panel_staggered.dta \
  --outcome y --unit id --time t --first-treat g --dose dose \
  -o results/continuous.json
```

- `--dose` 必须**单位内不随时间变化**。此约束来自估计量定义（单位处理强度），不是实现缺陷；传了变动剂量会报 `dose must be time-invariant per unit`。
- 输出：`att` / `se` / `ci` + `overall_acrt`（平均因果响应）+ `dose_response` 曲线（`dose`, `effect`, `se`, CI）。
- 报告规矩：**必须同时报 ATT 与 ACRT**。只报 ATT 会掩盖剂量维度的信息。

### 2. `dml` — DMLDiD（Chang 2020）

```bash
python stata-did-community/python/did_py.py dml \
  --data data/did-python/panel_staggered.dta \
  --outcome y --unit id --time t --first-treat g \
  --covariates x1 x2 --n-folds 5 \
  -o results/dml.json
```

- `--covariates` **必填**。无协变量时 Chang 的估计量退化为无条件错时 DiD，`diff-diff` 直接拒绝并提示改用 `CallawaySantAnna`。这不是本仓的限制。
- `--propensity-learner` / `--outcome-learner` 默认 `logit` / `linear`；可传 sklearn 兼容的 learner 名。
- `--repeated-cross-section` 对应 Chang (2020) Case 2。
- 输出：`att` / `se` + `event_study` 表。

### 3. `efficient` — EfficientDiD（Chen, Sant'Anna & Xie 2025）

```bash
python stata-did-community/python/did_py.py efficient \
  --data data/did-python/panel_staggered.dta \
  --outcome y --unit id --time t --first-treat g \
  -o results/efficient.json
```

- `--pt-assumption` 取 `all`（前期与后期都用平行趋势）或 `post`（只用后期）。默认 `all`。
- `--covariates` 可选。
- 输出：`att` / `se` / `estimation_path` + `event_study` 表。
- 优势在效率：同一数据下 SE 通常小于 `csdid`。论文中可作 `csdid` 的精度对照，但**目标参数需说明一致**才算对照。

### 4. `duration` — DurationDiD（Deaner & Ku 2026）

```bash
python stata-did-community/python/did_py.py duration \
  --data data/did-python/spell_duration.dta \
  --outcome y --unit id --time t \
  --treatment treated --last-pre-period 5 --method cd \
  --bootstrap 200 -o results/duration.json
```

- 结果变量必须是**二元吸收态**：0 = 尚未结束，1 = 已结束且之后保持 1。非二元值会报错。
- `--treatment` 是 0/1 组别标志，不是首处理期。
- `--last-pre-period` 是处理前最后一个期。
- `--method`：`cd` = 未处理风险的可加差（common dynamics），`ph` = 风险比。
- `--bootstrap` 建议 ≥ 200；默认 0 会退化到解析式（该估计量以小样本自助法为主要推断方式）。
- 输出：`att` / `se` + `post_periods` 表（逐期 ATT、同时置信带）。

## 在 Stata 与 Python 之间往返

推荐工作流：Stata 存盘 → Python 跑补位估计 → Stata 读回。

```stata
* Stata 侧：准备面板
use data/did-python/panel_staggered.dta, clear
save mypanel.dta, replace
```

```bash
python stata-did-community/python/did_py.py dml \
  --data mypanel.dta --outcome y --unit id --time t --first-treat g \
  --covariates x1 x2 --format dta -o results/dml_headline.dta
```

```stata
* Stata 侧：读回结果
use results/dml_headline.dta, clear
list
```

`--format dta` 写出的是**一行**汇总（estimator / att / se / t_stat / p_value / ci_lower / ci_upper / n_obs 等）。逐期或逐剂量结果用 `json` 或 `csv` 保存。

> **注意**：`--format dta` 只保留头部行。需要曲线或事件研究表时，改用 `json`，或先写 `csv` 再 `import delimited`。

## 22 个有 Stata 实现的估计量（不进入本文件）

| diff-diff 估计量 | Stata 命令 | 分发 |
|---|---|---|
| `DifferenceInDifferences` | `didregress` / `regress` | 内置 |
| `TwoWayFixedEffects` | `xtdidregress` / `reghdfe` | 内置 / SSC |
| `MultiPeriodDiD` | `reghdfe` + 相对时间哑变量；4.0 起由 `TwoWayFixedEffects(event_study=True)` 承接 | 内置 |
| `CallawaySantAnna` | `csdid` / `xthdidregress aipw` | SSC / 内置 |
| `SunAbraham` | `csdid` 事件研究（渐近等价）；或 `eventstudyinteract` | SSC |
| `ImputationDiD` | `did_imputation` | SSC |
| `TwoStageDiD` | `did2s`；或 `csdid, method(twostage)` | SSC |
| `SpilloverDiD` | `did2s` + 手工构造 ring 哑变量 | SSC，需自建 |
| `SyntheticDiD` | `sdid` | SSC |
| `SyntheticControl` | `synth` / `synth_runner` | SSC |
| `TripleDifference` | `xtdidregress, group(g1 g2)`（同质效应） | 内置 |
| `StaggeredTripleDifference` | 无官方合并命令；`TripleDifference` 4.0 起原生支持错时 | — |
| `ChaisemartinDHaultfoeuille` | `xtswitchdid`（StataNow）/ `did_multiplegt_dyn` | 内置 / 社区 |
| `HeterogeneousAdoptionDiD` | `did_had` | GitHub `net install` |
| `RegressionDiscontinuity` | `rdrobust` | SSC |
| `StackedDiD` | `stacked` | SSC |
| `TROP` | `trop`（SSC S459786） | SSC |
| `WooldridgeDiD` | `jwdid` | SSC |
| `LPDiD` | `lpdid` | SSC |
| `ChangesInChanges` | `cic`（SSC S458656） | SSC |
| `LWDiD` | `lwdid`（SSC S459672，2026-04） | SSC |
| `BaconDecomposition` | `estat bdecomp` / `twowayfeweights`（SSC S458611） | 内置 / SSC |
| TWFE 权重诊断（diff-diff 3.13） | `twowayfeweights` | SSC |

`StaggeredTripleDifference` 在 diff-diff 4.0 被移除（并入 `TripleDifference(first_treat=)`），Stata 侧对应能力目前靠手工交互项或 `csdid` 近似，精度未实测。

## 与 diff-diff 的版本锚点

本文件对应 `diff-diff` v3.13.0。该项目的 4.0 切换窗口（2026-10-18 起）已删除 `MultiPeriodDiD`、`StaggeredTripleDifference`、`QDiD`、`robust=` 与 8 个模块级包装函数。本仓库的 `did_py.py` 只调用四个保留类，不受影响。

## 参考文献

- Callaway, Goodman-Bacon & Sant'Anna (2024). Difference-in-Differences with a Continuous Treatment. NBER WP 32117. <https://www.nber.org/papers/w32117>
- Chang (2020). Double/debiased machine learning for difference-in-differences models. *Econometrics Journal* 23(2), 177–191. DOI 10.1093/ectj/utaa001
- Chen, Sant'Anna & Xie (2025). Efficient Difference-in-Differences and Event Study Estimators. <https://arxiv.org/pdf/2506.17729>
- Deaner & Ku (2026). Causal Duration Analysis with Diff-in-Diff. <https://arxiv.org/abs/2405.05220>
