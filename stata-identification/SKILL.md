---
name: stata-identification
description: Use when choosing among randomized assignment, RDD, IV, panel-policy designs, DID, synth/sdid, and cross-sectional selection-on-observables, or deciding whether causal language is defensible; triggers include identification strategy, causal design, can I claim causality, and which method should I use.
compatibility: >-
  适配 Claude Code / Codex / OpenClaw / SkillsMP；面向 StataNow 19.5 MP（macOS / Windows / Linux）。
  本 skill 是跨设计 router，不执行方法估计；正式行为 prompts 与 verify 属 Ticket 06/07 的发布 gate。
---

# Stata 识别策略 router

本 skill 只负责先定义问题、顺序检查识别设计并路由；它不是第五种估计方法。变量名、数据列、面板形状和政策关键词只能触发提问，不能替代随机化记录、制度规则、时间线或其他可辩护设计证据。

```stata
version 19.5
```

## 1. 运行 Stata 的方式

- router 判断本身不需要运行 Stata；先记录 treatment、outcome、unit、时间结构、处理时点、目标总体与 estimand，再读 decision tree。
- 若后续方法 skill 需要批处理，使用 `stata-mp -b do "脚本.do"`；Windows 等价路径见 `docs/run-stata.md`。
- 本 ticket 不运行 RCT、RDD、IV、DID 或 selection 估计。共同假设的简单模拟与断言由后续 `verify/verify-identification.do`（Ticket 06）验证；自然语言路由由 Ticket 07 的 prompts 验证。

## 2. 强制路径

匹配到第一条就停；完整进入条件、关键假设、失败去向和 named-method 判断细节只读 [identification-decision-tree.md](references/identification-decision-tree.md)。

1. **Named method 直达**：用户明确点名 DID / 事件研究 / `csdid` / `jwdid` / `synth` / `sdid`、RDD / `rdrobust`、IV / 2SLS / `ivregress` / `ivreg2` / LATE，或 PSM / `psmatch2` / IPW / IPWRA / `teffects` / entropy balancing / `ebalance` 时，直接进入权威表指定的方法 skill，不先绕 router。明确点名 `psmatch2` 时先进入 `stata-selection` 并执行设计 gate；gate 通过后才读 `stata-selection/references/psmatch2.md`。任何方法本地 gate 失败后返回本 router。
2. **通用设计选择**：用户问“该选什么设计”“能否识别”或只给数据形状 / 政策关键词时，先定义 treatment、outcome、unit、时间、目标总体和 estimand，再按高层顺序检查：随机分配 → RDD → IV → 面板政策公共 gate（standard DID 或 `synth` / `sdid`）→ 横截面 selection → stop causal。不得凭关键词跳支柱。
3. **共同假设审计**：路由到方法后，读 [identification-common-assumptions.md](references/identification-common-assumptions.md)，逐项区分共同假设、设计特定假设与 power / precision。
4. **论文表述**：只有对应 gate 可辩护时，才按 [identification-paper-writing.md](references/identification-paper-writing.md) 写 estimand、机制、证据、限制、目标总体与外推边界；否则停止因果措辞。

## 3. 高层路由入口

| 请求 | 首个入口 | 本地失败动作 |
|---|---|---|
| 通用设计选择 / 因果解释审计 | 本 skill → decision tree | 按权威 stop rules 继续或停止因果声明 |
| DID / 事件研究 | `stata-did` | standard DID 未通过时先检查同支柱的 `synth` / `sdid`；两者均不成立再返回本 router |
| `csdid` / `jwdid` / `synth` / `sdid` | `stata-did-community` | 返回本 router |
| RDD / 断点 / `rdrobust` | `stata-rdd` | 返回本 router |
| IV / 2SLS / `ivregress` / `ivreg2` / LATE | `stata-regression` 的 IV references | 返回本 router |
| PSM / IPW / IPWRA / `teffects` / entropy balancing / `ebalance` | `stata-selection` | 返回本 router |
| `psmatch2` | 先进入 `stata-selection` 并执行设计 gate；通过后读 `stata-selection/references/psmatch2.md` | gate 失败返回本 router |

具体 named-method ownership 与失败动作以 decision-tree 的三列表为准。

## 4. 详细参考（references/）

| 文件 | 唯一职责 |
|---|---|
| [identification-decision-tree.md](references/identification-decision-tree.md) | 完整且唯一的顺序化 stop rules、named-method ownership 与失败去向 |
| [identification-common-assumptions.md](references/identification-common-assumptions.md) | 共同识别假设，以及 power / precision 的分离 |
| [identification-paper-writing.md](references/identification-paper-writing.md) | 可审计的论文识别表述、诊断边界与外推边界 |

references 数量固定为 3；完整树不得复制到本文件或其他运行时材料。

## 5. 关键陷阱速查

统一格式：**陷阱 → 触发 → Fix → 验证**。

1. **关键词直接路由** → **触发**：看到 `cutoff`、`instrument`、`policy_year` 或协变量列便宣布设计成立 → **Fix**：把列名只当检查触发器，要求随机化记录、制度机制、时间线或设计证据 → **验证**：路由记录同时列出“数据中观察到什么”和“哪项外部证据支持假设”。
2. **诊断等于证明** → **触发**：balance、pretrend、density、first-stage 或 overidentification 检验不显著 / 显著后宣布识别成立 → **Fix**：只写“支持性诊断”，另列诊断不能证明的假设 → **验证**：论文没有“检验证明 exchangeability / exclusion / no manipulation”等措辞。
3. **无可信设计仍写因果** → **触发**：所有 gate 失败后改跑普通回归并称为 effect → **Fix**：降级为描述或关联，明确停止因果声明 → **验证**：结果用 association / difference，不用 effect / impact / caused。
4. **把 MDE 当识别** → **触发**：因样本量大、SE 小或 MDE 小而声称无偏 → **Fix**：把 MDE、sample size、SE、CI 单列为 power / precision → **验证**：识别假设表不含这些精度指标。
5. **复制完整树** → **触发**：在主 skill 或方法 skill 重写所有 branches → **Fix**：只留高层入口和 decision-tree pointer → **验证**：运行时范围内完整 stop-rules marker 唯一。

## 6. 可执行禁令

- ❌ **禁止**凭变量名、数据列或关键词直接选择方法；**替代**：打开 decision tree，逐项要求可辩护的制度 / 设计证据。
- ❌ **禁止**把 balance、pretrend、density、first-stage 或 overidentification 诊断写成识别假设已被证明；**替代**：写成支持性证据，并明确不可检验部分。
- ❌ **禁止**在没有可信识别设计时继续使用因果措辞；**替代**：只报告描述或关联，或重新设计研究。
- ❌ **禁止**把 MDE、样本量、标准误或置信区间宽度列为识别条件；**替代**：放入 power / precision 小节。
- ❌ **禁止**在本文件或其他方法 skill 复制完整 stop rules；**替代**：只保留高层入口并指向 `identification-decision-tree.md`。
- ❌ **禁止**让 named-method 请求先绕 router；**替代**：直达方法 skill，只有本地 gate 失败才返回 router。
- ❌ **禁止**让 `psmatch2` 绕过 selection 设计 gate；**替代**：先执行 `stata-selection` gate，通过后再读社区 reference。

## 7. 错误码速查（错误码 → 触发 → 修复）

识别 gate 失败是研究设计结论，不是 Stata return code；不得虚构或映射成 `r(#)`。

- **`r(198)`** — 常见的语法 / 选项错误信号；**修复**：读取完整错误文本并查对应方法 help，不能据此判断识别失败；**验证**：保存触发命令、原始错误文本与最小复现。
- **`r(2000)`** — 常见的无可用观测信号；**修复**：检查缺失、筛选和共同样本，不能据此推断 positivity 或 exchangeability 的唯一原因；**验证**：记录可用样本计数与筛选条件。
- **`r(498)`** — 多种命令用于“不满足当前命令条件”的保守信号；**修复**：按具体命令读取完整错误文本与 help，不把它解释为某项识别假设被拒；**验证**：记录命令上下文和修复后 return code。

## 8. 发布 gate

本 Ticket 04 只交付 router 文档和 3 个 references。正式行为 prompts、`verify/verify-identification.do`、Stata 实测日志以及全量发布声明分别由 Ticket 06/07 及后续发布 gate 承担；在这些证据完成前，不宣称完整行为回归或 Stata verify 已通过。

## ✅ 交付前自检清单（跑完命令后逐条核对）

- [ ] 路由依据：named-method 直达对应方法 skill 并执行本地 gate；通用选择走了 decision tree，未凭变量名/关键词跳分支
- [ ] 进入方法前先定义 treatment、outcome、unit、时间结构、处理时点、目标总体与 estimand
- [ ] 每个放弃/选中的支柱都同时列出「数据中观察到什么」与「哪项外部制度/设计证据」；gate 失败去向符合同支柱顺序（标准 DID → synth/sdid → router）
- [ ] 论文表述：只有 gate 可辩护才用因果措辞（effect/impact/caused）；否则用 association/difference 并停止因果声明
- [ ] 诊断未被写成识别证明（balance/pretrend/density/first-stage/overidentification 均为支持性证据）；power/precision 单列
- [ ] 未在本文件或其他 skill 复制完整 stop rules（decision tree 保持唯一）；发布 gate 证据（prompts/verify）未被提前宣称
