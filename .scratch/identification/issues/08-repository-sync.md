# 08 — 仓库文档、CI、claims 与社区 sentinel 同步

**What to build:** README、AGENTS、贡献指南、引用元数据、CLAUDE、CI、harness 和 claims 统一使用 10-skill/10-verify/6-ADR 当前态，并能验证两个社区包 sentinel。

**Blocked by:** 03 — `stata-selection` 主 skill 与 8 个 references；05 — 现有方法边界与 sdid references；06 — Selection 与 identification 验证入口；07 — Agent 路由行为回归

**Status:** ready-for-agent

- [ ] 当前活跃文档与 CI 元数据统一反映 10 skills、10 verify 和 6 ADR。
- [ ] README 的实测 10/10 PASS 声明只在最终全量验证后更新。
- [ ] `CLAUDE.md` 修改前先读取工作区当前内容，最小合并用户未提交改动。
- [ ] 项目内生成数据和外部来源数据的两分支治理说明同步到 AGENTS 与 manifest-extra 顶部。
- [ ] `verify/check-claims.sh` 动态检查 skill、prompt、ADR 和 badge 计数。
- [ ] `verify/test-harness.sh` 验证 ebalance 和 `psmatch2` optional sentinel 的双模式行为，并确保真实错误不被 sentinel 掩盖。
- [ ] 历史快照文档不被错误回写。
