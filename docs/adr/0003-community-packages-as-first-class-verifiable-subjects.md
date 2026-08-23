# ADR-0003: 社区包作为一等可验证对象纳入 verify

- 状态：Accepted
- 日期：2026-08-17
- 相关：ADR-0001（SKILL 围栏不可执行化）、ADR-0002（demo 独立全景层）；`/add-stata-methods` 报告 decision #1（突破"社区包不进验证"边界）

## 背景

AGENTS.md 沿用至今的硬性约定：

> 社区包（`ssc install`，如 reghdfe / csdid / synth / sdid）只写用法，不进验证脚本（脚本不依赖网络）

这条约定在 `stataskills` 仓库最初的 6 个 skill（basics / descriptives / regression / advanced / coefplot / did）建立时是合理的：当时所有覆盖的命令都是 Stata 内置（didregress、xtdidregress、hdidregress、xthdidregress），数据集全部来自 `data/agis6/`（AGIS6 教材配套）。

`stata-did` 在 2026-08-17 的扩展加入了第 14 节（合成控制 `synth` / `synth_runner`）和第 15 节（合成 DID `sdid`）。这些是社区包方法，且 `synth` 的经典案例（加州 Prop 99）依赖 `synth_smoking.dta`——一份需要从外部源下载、无法本地模拟的示例数据。

摆在面前的选项：
- **(a) 维持原状**：社区包不进验证，SKILL.md 第 14–15 节"只写用法"。
- **(b) 把"写得进 SKILL"的部分整体撤下**：改写为方法学索引而不是可执行 workflow。
- **(c) 把社区包纳入验证**：扩展 harness 支持双清单 + `--community` 模式 + 双 sentinel，让 CI 不被网络绑定、本地可选真验证。

## 决策

**采纳 (c)。** `verify/run-verify.sh` 引入：
- 双数据清单（`data/manifest.txt` + `data/manifest-extra.txt`）——AGIS6 与项目扩展数据严格分离；
- `--community` 模式标志——默认模式静默 PASS（cap which 风格，CI 友好），`--community` 模式下必需包未装即 BAD；
- 双 sentinel（`__COMMUNITY_PACKAGE_MISSING__` 必需 / `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__` 可选）——脚本可在缺包分支精确区分必需/可选，避免误报。
- 缺包分支只输出 sentinel 并跳过对应命令，不产生 `r(N)`；harness 对任何 Stata 错误码都保持 fail-closed，避免 sentinel 掩盖真实失败。

第一份使用此模式的脚本是 `verify/verify-synth-sdid.do`，覆盖 `stata-did` 第 14–15 节。`synth_smoking.dta` 由 `data/synth/download_synth_smoking.sh` 下载并含字节级校验（`EXPECTED_SIZE=47045`，差异时拒绝覆盖并报错）。

## 理由（load-bearing）

1. **SKILL.md 第 14–15 节的命令语法本身就需要实测**——其中 `synth` 的 numlist 形式是 `(start(1)end)` 不是 `(start:end)`（后者被 synth 报 `invalid numlist r(121)`），原 SKILL.md 示例代码有 bug。把命令纳入 `verify/` 才能在第一时间捕获这种"看着对、跑就错"的语法陷阱。**这不是"社区包方法本身要不要进验证"的抽象讨论，是 SKILL 内容真实错误倒逼扩展**。

2. **CI 友好性是约束，不是取舍**——`run-verify.sh` 默认模式 cap which 跳过关键命令、log 末尾打 sentinel、整体仍 PASS。CI runner 不装 `synth` / `sdid` 不会破坏 `bash verify/run-verify.sh --static` 与默认模式。`--community` 模式是显式 opt-in 的本地"真验证"开关，给"我要确保社区包章节真的能在本机跑通"留出入口。

3. **数据资产单源原则不变**——扩展数据走 `data/manifest-extra.txt`（与 AGIS6 `data/manifest.txt` 解耦），且每个扩展数据集必须留档 `data/<子目录>/README.md`（来源、许可、字节校验值）+ `download_*.sh`（带 EXPECTED_SIZE 字节校验）。`data/manifest.txt` 顶部注释"AGIS6 单一来源"的语义不被稀释。

4. **必要包与可选包显式区分**——`synth_runner`（用于 ADH 2015 placebo 置换推断）是 `synth` 之上的可选工具，不是必需。`__COMMUNITY_PACKAGE_OPTIONAL_MISSING__` sentinel 让 harness 知道"这个缺了不影响核心验证逻辑，但仍提示用户"。如果不区分，可选包会被误报为"必需包缺"，污染 PASS 判定的语义。

5. **本仓库 ADR 传统的延续**——ADR-0001 / 0002 都在做"分层契约"的明示（教学围栏 / 可执行验证 / 教材原文 / 全景演示四层）。本 ADR 沿用同一思路：**"社区包在 verify 中的角色"是第五条契约**，写在 ADR 里比写在 SKILL.md / AGENTS.md 注释里更稳。

## 后果

- 维护负担新增一项：新增社区包章节时需在 `data/<子目录>/README.md` 留档 + `download_*.sh` + `data/manifest-extra.txt` 登记 + `verify/<skill>-<chapter>.do` 含 sentinel。这比"内置命令 + agis6 数据"的传统流程略重，**有意识保留**——目的是过滤"社区包示例数据"这种最常见的腐烂源（上游改字段、上游下架、上游改许可）。
- `run-verify.sh` 默认模式不强制装包——CI 仍能跑、不会因网络抖动变红。代价：默认模式下，`synth_smoking.dta` 真有字段问题时静默通过，需要 `--community` 主动发现。建议：本地开发前 `ssc install synth sdid synth_runner`；CI 仅跑静态层（已在 .github/workflows 里如此配置）。
- `verify-synth-sdid.do` 中的 sdid 部分用本地模拟数据（800 obs，1 处理 + 39 对照 × 20 期），单处理单位下 bootstrap/jackknife 都报 `r(451)`（synth_runner 文档明示："bootstrap and jackknife procedures are not appropriate with single treated units"），故用 `vce(noinference)` 跑点估计。这与 SKILL.md 第 15 节示例的 `vce(bootstrap) reps(50)` 形成"模拟数据 vs 真实多处理单位研究"的对比，已在脚本注释中明示。
- 任何想撤销本 ADR 的判断需要"AGENTS.md 同步改回'社区包不进验证'"+ "synth / sdid 章节从 SKILL.md 删除或标注为'仅索引'"，是反向路径。

## 未来再评估

- 如果未来 Stata 内置命令覆盖了 `synth` / `sdid` 的核心功能（极不可能但记录在案），本 ADR 退化为"扩展数据下载与字节校验"的纯基础设施决策。
- 如果多个 skill 都引入社区包章节（synth / reghdfe / csdid / eventstudyinteract / did_multiplegt / ...），考虑把"社区包 sentinel + 双清单 + 下载脚本"沉淀为一个模板（`docs/templates/community-package.md`）。
- 如果 `data/synth/synth_smoking.dta` 上游变更（字段重命名、新增变量、许可变化），需要团队评审是否更新 EXPECTED_SIZE / 重新生成 / 切换到另一数据集——脚本里 EXPECTED_SIZE 不一致时是 fail-fast 状态，不会默默覆盖。
