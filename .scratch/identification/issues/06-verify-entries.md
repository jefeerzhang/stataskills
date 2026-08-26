# 06 — Selection 与 identification 验证入口

**What to build:** 两个新 skill 都有可执行 verify；selection verify 能验证数据契约、IPWRA、balance、overlap、官方 PSM、`psmatch2`、IPW、NN、ebalance 和结果表。

**Blocked by:** 02 — 教学数据与数据治理；03 — `stata-selection` 主 skill 与 8 个 references；04 — `stata-identification` router 与 3 个 references

**Status:** complete

- [x] 两个 verify 文件都有合法文件级 VERIFY CONTRACT 和正确 version 入口。
- [x] selection verify 检查 exact varlist、原始失衡、IPWRA ATET 数值和 postestimation 模型归属。
- [x] 官方 PSM、IPW、NN 均显式使用 ATET 并存储估计结果。
- [x] `psmatch2` 有独立 optional section、安装/语法契约和 optional sentinel；缺包双模式 PASS，真实 Stata 错误 FAIL。
- [x] ebalance optional section 保持状态保护、权重断言和 optional sentinel 契约。
- [x] 主结果表保持原尺度，平衡结果作为独立带标题的 verify log 输出。
- [x] identification verify 覆盖共同假设与 estimand 的可执行示例。

## 实测证据（2026-08-26）

- 红灯基线：`bash verify/run-verify.sh --static` 在两个入口缺失时返回 1，报告 `verify-selection` 与 `verify-identification` 缺文件。
- Selection：Stata MCP 因安全策略禁止 wrapper 内嵌 `do`，故使用仅额外加入 harness cwd `cd` 的临时副本运行正式脚本内容；完整日志到达一次 `end of do-file`，无 Stata return-code error。处理率 `0.253500`；原始 abs SMD（x1–x4）为 `0.431167/0.475731/0.027161/0.444719`；raw y difference `1.460681`；IPWRA/PSM/IPW/NN ATET 分别为 `0.501678/0.552144/0.538496/0.444796`。
- Optional installed branches：本机 `psmatch2` 默认 ATT `0.529915`、`r(seatt)=0.119034`、ATE `0.593829`，并确认 `_weight`/`_support`；`ebalance` 默认 `_webal` 与 `generate(ebw_verify)` 两条均 `e(convg)==1` 且权重非缺失、非负。缺包分支只含对应 optional sentinel，真实估计命令未用 `capture` 包裹。
- Identification：Stata MCP 直接运行正式 do-file，完整日志到达一次 `end of do-file`，无 Stata return-code error。随机处理率 `0.495500`，已知 ATE/ATET 均为 `0.500000`，随机化 DGP 下的回归 ATET 恢复值 `0.450181`（robust SE `0.044457`），no-interference 明示为 DGP constraint，power/precision 单列。
- 静态验收：`bash verify/run-verify.sh --static` 返回 0；动态发现两个新 1:1 入口，汇总 `11 通过，0 失败`。
- 本票未生成或提交正式 `verify/*.log`；正式 raw logs 留给 Ticket 09。
