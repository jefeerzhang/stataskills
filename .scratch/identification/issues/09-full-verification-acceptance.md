# 09 — 全量验证、raw logs 与 ADR Accepted

**What to build:** 完成最终集成验证，生成两个新 raw verify logs，并在全部 Acceptance 条件通过后将 ADR-0006 从 Proposed 改为 Accepted。

**Blocked by:** 08 — 仓库文档、CI、claims 与社区 sentinel 同步

**Status:** complete

- [x] `test-prompts.sh`、`test-harness.sh`、`check-claims.sh` 和 static verify 全部退出 0。
- [x] selection 与 identification 两个单项 verify 均通过。
- [x] 全量 verify 报告 10/10 PASS。
- [x] 两个新 raw logs 生成并按项目规则保留。
- [x] README 仅在完整证据产生后更新“本机实测 10/10 PASS”。
- [x] Acceptance checklist 全部满足后，ADR-0006 才改为 Accepted。
- [x] Ticket 1–8 未在最终集成验证前独立发布或合并。

## Verification evidence — 2026-08-26

- `bash verify/test-prompts.sh`: 38 passed, 0 failed.
- `bash verify/test-harness.sh`: all 5 probes passed.
- `bash verify/check-claims.sh`: 42 passed, 0 failed; facts report 10 skills, 10 targets, 6 ADRs, and 27 prompts.
- `bash verify/run-verify.sh --static`: 11 passed, 0 failed.
- `bash verify/run-verify.sh`: 10 passed, 0 failed; `verify-selection` and `verify-identification` reached `end of do-file` with no return-code error.
