# 05 — 现有方法边界与 sdid references

**What to build:** DID、DID-community、RDD、IV 与 selection 的 named-method 请求能够正确直达；standard DID、synth 和 sdid 的运行时说明与 router 保持一致。

**Blocked by:** 04 — `stata-identification` router 与 3 个 references

**Status:** complete

- [x] 各方法保留最短本地进入条件、失败动作和 router 指针，不复制完整决策树。
- [x] standard DID 的边界与 parallel trends 说明准确。
- [x] Synthetic Control 通常面向少数处理单位和长前期。
- [x] Synthetic DiD 支持单个或多个处理单位及当前实现支持的多个处理日期，不把处理单位少作为必要条件。
- [x] 运行时 sdid reference 与 workflow 对上述边界、comparison units、weighting、latent-factor/regularity 和推断条件一致。
- [x] named-method 失败后能返回 router；standard DID 失败后先检查同一面板政策支柱的 synth/sdid 分支。
