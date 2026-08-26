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

## Verification evidence

- Formal build: `data/selection/build-teaching.do` executed with Stata 19.5; exit 0 and reached `end of do-file`.
- Observed: `N=2000`, treatment rate `0.254`, raw mean difference `1.461`.
- IPWRA: ATET `0.5016781`, robust SE `0.06099`; `abs(ATET - 0.5) <= 0.15` passed.
- Publication constraints: exact varlist `id treat y x1 x2 x3 x4 x5 x6`, no oracle variables, English labels.
- Static manifest check: `bash verify/run-verify.sh --static` — 9 passed, 0 failed.
- Sanitized formal-build evidence is recorded in `data/selection/README.md` under “Formal build evidence”; raw local Stata logs are not committed because they contain machine/license metadata.
