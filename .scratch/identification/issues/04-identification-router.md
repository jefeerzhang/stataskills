# 04 — `stata-identification` router 与 3 个 references

**What to build:** 用户可以根据研究设计进入 RCT、RDD、IV、面板政策设计、standard DID、synth/sdid、selection，或在缺少可信识别设计时停止因果声明。

**Blocked by:** 01 — ADR-0006 与实施基线

**Status:** complete（文档交付完成；正式行为 prompts / verify 仍受 Ticket 06/07 gate 约束）

- [x] Router 使用顺序化 stop rules，并区分数据形状与可辩护识别假设。
- [x] 面板政策设计先经过公共 gate，再分别判断 standard DID、synth 和 sdid。
- [x] standard DID 要求 parallel trends；synth 与 sdid 使用各自的方法条件。
- [x] 共同假设 reference 覆盖 consistency、SUTVA/no interference、design-specific exchangeability、positivity/overlap 和 estimand。
- [x] MDE、样本量、标准误和置信区间归入 power/precision，而非识别假设。
- [x] 完整 stop rules 在运行时 references 中只有一个权威副本。

## Gate

Ticket 04 只完成 `stata-identification` 文档与 3 个 references。自然语言路由行为回归由 Ticket 07 的 prompts 验证；共同假设的 Stata 可执行断言与日志由 Ticket 06 的 `verify/verify-identification.do` 验证。在这些下游 gate 完成前，不把本 ticket 的静态完成状态表述为正式行为或 Stata 实测已通过。
