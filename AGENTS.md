# AGENTS.md

Stata skills 仓库：基于《A Gentle Introduction to Stata》第 6 版构建的 7 个 skills（`stata-basics`、`stata-descriptives`、`stata-regression`、`stata-advanced`、`stata-coefplot`、`stata-did`、`stata-did-community`），含配套数据集（`data/agis6/`）、教材原文（`book/`）与验证脚本（`verify/`）。

## 目录

- `stata-*/SKILL.md` — 各 skill 主文档（含 frontmatter `name`/`description`、分节编号、陷阱速查、验证节）
- `verify/verify-<skill>.do` — 对应验证脚本；`bash verify/run-verify.sh [skill名]` 运行，Stata 19.5 批处理模式
- `docs/run-stata.md` — 各平台 Stata 批处理路径
- `docs/adr/` — 架构决策记录
- `CLAUDE.md` — 旧版项目指令（issue tracker / triage labels / domain docs），保留有效，本文件不重复其内容

## 关键惯例

- SKILL.md 中 Stata 内置命令的示例语法必须经 `verify/` 脚本实测通过
- 社区包（`ssc install`，如 reghdfe / csdid / jwdid / did_imputation / synth / sdid）：**部分章节的示例语法现在已纳入验证**（见 `stata-did/SKILL.md` 第 13–15 节 / `verify/verify-synth-sdid.do`）。机制：`run-verify.sh` 默认模式静默 PASS（cap which 风格，CI 不被网络绑定）；`--community` 模式强制要求必需包安装齐全才 PASS。可选包用 `__COMMUNITY_PACKAGE_OPTIONAL_MISSING__` sentinel，与必需包 `__COMMUNITY_PACKAGE_MISSING__` 区分。
- 验证脚本数据的两种来源：
  - AGIS6 教材配套：`data/agis6/`，由 `data/manifest.txt` 单一来源管理。
  - 项目级扩展（社区包示例需要、非 AGIS6 来源）：`data/<子目录>/`，由 `data/manifest-extra.txt` 单一来源管理。两份清单由 harness 同时校验；扩展数据集必须有来源 README + 字节级下载脚本（如 `data/synth/download_synth_smoking.sh`）。
- 中文作图需先询问用户；默认英文标签
- 每个 SKILL.md 首行钉住 `version 19.5`

<!-- proma:knowledge-maintenance:start -->
## 协作知识演进（Proma 维护）

- 保持本文件中的项目地图与已验证项目事实同步；命令、架构、边界和入口变化时做最小更新，不复制到协作记忆。
- Proma 工作区的 `memory/` 是可扩展的长期协作知识库：`MEMORY.md` 只做主题索引和路由，按证据创建用户画像、协作偏好、纠错与经验、决策理由等主题文件；不要把临时过程或长篇证据写入其中。
- 用户画像按具体领域渐进修订，不以“新手/专家”等全局标签定性。只有稳定、会改变未来协作判断的信息才值得维护。若记忆时间敏感、状态会更新，或记录具有后续判断价值的阶段性进展，须在对应正文相邻标注事实/状态的发生、生效或截至时间（至少日期；日内顺序、截止点或时区会影响判断时写明时间和时区），不能用文件修改时间替代；稳定事实无需额外添加时间戳。
- 基于明确、稳定证据的 Memory 最小增量可直接写入并在完成后说明；仅在删除或大段覆盖、与既有记录冲突、存在不确定推断，或可能涉及敏感个人信息时，先提出候选并取得确认。项目地图的已验证事实可直接更新。历史会话仅在用户授权后作为分批、限量的补充证据，不得全量扫描。
<!-- proma:knowledge-maintenance:end -->
