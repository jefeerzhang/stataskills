# 02 — 教学数据与数据治理

**What to build:** 生成并验证 selection 教学数据，使用户能够复现一个 selection-on-observables 场景，并得到固定真 ATET=0.5 的可审计数据基线。

**Blocked by:** 01 — ADR-0006 与实施基线

**Status:** complete

- [x] N=2000、seed=20260825、Bernoulli treatment 处理率落在 0.20–0.30。
- [x] treatment 与潜在未处理结果只通过处理前可观测协变量共同决定。
- [x] 固定处理效应为 0.5，构建阶段断言关键不变量和缺失值。
- [x] 发布数据严格只含 `id treat y x1-x6`，oracle/build-time 变量不发布。
- [x] manifest、README provenance、重建命令、schema 和数值不变量记录完整。
- [x] 发布 variable labels 使用英文。
