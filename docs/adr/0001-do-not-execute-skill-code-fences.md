# ADR-0001: SKILL.md 代码围栏保持教学伪代码，不做成 executable interface

- 状态：Accepted
- 日期：2026-08-16
- 相关：/improve-codebase-architecture 报告 candidate #4（Speculative）

## 背景

架构评审曾提出一个 deepening opportunity：把 SKILL.md 的代码围栏当作可执行
interface，由验证 harness 直接解析并运行，让"同一段 Stata 命令"只维护一份，
消除 SKILL 围栏、verify 脚本、教材 chapter do-file 三处渲染的重复。

## 决策

**放弃该重构。** SKILL.md 代码围栏保持教学伪代码，verify 脚本保持真实可执行
验证，教材 chapter do-file 保持 primary source。三处渲染是刻意分层，不是重复。

## 理由（load-bearing）

1. **围栏物理上不可执行。** 围栏是面向人类读者的教学伪代码，含 Stata 不接受的
   中文变量名（`egen float 缺失数 = rowmiss(...)`）、伪代码简写（`rowmean(同左)`）、
   省略占位符（`title(...) scheme(s1mono)`）。stata-basics 更是没有任何
   ` ```stata ``` ` 围栏，代码全是 inline 缩进块。
2. **删除测试否决。** 删围栏 = 丢掉教学核心（skill 的全部语义）；删 verify =
   丢掉可执行验证（test surface）。两个端点都不可删，没有可深化的 module——
   三处是三种不同抽象层级的刻意设计：教学（围栏）／验证（verify 脚本，可执行
   缩写子集）／原文（chapter do-file，教材 primary source）。
3. **改写围栏代价高且伤语义。** 把 40 块围栏改写为真实可执行命令需删除中文
   变量名与伪代码，教学可读性受损，收益只是消除"尚未发生漂移"的重复。

## 后果

- 维护同一命令仍要留意三处（改命令时同步 SKILL / verify / chapter），但这是
  跨抽象层级的翻译，不是单一 module 的拷贝漂移。
- 验证真实性由 verify 脚本承担（`verify/run-verify.sh`，见 ADR 体系内其他记录），
  与围栏的教学完整性解耦。

## 未来再评估

若 SKILL.md 围栏被证明与 verify 脚本持续漂移并造成真实故障（而非理论风险），
重新打开本 ADR，优先考虑"围栏标注对应 verify 命令"的轻量链接，而非可执行化。
