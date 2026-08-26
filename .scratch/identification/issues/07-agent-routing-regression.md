# 07 — Agent 路由行为回归

**What to build:** Agent 行为回归集能够审计通用 router、方法直达、分支选择和失败回退，不依赖 prompt 顺序或自然语言猜测。

**Blocked by:** 04 — `stata-identification` router 与 3 个 references；05 — 现有方法边界与 sdid references

**Status:** ready-for-agent

- [ ] JSON 合法，实际 10 个 skill 全覆盖。
- [ ] `route_branch` 覆盖 router-entry、RCT、RDD、IV、standard DID、synth/sdid、selection、stop-causal、named-method-direct 和 gate-failure-return。
- [ ] named-method 明确点名 `psmatch2` 时直达 `stata-selection` 并进入社区 reference。
- [ ] standard DID parallel trends 失败时，行为回归先检查 synth/sdid，而不是直接转 selection。
- [ ] `verify/test-prompts.sh` 从实际 skill 目录动态派生 expected skill，不保留固定 8 或固定 10 数组。
- [ ] CI prompts 检查不再保留旧的 8-skill 文案。
