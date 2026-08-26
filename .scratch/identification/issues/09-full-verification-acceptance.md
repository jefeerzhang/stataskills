# 09 — 全量验证、raw logs 与 ADR Accepted

**What to build:** 完成最终集成验证，生成两个新 raw verify logs，并在全部 Acceptance 条件通过后将 ADR-0006 从 Proposed 改为 Accepted。

**Blocked by:** 08 — 仓库文档、CI、claims 与社区 sentinel 同步

**Status:** ready-for-agent

- [ ] `test-prompts.sh`、`test-harness.sh`、`check-claims.sh` 和 static verify 全部退出 0。
- [ ] selection 与 identification 两个单项 verify 均通过。
- [ ] 全量 verify 报告 10/10 PASS。
- [ ] 两个新 raw logs 生成并按项目规则保留。
- [ ] README 仅在完整证据产生后更新“本机实测 10/10 PASS”。
- [ ] Acceptance checklist 全部满足后，ADR-0006 才改为 Accepted。
- [ ] Ticket 1–8 不得在最终集成验证前独立发布或合并。
