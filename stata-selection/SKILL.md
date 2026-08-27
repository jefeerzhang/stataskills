---
name: stata-selection
description: Use when estimating cross-sectional treatment effects with binary treatment and pre-treatment observed confounders under selection on observables; triggers include teffects, IPWRA, propensity-score matching, overlap, balance, ATET, and psmatch2.
compatibility: >-
  适配 Claude Code / Codex / OpenClaw / SkillsMP；StataNow 19.5 MP（macOS / Windows / Linux）。
  内置 teffects 命令无需安装；psmatch2 与 ebalance 为 optional community packages，缺包不阻断默认路径。
---

# Stata 横截面选择-on-observables（binary treatment）

本 skill 只承接横截面、二元处理、处理前可观测混杂；识别依赖 selection on observables、一致处理定义、SUTVA 与足够的 overlap/positivity。主估计固定为官方 `teffects ipwra ..., atet`，结果报告 ATET 原尺度。

```stata
version 19.5
```

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`；Windows 等价路径见 `docs/run-stata.md`。
- 示例中的 `y treat x1 x2 x3 x4` 是占位变量；执行前必须映射到真实变量并保留处理前时点。
- 需要图形时默认使用英文标签；若用户要求中文标签或标题，先询问是否确需中文。

## 强制路径

快速单方法咨询可只运行命中的相关 reference；完整 selection 分析必须执行下方锁定链。禁止的是把所有 estimator 当作多个主结果，不是跳过规范对照链。

**适用场景**：横截面或单个处理前截面，`treat` 为 0/1，混杂变量在处理前已测量。

**强制命令链**：

1. **设计 gate**：确认 treatment、outcome、estimand（默认 ATET），逐项审计 adjustment set：变量必须处理前测量且因果角色可解释；必须包含需要控制的处理前共同原因，可加入有明确精度目的的处理前 outcome predictor。禁止 mediator、post-treatment outcome、collider，以及仅为预测 treatment 而加入的 instrument。无法解释变量角色或无法辩护无未观测混杂时，停止并返回 `stata-identification` router；同时写下 overlap/positivity 与 SUTVA 的制度论证。
2. **原始检查**：
   ```stata
   tabulate treat, missing
   summarize y x1 x2 x3 x4
   misstable summarize y treat x1 x2 x3 x4
   assert inlist(treat, 0, 1) if !missing(treat)
   ```
3. **主估计（完整分析的固定起点）**：
   ```stata
   teffects ipwra (y x1 x2 x3 x4) (treat x1 x2 x3 x4), atet
   estimates store ipwra_atet
   ```
   `estimates store ipwra_atet` 必须立即跟在估计后，避免后续命令覆盖 `e()` 结果。
4. **估计后 balance**：
   ```stata
   tebalance summarize
   ```
   不要在任何 `teffects` 估计前运行 `tebalance`。
5. **估计后 overlap**：
   ```stata
   teffects overlap
   ```
   这是 postestimation 命令，不带 `atet`；`atet` 只写在估计命令上。
6. **官方对照（完整分析锁定链）**：先运行官方 `teffects psmatch` 并立即 store，再运行官方 `teffects ipw` 并立即 store；语法见对应 references。
7. **NN 额外内置敏感性对照**：最后运行 `teffects nnmatch` 并立即 store；NN 不调用通用 `tebalance`，只按 NN reference 做距离、bias-adjustment、overlap 与有效样本诊断。
8. **主表与独立 balance log**：用内置 `estimates table ipwra_atet psmatch_atet ipw_atet nnmatch_atet` 输出原尺度主结果；将 `tebalance summarize` 与 overlap 诊断单独保存/记录，不把诊断混入主效应表。

主路径中的 `tebalance` 和 `teffects overlap` 都必须发生在估计之后；`teffects overlap` 不写 `atet`，也不把 overlap 图或 balance 结果当成识别证明。

## 方法边界与识别术语

- **IPWRA**（`teffects ipwra`）同时拟合 treatment model 与 outcome regression；在 treatment model 或 outcome model 其中一个正确指定时具有双重稳健性（仍要求一致处理、无未测混杂、positivity/overlap、正确结果/处理变量定义与独立性/SUTVA）。双重稳健不是万能修复。
- **`teffects aipw`** 是 augmented inverse-probability weighting，另一个官方 AIPW estimator；不要把它简称成 IPWRA，也不要把两者输出当作同一估计量。需要比较时单独估计、单独存储并说明模型结构。
- **`hdidregress aipw`** 属于时间维度的异质性稳健 DID；它要求政策时间/组结构，不是横截面 `teffects` 的替代。时间处理或错时处理走 `stata-did`。
- 双重稳健不能修复未观测混杂、违反 SUTVA、缺乏 overlap/positivity、post-treatment controls 或错误的 treatment/outcome 定义；诊断不证明这些假设成立。

## 详细参考（references/）

| 文件 | 只承担的职责 |
|---|---|
| [teffects-psmatch.md](references/teffects-psmatch.md) | 官方 propensity-score matching |
| [psmatch2.md](references/psmatch2.md) | optional 社区 `psmatch2`，仅兼容性/敏感性对照 |
| [teffects-nnmatch.md](references/teffects-nnmatch.md) | 官方 covariate nearest-neighbor matching |
| [teffects-ipw.md](references/teffects-ipw.md) | 官方 inverse probability weighting |
| [teffects-ipwra.md](references/teffects-ipwra.md) | 官方 IPWRA 及双重稳健解释 |
| [ebalance.md](references/ebalance.md) | optional entropy balancing |
| [balance-overlap.md](references/balance-overlap.md) | balance 与 overlap/positivity 诊断 |
| [selection-paper-writing.md](references/selection-paper-writing.md) | ATET 主表、诊断、限制与外推写作 |

若问题是识别策略总路由、不可观测混杂或未覆盖的识别设计，只保留 selection 的最小边界并转交 `stata-identification`；不要在这里复制完整 identification stop rules。

## 关键陷阱速查

统一格式：**陷阱 → 触发 → Fix → 验证**。

1. **估计前运行 `tebalance`** → **触发**：尚无 treatment-effects estimation results → **Fix**：完整分析先 `teffects ipwra ...`，立即 store，再 `tebalance summarize`；对照链按 PSM → IPW → NN 顺序运行 → **验证**：log 中估计命令出现在 balance 之前，且四个模型均有 stored estimates。
2. **把 `group(treat)` 塞进 `teffects`** → **触发**：把 DID 的 group 语法带入横截面 → **Fix**：`teffects ... (treat x1 x2)`，不要 `group()` → **验证**：`help teffects ipwra` 与命令无 `group()`。
3. **使用 `eform`** → **触发**：把 ATET 当 odds ratio 或指数化系数 → **Fix**：报告 ATET 原尺度；不要 `eform` → **验证**：主表单位与 `y` 相同。
4. **把 balance 当因果证明** → **触发**：平衡后就宣称无混杂 → **Fix**：把 balance/overlap 写成诊断，并报告制度假设与限制 → **验证**：论文没有“balance proves identification”。
5. **加入 post-treatment controls** → **触发**：控制变量由处理发生后测量或受处理影响 → **Fix**：删掉，回到处理前 covariates；必要时改研究设计 → **验证**：变量时间线逐项标记为 pre-treatment。
6. **跳过完整对照链** → **触发**：完整 selection 分析只报告 IPWRA 而省略规范对照 → **Fix**：按 IPWRA → balance/overlap → 官方 PSM/IPW → NN → 分表执行；快速单方法咨询才可只运行相关 reference → **验证**：完整分析 log 中四个内置估计均有 stored estimates。

## 可执行禁令

- ❌ **禁止**在估计前运行 `tebalance`；**替代**：`teffects ipwra ...` → `estimates store ipwra_atet` → `tebalance summarize`。
- ❌ **禁止**在 `teffects` 中使用 `group(treat)`；**替代**：把处理变量放入第二个括号，并用 `atet` 指定 estimand。
- ❌ **禁止**使用 `eform` 报告本 skill 的 ATET；**替代**：主表报告 outcome 原尺度。
- ❌ **禁止**把 mediator 或 post-treatment outcome 放入 adjustment set；**替代**：使用处理前、因果角色可解释的共同原因，或有明确精度目的的处理前 outcome predictor。
- ❌ **禁止**控制 collider，或仅因其提高 treatment 预测就加入 instrument；**替代**：先画变量角色/时间线，只调整可辩护的处理前共同原因；角色无法解释时返回 `stata-identification`。
- ❌ **禁止**把 balance 或 overlap 诊断当作因果识别证明；**替代**：同时陈述 selection-on-observables、positivity、SUTVA 与未观测混杂限制。
- ❌ **禁止**把所有 estimator 当作多个主结果；**替代**：完整分析按锁定对照链运行，IPWRA 是唯一预先指定主估计；快速单方法咨询才按研究问题选择相关 reference。
- ❌ **禁止**把 `psmatch2` 当默认主估计或声称优于 IPWRA；**替代**：optional 社区敏感性/兼容性对照，主结果仍为官方 IPWRA。

## 错误码速查（错误码 → 触发 → 修复）

- **`r(198)`** — 选项或括号语法错误，常见于把 `group()`、`eform` 或错误的 postestimation 选项带入；**修复**：按对应 reference 的官方语法重写，并用 `help teffects <cmd>` 核对；**验证**：估计命令无 `invalid syntax`。
- **`r(2000)`** — 没有可用观测或变量全缺失；**修复**：逐项 `misstable summarize`、检查 treatment/outcome/covariates 的共同样本；**验证**：估计前 `count if !missing(...)` 大于 0。
- **`r(459)`** — 某些 treatment-effects 数据、模型或 postestimation 条件未满足的保守信号，不能仅凭错误码断定是 overlap；**修复**：读取完整错误文本，检查共同样本、处理组支持、模型设定与对应 help；**验证**：记录触发命令、原始错误文本和修复后的重新运行结果。
- **`r(498)`** — 某些估计或 postestimation 条件未满足的保守信号，不能仅凭错误码断定唯一原因；**修复**：确认估计结果仍归属于目标模型、没有被覆盖，并按对应 help 检查数据与选项；**验证**：保留最小复现命令及成功/失败 return code。

## 验证

- 内置命令示例必须在 Stata 19.5 临时副本/教学数据上试跑；不要运行会覆盖 `.dta` 的 build。
- `psmatch2`、`ebalance` 示例标记为 optional；只有包存在时才实测，缺包应使用 `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__` sentinel，不阻断默认路径。

## ✅ 交付前自检清单（跑完命令后逐条核对）

- [ ] 设计 gate：treatment/outcome/estimand（ATET）明确；adjustment set 全部处理前测量且因果角色可解释（无 mediator/post-treatment/collider/instrument 混入）
- [ ] 锁链顺序：`teffects ipwra ..., atet` → 立即 `estimates store ipwra_atet` → `tebalance summarize` → `teffects overlap`（未在估计前跑 balance；overlap 未写 `atet`）
- [ ] 官方对照链完整：`teffects psmatch`、`teffects ipw`、`teffects nnmatch` 均已估计并 store；`psmatch2` 只作兼容性对照，未当主估计
- [ ] 主表 `estimates table ipwra_atet psmatch_atet ipw_atet nnmatch_atet` 为原尺度（未 `eform`）；diagnostics 单独记录
- [ ] 报告未把 balance/overlap 当识别证明；限制段写明 selection-on-observables、positivity、SUTVA 与未观测混杂
- [ ] log 恰好一次 `end of do-file`，无 `r(错误码)`（r(198)/r(2000)/r(459)/r(498) 已按错误码速查排掉）
