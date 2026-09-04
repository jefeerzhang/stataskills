# ADR-0004：验证目标注册表作为 target → do-file / log 解析的单一来源

## 背景

`verify/run-verify.sh` 与 `verify/check-claims.sh` 中，`did-community` 的委托关系曾散落在多处：枚举排除、do-file / log 换名、`check-claims` 孤儿放行，外加占位 `verify-did-community.do`。同一份别名知识在多处重复。

## 决策

`verify/lib/targets.sh` 是验证目标解析的单一来源，暴露 **declarative target plan**：

- `targets_plan_owner <entry>` → owner skill（无 `stata-` 前缀）
- `targets_plan_dofiles` / `targets_plan_logs` → 有序基名
- `targets_plan_delegate_bases` → 由 override 派生的纯委托基名（不手写第二份名单）
- 按行迭代：`targets_plan_each_dofile` / `each_log` / `each_pair` / `each_delegate` / `is_delegate`

Caller（`run-verify.sh` / `check-claims.sh` / `test-prompts.sh`）只经 `each_*` 消费；空格拆分仅发生在 `targets.sh` 内部。旧空格分隔 compatibility 薄封装已于 #27 删除。

当前非恒等 plan：

| 入口 | owner | do-files（有序） |
|------|--------|------------------|
| `verify-did-community` | `did-community` | `verify-synth-sdid` · `verify-power` · `verify-trop` |

全量枚举按 `stata-*/SKILL.md` 驱动入口；占位 `verify-did-community.do` 已删除。

## 理由（load-bearing）

1. 委托关系是「一条 seam、多个 adapter」：执行、日志、文档断言都要知道 did-community 跑哪些 do-file，跨 seam 泄漏。集中到 plan 换取 locality。
2. 删除测试：删除 `targets.sh` 会让别名知识重新散回多处 caller。
3. 解析提前后，`check_version` / data contract 落在真实委托 do-file 上，而非占位文件。
4. 与 ADR-0003 对齐：社区包验证脚本增多时，只改 override 表。

## 后果

- 新增 skill 入口由 `stata-*/SKILL.md` 决定；`verify/verify-<name>.do` 必须存在或经 plan 解析为存在的 do-file。
- 纯委托脚本经 `targets_plan_is_delegate` / `each_delegate` 放行孤儿检测。
- 显式单目标（如 `run-verify.sh synth-sdid`）对恒等入口仍可用。
- ADR / AGENTS 中的三委托事实由 `check-claims` 与 `test-targets` 交叉验证；delegate 漂移会失败。

## 未来再评估

- 若委托关系再扩展，保持单一 override 表；必要时沉淀为 TSV，但仍只经 plan API 暴露。
