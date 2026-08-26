# 07 — Agent 路由行为回归

**What to build:** Agent 行为回归集能够审计通用 router、方法直达、分支选择和失败回退，不依赖 prompt 顺序或自然语言猜测。

**Blocked by:** 04 — `stata-identification` router 与 3 个 references；05 — 现有方法边界与 sdid references

**Status:** complete

- [x] JSON 合法，实际 10 个 skill 全覆盖。
- [x] `route_branch` 覆盖 router-entry、RCT、RDD、IV、standard DID、synth/sdid、selection、stop-causal、named-method-direct 和 gate-failure-return。
- [x] named-method 明确点名 `psmatch2` 时直达 `stata-selection` 并进入社区 reference。
- [x] standard DID parallel trends 失败时，行为回归先检查 synth/sdid，而不是直接转 selection。
- [x] `verify/test-prompts.sh` 从实际 skill 目录动态派生 expected skill，不保留固定 8 或固定 10 数组；skill 与 route_branch 均做双向精确集合检查，锁定 branch 各恰好一条。
- [x] 每条 route contract 锁定 `expected_actions` 数量，并按 action 索引逐项检查语义锚点，不跨 action 聚合；缺失、null、非数组、空数组、非字符串或空字符串均失败。
- [x] CI prompts 检查准确区分 `expected_actions` 合同审计与 `expected_outputs` 文档/日志搜索。

**Evidence:** `bash verify/test-prompts.sh`、JSON parser、shell syntax、action 位置/数量及异常 fixture 拒绝探针与 jq/Python 静态一致性检查通过；`--prompts` 未运行，因其会进入 Stata/社区包执行层。
