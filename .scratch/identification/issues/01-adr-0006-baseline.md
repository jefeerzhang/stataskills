# 01 — ADR-0006 与实施基线

**What to build:** 固化四个识别方法支柱、横切 router、DID/synth/sdid 分支、selection 范围、独立 `psmatch2` reference、数据治理和最终 Acceptance 门。

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] ADR-0006 保持 Proposed，并准确记录 8 → 10 skills 的架构变化。
- [ ] 明确 `psmatch2` 是独立社区 reference，不是 legacy-only 指针，也不是默认主估计。
- [ ] 明确 standard DID、synth 与 sdid 的不同进入条件。
- [ ] 明确项目内生成数据与外部来源数据的两分支治理规则。
- [ ] Acceptance 门自包含，覆盖结构、方法、数据依赖、验证和发布条件。
