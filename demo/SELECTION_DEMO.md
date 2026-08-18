# DID 方法选择 Demo

本 demo 测试 `stata-did` skill 的**方法自动选择能力**：给定用户场景描述，AI 能否正确推荐最合适的 DID 估计量。

## 测试场景

### 场景 1：简单 2x2 DID

**用户提示词**：
> "我有一组医院数据，想评估某项政策对患者满意度的影响。政策在 2020 年 1 月对部分医院实施，我有 2019-2021 年的月度数据。"

**AI 应该做的诊断**：
1. 数据结构：面板（同一批医院跟踪多期）
2. 处理时点：单时点（2020 年 1 月）
3. 处理单位：部分医院（非全部）

**推荐方法**：`xtdidregress`（面板单时点 DID）

**理由**：单时点 + 面板数据 → 官方内置命令最简单，estat 诊断丰富

**生成的 Stata 代码**：
```stata
xtset hospital_id month
xtdidregress (satisfaction) (treated), group(hospital_id) time(month)
estat trendplot
estat ptrends
```

---

### 场景 2：错时 DID（默认推荐）

**用户提示词**：
> "我有 500 个县的面板数据，想评估一项就业政策的效果。不同县在不同年份实施了这个政策（有的 2015 年，有的 2018 年），有的县从未实施。"

**AI 应该做的诊断**：
1. 数据结构：面板（500 个县）
2. 处理时点：错时（不同县不同年份）
3. 处理单位：多个（非少数）
4. 对照组：有 never-treated（从未实施的县）

**推荐方法**：`hdidregress aipw`（默认推荐，官方内置）

**理由**：错时 + 面板 + 多处理单位 → 需要异质性稳健估计量；`hdidregress aipw` 是官方内置，estat 诊断丰富

**生成的 Stata 代码**：
```stata
xtset county year
hdidregress aipw (employment) (treated), group(county) time(year)
estat aggregation, overall
estat aggregation, cohort
estat aggregation, dynamic graph
estat atetplot
```

---

### 场景 3：错时 DID + 计数结果变量

**用户提示词**：
> "我想评估某政策对医院就诊次数的影响。数据是面板，不同医院在不同时间接受了干预。就诊次数是计数数据（0, 1, 2, ...）。"

**AI 应该做的诊断**：
1. 数据结构：面板
2. 处理时点：错时
3. 结果变量类型：计数数据（非连续）

**推荐方法**：`jwdid method(poisson)`（唯一支持非线性模型）

**理由**：计数数据 → 需要 poisson 回归 → `jwdid` 是唯一支持非线性模型的 DID 估计量

**生成的 Stata 代码**：
```stata
xtset hospital_id year
jwdid visits x, ivar(hospital_id) tvar(year) gvar(first_treat) method(poisson) group
estat simple
estat event
estat plot
```

---

### 场景 4：错时 DID + 想要最精确的标准误

**用户提示词**：
> "我有面板数据，错时处理。我想确保标准误估计准确，特别是有限样本下的方差修正。审稿人可能会问我的推断是否稳健。"

**AI 应该做的诊断**：
1. 数据结构：面板
2. 处理时点：错时
3. 用户需求：方差修正（有限样本）

**推荐方法**：`did_imputation, leaveout`（唯一实现 BJS 附录 A.9 方差修正）

**理由**：用户明确要求有限样本方差修正 → `leaveout` 是唯一实现

**生成的 Stata 代码**：
```stata
replace first_treat = . if never_treated  // 注意：Ei 用缺失表示从未处理
did_imputation y id year first_treat, horizons(0/5) leaveout autosample
did_imputation y id year first_treat, pretrends(5)  // 平行趋势检验
```

---

### 场景 5：少数处理单位

**用户提示词**：
> "我想评估加州某项控烟政策的效果。只有加州一个州实施了政策，其他 38 个州没有。我有 1970-2000 年的数据。"

**AI 应该做的诊断**：
1. 数据结构：面板
2. 处理单位：只有 1 个（加州）
3. 对照组：38 个未处理的州

**推荐方法**：`synth`（合成控制法）

**理由**：只有 1 个处理单位 → DID 的平行趋势假设很难令人信服 → 合成控制法从捐赠池构建合成对照

**生成的 Stata 代码**：
```stata
ssc install synth, replace
use synth_smoking.dta, clear
tsset state year
synth cigsale beer(1984(1)1988) lnincome(1972(1)1988) retprice age15to24 ///
      cigsale(1988) cigsale(1980) cigsale(1975), ///
      trunit(3) trperiod(1989) xperiod(1980(1)1988) nested
```

---

## 测试方法

1. 将上述用户提示词输入给 AI（加载 `stata-did` skill）
2. 观察 AI 是否：
   - 正确诊断数据结构（面板/截面/重复截面）
   - 正确识别处理时点（单时点/错时）
   - 正确推荐估计量
   - 生成正确的 Stata 代码
3. 记录 AI 的实际表现，与预期对比

## 预期结果

如果 skill 的方法选择逻辑正确，AI 应该：
- 场景 1 → `xtdidregress`
- 场景 2 → `hdidregress aipw`
- 场景 3 → `jwdid method(poisson)`
- 场景 4 → `did_imputation, leaveout`
- 场景 5 → `synth`

## 记录模板

| 场景 | 用户提示词 | AI 推荐方法 | 是否正确 | 生成代码是否正确 | 备注 |
|------|-----------|------------|---------|----------------|------|
| 1 | 简单 2x2 DID | | | | |
| 2 | 错时 DID（默认） | | | | |
| 3 | 错时 + 计数结果 | | | | |
| 4 | 错时 + 方差修正 | | | | |
| 5 | 少数处理单位 | | | | |
