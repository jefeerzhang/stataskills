# ADR-0002: demo/ 作为独立全景层，与 verify 的可执行验证解耦

- 状态：Accepted
- 日期：2026-08-16
- 相关：ADR-0001（SKILL 围栏保持教学伪代码）、/improve-codebase-architecture 报告 candidate #3

## 背景

ADR-0001 定义了三层刻意分层：SKILL.md 教学围栏 / verify 脚本可执行验证 / chapter do-file 教材原文。
demo/ 是第四层，ADR-0001 未覆盖它。demo do-file 注释自称"与 verify 同款设计"，但实际上是独立
编写的端到端演示代码（含 graph export、结果解读、完整数据流），与 verify 无结构耦合。

覆盖不对称：stata-did 有 verify 无 demo；panelview/fect 有 demo 无 verify。

架构评审提出两个方向：(a) 把 demo 薄化为 verify 的公开演示壳（深度优先）；(b) 保留 demo 的
独立性并用 ADR 文档化其定位（保守优先）。

## 决策

**demo/ 是独立的第四层：端到端全景演示。** 不薄化为 verify 的壳。ADR-0001 的三层模型
扩展为四层：

| 层 | 目录 | 抽象层级 | 目的 |
|---|---|---|---|
| 1. 教学围栏 | `stata-*/SKILL.md` | 伪代码 | 教学可读性 |
| 2. 可执行验证 | `verify/verify-*.do` | 可执行子集 | CI 断言正确性 |
| 3. 教材原文 | `data/agis6/chapter*.do` | primary source | 教材忠实性 |
| 4. 全景演示 | `demo/dofiles/*.do` | 端到端演示 | 人类可读的完整体验 |

## 理由（load-bearing）

1. **deletion test：** 删 demo 不会让复杂度消失——端到端体验（graph export、结果解读、
   完整数据流）会散落到 README 截图描述和口头演示中。demo 集中了这些行为。

2. **seam 的不同位置：** verify 的 seam 在"命令是否正确执行"；demo 的 seam 在"读者是否
   能跟随完整流程"。两个不同的 interface，不同的 leverage。

3. **薄化代价高：** 把 demo do-file 改为 `do verify-*.do` + graph export 壳，需要
   verify 脚本本身输出图——但这违反 ADR-0001（verify 的职责是验证，不是演示）。
   让 verify 同时承担验证和演示两个职责会使其 interface 膨胀（shallow module 风险）。

## 后果

- demo 与 verify 的代码重复是跨层翻译，不是拷贝漂移。用覆盖矩阵（check-claims.sh）
  对账，而非共享代码来消除重复。
- 覆盖不对称（did 无 demo、panelview/fect 无 verify）是当前状态，不是目标。demo
  扩展时应同步扩展覆盖。
- 若 demo 代码与 verify 代码持续漂移并造成真实故障（非理论风险），重新打开本 ADR，
  优先考虑"覆盖矩阵断言升级为逐行比对"的轻量方案。

## 未来再评估

若 demo 需求演变为"公开的 CI 可跑验证"（例如给没有 Stata 的用户在线跑 demo），
重新评估是否将 demo 合并进 verify 的执行层。
