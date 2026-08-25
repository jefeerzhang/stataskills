---
name: stata-did
description: Stata 内置 DID 命令族：didregress / xtdidregress / hdidregress / xthdidregress，含平行趋势检验、事件研究、DDD、wild bootstrap。全部内置，无需 ssc install。触发词：DID / 双重差分 / 政策评估 / 错时处理 / 平行趋势 / 事件研究。
compatibility: >-
  适配 Claude Code / Codex / OpenClaw / SkillsMP；StataNow 19.5 MP（macOS / Windows / Linux）实测 PASS；
  触发即读本文，无需联网加载其他文件。  全部内置（didregress / xtdidregress / hdidregress / xthdidregress，StataNow 19.5 自带）。
---

# Stata 双重差分：didregress 命令族（DID / DDD / 错时处理）

本 skill 对应 Stata 官方 DID 命令族（源自 Stata 19 宣传单 [Causal inference: Difference-in-differences] 的命令体系）：`didregress`、`xtdidregress`、`hdidregress`、`xthdidregress` 及 `estat` 事后诊断，全部为**内置命令**，无需 `ssc install`。社区包（reghdfe / eventdd / csdid / jwdid / did_imputation / synth / sdid）见 `stata-did-community` skill。