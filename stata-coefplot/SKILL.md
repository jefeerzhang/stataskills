---
name: stata-coefplot
description: Stata coefplot 系数图（森林图）：多模型对比、置信区间、边际效应图、OR 图、发表级定制。触发词：coefplot / 森林图 / 系数图 / 置信区间 / 多模型对比 / margins 图。
compatibility: >-
  适配 Claude Code / Codex / OpenClaw / SkillsMP；StataNow 19.5 MP（macOS / Windows / Linux）实测 PASS；
  触发即读本文，无需联网加载其他文件。  必装：ssc install coefplot（依赖 estout，提示时一并装）。
---

# Stata 系数图：coefplot（森林图与模型对比图）

本 skill 整合 Ben Jann 的 `coefplot` 包（SSC）官方示例体系（getting-started + estimates / confidence-intervals / labelling / markers / varia），覆盖从基础系数图到发表级定制的完整方法。