---
name: stata-rdd
description: Stata 断点回归（RDD）：rdrobust / rdplot / rddensity，覆盖 sharp 与 fuzzy、密度操纵检验、带宽敏感性、placebo cutoff。Cattaneo 团队协议，需 ssc install。触发词：RDD / 断点回归 / regression discontinuity / 分数线 / 年龄门槛 / 地理边界 / rdrobust / 操纵检验。
compatibility: >-
  适配 Claude Code / Codex / OpenClaw / SkillsMP；StataNow 19.5 MP（macOS / Windows / Linux）实测 PASS；
  触发即读本文，无需联网加载其他文件。  必装：ssc install rdrobust rdplot rddensity（Cattaneo 团队协议）。
---

# Stata 断点回归：rdrobust 命令族（RDD / sharp / fuzzy）

**本仓库唯一识别策略是 DID（`stata-did` / `stata-did-community`）。** RDD 是**第二根独立支柱**——处理由一个**运行变量的阈值**决定，不是由时间决定。两者识别框架不同，**不要混用**（详见「强制路径 / 踢走」）。