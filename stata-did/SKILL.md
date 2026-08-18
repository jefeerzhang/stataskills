---
name: stata-did
description: Stata 内置 DID 命令族：didregress / xtdidregress / hdidregress / xthdidregress，含平行趋势检验、事件研究、DDD、wild bootstrap。全部内置，无需 ssc install。触发词：DID / 双重差分 / 政策评估 / 错时处理 / 平行趋势 / 事件研究。
---

# Stata 双重差分：didregress 命令族（DID / DDD / 错时处理）

本 skill 对应 Stata 官方 DID 命令族（源自 Stata 19 宣传单 [Causal inference: Difference-in-differences] 的命令体系）：`didregress`、`xtdidregress`、`hdidregress`、`xthdidregress` 及 `estat` 事后诊断，全部为**内置命令**，无需 `ssc install`。社区包（reghdfe / eventdd / csdid / jwdid / did_imputation / synth / sdid）见 `stata-did-community` skill。

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

## 8. 经典手工 DID：`xtreg` + 交互项（Stata < 17 时代脉络）

Stata 17+ 的 `didregress`/`xtdidregress` 自动吸收组与时间固定效应并报告 ATET；Stata 17 之前没有这条官方路径，研究者手工构造"处理 × 事后"交互项并用 `xtreg` 跑。这一节保留这条历史脉络，方便阅读老论文与迁移到 `xtdidregress`。

```stata
* 1. 生成交互项：treat_post = treated × post
gen post    = (year >= 2000)
gen treated = (condlist)              // 1 = 处理组，0 = 对照组
gen treat_post = treated * post

* 2. 跑双向固定效应面板回归（处理 + 年固定效应）
xtreg trade treat_post i.year, fe vce(cluster id)
```

`treat_post` 的系数就是 DID 估计量；`i.year` 吸收年固定效应；`fe` 吸收个体固定效应；`vce(cluster id)` 在个体层聚类稳健 SE。这与 `xtdidregress (y) (treat_post), group(id) time(year)` 在代数上等价——后者只是把同样的估计写成声明式接口。

## 9. 组变量预处理：`encode` 把字符串变数值

`xtset` 只接受数值型组变量；如果原始数据组变量是字符串（如 country = "Australia"），必须先 `encode`：

```stata
xtset country year
* → "country is string variable; cannot be xtset"

encode country, gen(country_id)        // country_id 是 1..N 的整数 + 同名值标签
xtset country_id year                  // 现在 OK
xtdidregress (y) (treat), group(country_id) time(year)
```

**Fix**：`encode` 创建的新变量带值标签，所以 `tab country_id` 仍能看到原国家名；不要把 `country` 原变量与 `country_id` 混用。

## 10. 手工平行趋势图：`bysort` + `twoway line`

不依赖 `didregress` / `xtdidregress`，任何面板数据都能画——这在探索阶段（还没决定估计量）或跑 `reghdfe`/`csdid` 后很有用：

```stata
* 1. 收缩到 (年 × 组) 均值
bysort year treated: egen mean_y = mean(y)

* 2. 双线图（实线对照 + 虚线处理）+ 政策年参考线
twoway line mean_y year if treated==0, sort lpattern(solid) ///
   || line mean_y year if treated==1, sort lpattern(dash) ///
   || xline(2000, lpattern(dot))                      ///
   legend(label(1 "Control") label(2 "Treated"))    ///
   title("Pre/Post trend (manual, any data)")        ///
   scheme(s1mono)
graph export "output/pre_post_trend_manual.png", replace
```

**Fix**：先 `bysort year treated: egen mean_y = mean(y)` 才会出现两条线，否则散点太密；`sort` 选项让线按 x 轴排序；`xline(政策年)` 是判断平行趋势假设的视觉锚点。

## 11. 真实案例：平行趋势假设被拒时的应对

Princeton 教程 wdipol.dta 案例里，`xtdidregress (trade) (treated_post), group(country) time(year)` 后跑 `estat ptrends` 报 p=0.003——明确拒绝平行趋势原假设。

**这种时候标准做法**（按优先级）：

1. **看平行趋势图**：`estat trendplot`（或上面的手工 line 图）——判断是"处理前趋势本身就不平行"还是"预处理期太短/数据噪音大"。
2. **检查政策时间线**：是不是真的有"同期对照"？会不会某对照国其实在那段时间也有政策影响？通常需重读文献。
3. **加协变量平衡趋势差**：`xtdidregress (y x1 x2) (treat), group(id) time(t)`，看加协变量后 ptrends 是否变得不显著。
4. **改用合成 DID / 异质性稳健估计**：
   - `hdidregress aipw`——双重稳健，能在趋势差异存在时给出一致估计
   - `xthdidregress aipw`（面板版）
   - **不要简单地加更多控制变量**——这是过度反应，且会引入 bad control
5. **跑 Honest DiD 敏感性分析**（Rambachan & Roth 2023）：
   - 安装：`ssc install honestdid`（社区包，Stata 内置无）
   - 跑：`honestdid, m(0)` 与 `honestdid, m(0.5)`——报告 PT 违反幅度 ≤ 0.5 SD 下的稳健 CI 上界
   - 这是审稿人最常要求的稳健性检查；缺失等于"只信主估计"
6. **报告与解释**：在论文里诚实报告平行趋势假设被拒，给出**视觉证据 + 协变量敏感性 + 异质性估计 + Honest DiD 上下界的对照三角化**；不应隐藏或回避。

**关键提醒**：平行趋势被拒 ≠ DID 估计一定错，但意味着"因果解读"需要更强论证。

## 关键陷阱速查

1. **处理变量放错括号**：`(结局 协变量) (处理变量)`——把协变量放进第二对括号会报 `invalid treatment variable`。
   **Fix**：固定写作 `(结局 [协变量]) (处理变量)`；写完后 `assert _did_tvar` 看处理变量是否被正确识别；多模型时用 `estimates table, b(%9.3f) star` 核对每模型 ATET。
2. **`estat trends` 不存在**：事前趋势检验命令是 `estat ptrends`。
   **Fix**：只可能输错；自检 `help estat ptrends`；找不到时报 `unrecognized command` —— 改写为 `estat ptrends` 即可。
3. **`xthdidregress` 不接受 `time()`**：报 `option time() not allowed`，先 `xtset` 即可。
   **Fix**：`xthdidregress (y) (treat), group(id)`——**不写 time()**；时间变量从 `xtset id month` 自动读取；写错就报 option not allowed。
4. **wildbootstrap 种子是 `rseed()`**：写 `seed()` 报 `invalid 'reps'` 类错误。
   **Fix**：`didregress ..., wildbootstrap(reps(99) rseed(20260816))`；不要写 `seed()`（那是 sample 命令的）；reps 默认 1000，但小样本演示用 99 / 120 也行（.025*reps 整数时更快）。
5. **`estat bdecomp` 两前提**：处理时点 ≥ 2（错时设计）+ 数据强平衡（个体级先 `collapse` 到组×期均值）。
   **Fix**：错时设计 + 先 `collapse (mean) y treat, by(group time)` 收缩到组×期均值；不足 2 个处理时点报 `insufficient treatment cohorts`；非平衡数据报 `unbalanced data not allowed`。
6. **单时点 DID 用 TWFE 没问题，错时必须换稳健估计量**：`hdidregress` / `xthdidregress`，并配合 `estat aggregation, dynamic` 看事件研究图。
   **Fix**：处理时点 ≥ 2 时禁止用 `didregress` 的 TWFE 结果；改跑 `hdidregress`（重复截面）或 `xthdidregress`（面板），必看 `estat aggregation, dynamic graph` 事件研究图；bacon 分解（`estat bdecomp`）诊断错时下 TWFE 负权重。
7. **wild bootstrap 后 `estat vce` 不允许**：官方明确禁止。
   **Fix**：wildbootstrap 后只能看原始估计表（CI 用 percentile）；要看 vce 必须去掉 `wildbootstrap()` 重跑——CI 自动回归到默认 robust。
8. **2-cluster 时 wild bootstrap CI 不可识别**：当 `group()` 变量只有 2 个聚类（如 0/1 对照/处理），Stata 报告 `lower confidence bound not found`——这是 wild bootstrap 的已知边界，**不是错误**。
   **Fix**：组数 < 5 时不用 wildbootstrap，改用 `aggregate(dlang)`（Donald-Lang 聚合，少组时更稳）；或合并同类小组合成 ≥ 5 个组；研究设计中应保证至少 5 个独立处理单元（policy group）。
9. **`xtset` 字符串变量报错**：`xtset country year` 报 `country is string variable` —— xtset 只接受数值型组变量。
   **Fix**：`encode country, gen(country_id)` 把字符串转数值（自动带值标签）；后面所有 `group()`/`absorb()`/`cluster()` 用 `country_id`。
10. **平行趋势假设被拒的处理**：实操里 `estat ptrends` 报 p < 0.05 是常事——直接放弃 DID 是过度反应。
   **Fix**：按优先级（详见第 11 节）：(1) 看 `estat trendplot` 判断是"真趋势差"还是"数据噪音"；(2) 加协变量平衡趋势差；(3) 改用 `hdidregress aipw` 或 `xthdidregress aipw`；(4) 诚实报告 + 三角化论证，**不要简单加更多控制变量**（可能引入 bad control）。
11. **`reghdfe` 旧代码迁移到 `hdidregress`**：`reghdfe y (time_to_event*), absorb(...) cluster(...)` 是 Stata 17 主流写法；Stata 18+ 可改用 `hdidregress aipw (y) (treat), group(id) time(t)`，结果在代数上不等价（异质性估计 vs 平均 TWFE）——不能直接说"一样的"。
   **Fix**：迁移时在论文方法节明示；保留旧 `reghdfe` 输出作对照；不要混用两套估计量报同一个政策效应。

## 验证

- 本 skill 全部内置命令语法经 `verify/verify-did.do` 在 Stata 19.5（StataNow MP）批处理模式实测通过；数据全部本地模拟（`set seed` 固定），不依赖网络与额外 `.dta`。
- 运行：`bash verify/run-verify.sh did`（默认）；全量六个 skill：`bash verify/run-verify.sh`。
- 真实研究中需注意：2-cluster 演示场景（如医院 0/1）跑 wildbootstrap 会报 CI 不可识别，应改用 `aggregate(dlang)`——见第 8 条陷阱。
