# ADR-0005：保留完整 verify log 随仓库提交；不替换为稳定摘要

## 背景

架构评审曾提出候选「用稳定 snapshot 代替 tracked raw logs」：把 `verify/*.log`（完整 Stata 会话记录）替换为一个小而稳定的「验证证据摘要」，原始 log 只留临时目录。评审指出 `verify/*.log` 约九成是环境噪声（Stata 版本横幅、许可/序列号、绝对路径、echo 行），一次小逻辑改动即可触发数百行 log diff（如 `de68073`：verify-coefplot.log 462 行、verify-rdd.log 432 行），掩盖真正的验证语义。

## 决策

**不采纳该候选。** `verify/*.log` 继续随仓库提交完整 Stata 输出（`run-verify.sh` 的 `evaluate` 保持 `cp` 原始 log 到 `verify/<name>.log`，即「最近一次验证状态」）。不引入 normalizer，不把原始 log 降级到临时目录。

## 理由（load-bearing）

1. **可追溯性优先于 review 整洁度**：保留完整 transcript，git 里能追溯「这台机器当时实际跑了哪条命令、完整输出了什么」。这是 reviewer / 审计需要的原始证据，摘要会丢失这些细节。
2. **用户明确选择**：在「提交摘要 vs 保留完整 log」的取舍上，用户明确选择保留完整 log。这是终局决策，不是忽略。

## 后果

- 跨平台 diff 噪声持续存在：macOS / Windows 重跑会因路径、许可、版本横幅不同产生大量无关改动，review 需从噪声中辨认真正的语义变化。
- `verify/*.log` 体积偏大（verify-coefplot.log 83KB、verify-regression.log 20KB），会持续贡献仓库体积与 diff 噪音。
- 维护负担维持现状：无需新增 normalizer 对齐 log 格式；也无需在 Stata 升级时同步维护摘要解析。

## 未来再评估

- 若日后 log 刷屏确已严重影响 review（如频繁跨平台跑验证），重新评估「提交摘要 + CI artifacts 留档原始 log」的折中路径——但需本 ADR 重新打开。
- 若 Stata 版本升级导致 log 格式变化，只影响人工阅读，不影响 harness 解析（`parse_log` 基于正则），无需联动。
