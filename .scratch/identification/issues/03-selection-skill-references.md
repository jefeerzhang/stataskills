# 03 — `stata-selection` 主 skill 与 8 个 references

**What to build:** 用户可以完成横截面、二元处理、selection-on-observables 分析；主路径使用 IPWRA/ATET，并能分别查阅官方匹配、社区 `psmatch2`、NN、IPW、IPWRA、balance/overlap、ebalance 和论文写作说明。

**Blocked by:** 01 — ADR-0006 与实施基线；02 — 教学数据与数据治理

**Status:** complete

### 静态与文档验收

- [x] 主 skill 的强制路径从 adjustment-set gate、原始检查开始，以 IPWRA ATET 为默认主估计。
- [x] 官方 `teffects psmatch` 与社区 `psmatch2` 分别拥有独立 reference。
- [x] `psmatch2` reference 准确区分默认 treated-effect/ATT 语义与 `ate` 选项，并覆盖安装授权、权重/匹配样本、标准误和限制。
- [x] 八个 selection references 职责分离，通用 balance/overlap 路径集中维护，NN 不调用 `tebalance`。
- [x] `ebalance` reference 包含已核实语法、`_webal`/`ebw_verify` 非负断言、`generate()`、convergence、`e(sample)`、状态保护与 sentinel。
- [x] NN reference 包含已核实 metric、bias adjustment、neighbor/ties、有效样本与 VCE 边界，且无 `tebalance`。
- [x] 新 skill 遵守 frontmatter、version、错误码、强制路径、陷阱和禁令惯例。

### 待正式 verify（Ticket 06）

- [x] 用正式教学 `.dta` 的 `preserve` 临时副本实测 `psmatch2` 最小 ATE；v4.0.12 返回 ATE/ATT/ATU，并生成匹配权重与支持对象。
- [x] 用正式教学 `.dta` 的 `preserve` 临时副本实测 `ebalance` 默认 `_webal` 与 `generate(ebw_verify)` 两条路径，均 `e(convg)==1`，并在 e(sample) 内验证非负。
- [x] 用正式教学 `.dta` 的 `preserve` 临时副本实测 NN `biasadj()` + `metric(mahalanobis)` + `vce(robust, nn(2))` + `osample()`；估计成功并存储。
- [x] `verify/verify-selection.do` 覆盖两个 optional 包、NN 契约及真实错误 FAIL；Ticket 06 已完成并通过 Stata 19.5 实测。
