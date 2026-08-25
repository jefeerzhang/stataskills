---
name: stata-did-community
description: Stata DID 社区包（9 个方法）：csdid / jwdid / did_imputation / synth / sdid / did_multiplegt(DCDH) / stacked / lpdid / reghdfe 事件研究。含决策树路由和特征对照矩阵。触发词：DID 社区包 / csdid / jwdid / 合成控制 / 可逆处理 / 局部投影 / 堆叠 DID。
compatibility: >-
  适配 Claude Code / Codex / OpenClaw / SkillsMP；StataNow 19.5 MP（macOS / Windows / Linux）实测 PASS；
  触发即读本文，无需联网加载其他文件。  需装 csdid / drdid / jwdid / hdfe / reghdfe / did_imputation / synth / stacked / lpdid（按方法选装）。
---

# Stata 双重差分：社区包（reghdfe / csdid / jwdid / did_imputation / synth / sdid / did_multiplegt / stacked / lpdid）

本 skill 覆盖主流 DID 社区包，需 `ssc install`。Stata 内置 DID 命令（`didregress` / `xtdidregress` / `hdidregress` / `xthdidregress`）见 `stata-did` skill。