---
name: stata-did
description: 帮助用户用 Stata 内置 DID 命令族做双重差分分析。Use when needing 政策评估 / 双重差分 / DID / DiD / difference-in-differences / 平行趋势检验 / 事件研究 / 错时处理 staggered DID / 三重差分 DDD / 异质性处理效应 / ATET 估计 / wild bootstrap 推断。覆盖 didregress（重复截面）、xtdidregress（面板）、hdidregress / xthdidregress（异质性稳健）四个估计命令与 trendplot / ptrends / granger / aggregation / atetplot / bdecomp 事后诊断。全部为 Stata 17/18+ 内置命令，无需安装；示例语法经 Stata 19.5 实测可复现（verify/verify-did.do）。
---

# Stata 双重差分：didregress 命令族（DID / DDD / 错时处理）

本 skill 对应 Stata 官方 DID 命令族（源自 Stata 19 宣传单 [Causal inference: Difference-in-differences] 的命令体系）：`didregress`、`xtdidregress`、`hdidregress`、`xthdidregress` 及 `estat` 事后诊断。全部为**内置命令**，无需 `ssc install`。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`。平台路径见 `docs/run-stata.md`。
- **中文作图规矩**：需要图形命令且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 安装与版本

```stata
version 19.5                       // 本仓库版本政策：首行钉住
* didregress / xtdidregress：Stata 17+（causal 模块）
* hdidregress / xthdidregress：Stata 18+（异质性稳健估计量）
help didregress                    // 官方手册 [CAUSAL] didregress
```

## 命令选择表

| 数据结构 | 处理时点 | 推荐命令 | 说明 |
|---|---|---|---|
| 重复截面 | 单时点 | `didregress` | 两组×多期独立截面 |
| 重复截面 | 单时点 + 双组维度 | `didregress` + 双 `group()` | 三重差分 DDD |
| 面板 | 单时点 | `xtdidregress` | 需先 `xtset` |
| 重复截面/面板 | 错时（staggered） | `hdidregress` / `xthdidregress` | TWFE 在错时下有偏，用异质性稳健估计量 |

共同语法骨架：`命令 (结局变量 [协变量]) (处理变量), group(组变量) time(时间变量)`——**处理变量必须放在第二对括号里**，估计目标是 ATET（处理组的平均处理效应）。

---

## 1. 基础 DID：didregress（重复截面）

```stata
* 数据结构：group 变量（0/1 或多组）、time 变量、treat = 处理组且处理后
didregress (satis) (treat), group(hospital) time(month)
estat trendplot                        // 平行趋势图（事后）
```

- 结局模型自动吸收组效应与时间效应，报告 ATET。
- 协变量放第一对括号：`didregress (satis age female) (treat), ...`。

## 2. 三重差分 DDD：group() 放两个组变量

处理状态必须在**两个组维度的组合**上变化（如：处理医院 × 参保患者）：

```stata
didregress (satis3) (treat3), group(hospital insured) time(month)
```

## 3. 推断选项：Donald–Lang 聚合与 wild bootstrap

```stata
* Donald–Lang：收缩到组×期均值后做推断（组数少时更稳）
didregress (satis) (treat), group(hospital) time(month) aggregate(dlang)

* 限制性 wild bootstrap：在零假设 ATET=0 下重抽，给 CI 与 p 值
* 注意是 rseed() 不是 seed()；reps() 默认 1000
didregress (satis) (treat), group(hospital) time(month) ///
    wildbootstrap(reps(99) rseed(20260816))
```

## 4. 面板 DID：xtdidregress

```stata
xtset id month
xtdidregress (satis x1) (treat), group(grp) time(month)
estat trendplot                        // 平行趋势图
estat ptrends                          // 事前平行趋势检验（注意不是 trends）
estat granger                          // Granger 型事前趋势检验
```

- 协变量与结局同在第一对括号：`(satis x1)`；第二对括号只放处理变量。
- `xtdidregress` 也支持 `aggregate(dlang)` 与 `wildbootstrap()`。

## 5. 异质性稳健 DID：hdidregress（错时处理 cohort）

错时处理（staggered adoption）下 TWFE 会混入"已处理组当对照"的负权重，产生偏误；`hdidregress` 提供异质性稳健估计量：

```stata
xtset id month
* 方法：twfe（双向固定效应）/ ra（回归调整）/ ipw / dr（双重稳健）
hdidregress twfe (y) (treat), group(id) time(month)

estat atetplot                         // 各 cohort 的 ATET 图
estat aggregation                      // 总体聚合（默认 overall）
estat aggregation, cohort              // 按 cohort 聚合
estat aggregation, dynamic             // 按处理暴露期聚合（事件研究视角）

hdidregress ra (y) (treat), group(id) time(month)
estat aggregation, overall
```

## 6. 面板异质性稳健版：xthdidregress

```stata
xtset id month                         // 必须先 xtset
xthdidregress twfe (y) (treat), group(id)
estat atetplot
estat aggregation, cohort
```

- **没有 `time()` 选项**：时间变量从 `xtset` 读取。

## 7. 处理效应分解：estat bdecomp（错时设计）

把总效应分解为 DID 效应、ATT 与选择项，直观展示错时下 TWFE 偏误来源：

```stata
* 前提 1：处理时点至少两个（错时设计）；前提 2：数据强平衡（每格一观测）
collapse (mean) y treat, by(group time)   // 个体级先收缩到组×期均值
didregress (y) (treat), group(group) time(time)
estat bdecomp                          // DID / ATT / 选择项分解
```

## 事后命令速查

| 命令 | 适用估计 | 作用 |
|---|---|---|
| `estat trendplot` | didregress / xtdidregress | 平行趋势图 |
| `estat ptrends` | didregress / xtdidregress / hdidregress | 事前平行趋势检验 |
| `estat granger` | didregress / xtdidregress | Granger 型事前趋势检验 |
| `estat grangerplot` | didregress / xtdidregress | Granger 检验图 |
| `estat aggregation` | hdidregress / xthdidregress | overall / cohort / dynamic 聚合 |
| `estat atetplot` | hdidregress / xthdidregress | 各 cohort ATET 图 |
| `estat bdecomp` | didregress（错时 + 强平衡） | 效应分解 |

## 常见陷阱

1. **处理变量放错括号**：`(结局 协变量) (处理变量)`——把协变量放进第二对括号会报 `invalid treatment variable`。
2. **`estat trends` 不存在**：事前趋势检验命令是 `estat ptrends`。
3. **`xthdidregress` 不接受 `time()`**：报 `option time() not allowed`，先 `xtset` 即可。
4. **wildbootstrap 种子是 `rseed()`**：写 `seed()` 报 `invalid 'reps'` 类错误。
5. **`estat bdecomp` 两前提**：处理时点 ≥ 2（错时设计）+ 数据强平衡（个体级先 `collapse` 到组×期均值）。
6. **单时点 DID 用 TWFE 没问题，错时必须换稳健估计量**：`hdidregress` / `xthdidregress`，并配合 `estat aggregation, dynamic` 看事件研究图。
7. **wild bootstrap 后 `estat vce` 不允许**：官方明确禁止。

## 验证

- 本 skill 全部语法经 `verify/verify-did.do` 在 Stata 19.5（StataNow MP）批处理模式实测通过；数据全部本地模拟（`set seed` 固定），不依赖网络与额外 `.dta`。
- 运行：`bash verify/run-verify.sh did`；全量六个 skill：`bash verify/run-verify.sh`。
