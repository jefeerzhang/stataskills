# 03 — `stata-selection` 主 skill 与 8 个 references

**What to build:** 用户可以完成横截面、二元处理、selection-on-observables 分析；主路径使用 IPWRA/ATET，并能分别查阅官方匹配、社区 `psmatch2`、NN、IPW、IPWRA、balance/overlap、ebalance 和论文写作说明。

**Blocked by:** 01 — ADR-0006 与实施基线；02 — 教学数据与数据治理

**Status:** ready-for-agent

- [ ] 主 skill 的强制路径从设计 gate、原始检查开始，以 IPWRA ATET 为默认主估计。
- [ ] 官方 `teffects psmatch` 与社区 `psmatch2` 分别拥有独立 reference。
- [ ] `psmatch2` reference 覆盖安装、常用匹配语法、ATT/ATE、权重/匹配样本、标准误和限制。
- [ ] 文档明确 `psmatch2` 是社区敏感性/兼容性对照，不优于 IPWRA，也不是默认主估计。
- [ ] 八个 selection references 的职责互不重复，包含可选 ebalance 和论文表述边界。
- [ ] 新 skill 遵守 frontmatter、version、错误码、强制路径、运行方式、陷阱和禁令惯例。
