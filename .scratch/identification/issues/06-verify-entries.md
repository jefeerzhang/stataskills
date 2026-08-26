# 06 — Selection 与 identification 验证入口

**What to build:** 两个新 skill 都有可执行 verify；selection verify 能验证数据契约、IPWRA、balance、overlap、官方 PSM、`psmatch2`、IPW、NN、ebalance 和结果表。

**Blocked by:** 02 — 教学数据与数据治理；03 — `stata-selection` 主 skill 与 8 个 references；04 — `stata-identification` router 与 3 个 references

**Status:** ready-for-agent

- [ ] 两个 verify 文件都有合法文件级 VERIFY CONTRACT 和正确 version 入口。
- [ ] selection verify 检查 exact varlist、原始失衡、IPWRA ATET 数值和 postestimation 模型归属。
- [ ] 官方 PSM、IPW、NN 均显式使用 ATET 并存储估计结果。
- [ ] `psmatch2` 有独立 optional section、安装/语法契约和 optional sentinel；缺包双模式 PASS，真实 Stata 错误 FAIL。
- [ ] ebalance optional section 保持状态保护、权重断言和 optional sentinel 契约。
- [ ] 主结果表保持原尺度，平衡结果作为独立带标题的 verify log 输出。
- [ ] identification verify 覆盖共同假设与 estimand 的可执行示例。
