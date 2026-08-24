# Changelog

All notable changes to stataskills are documented here. This format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/) (skill content is
versioned by Stata compatibility).

## [Unreleased]

### Changed
- refactor(验证): 新增 `verify/lib/targets.sh` 验证目标注册表，把
  `did-community → synth-sdid` 的委托关系收敛为单一来源；`run-verify.sh`
  全量枚举改为按 `stata-*/SKILL.md` 驱动，`check-claims.sh` 第 1 条改为
  注册表驱动的「skill ↔ 入口」双向断言（含孤儿检测），删除占位
  `verify-did-community.do`。详见 ADR-0004。
- refactor(验证): `test-prompts.json` 成为 `--prompts` 模式的单一来源——
  新增 `verify_keywords` 字段，删除 `verify_script`（重复注册表的委托知识），
  `test-prompts.sh` 删除两个按位置配对的平行数组，验证目标名从 `skill`
  字段推导（取首个、去 `stata-` 前缀）。`did-02/03/04` 目标随之收敛为
  `did-community`（由注册表解析到 synth-sdid）。
- refactor(架构): 拆分 stata-regression SKILL.md 为 references/ 模式——
  主文件 762 → 111 行，三个教材章节（ANOVA / 多元回归 / 逻辑回归）与
  三个扩展（reghdfe / ivreghdfe / fect）下沉到 6 个
  references/<章节|方法>.md（仿 stata-coefplot / stata-did-community 范式）。
  四件套陷阱统一在主文件一份。
- docs(adr-0005): 记录「保留完整 verify log、不替换为稳定摘要」的决策（架构评审候选 4 的取舍），详见 docs/adr/0005-keep-raw-verify-logs.md。

### Added
- feat(验证): 新增 `verify/check-claims.sh` 文档断言检查器（架构评审
  candidate 1）：从文件系统数出 facts（skill 数 / .dta 数 / manifest 条数 /
  demo dofiles、logs、PNG）与结构断言比对，接入 CI；顺手修复两处已实证
  漂移（docs/run-stata.md「5 份」→6、demo/REPORT.md 加快照范围声明）。
- feat(技能): 新增 `stata-did` skill，覆盖 Stata 官方 DID 命令族
  （didregress 重复截面/DDD、xtdidregress 面板、hdidregress/xthdidregress
  异质性稳健错时处理，及 trendplot/ptrends/granger/aggregation/atetplot/
  bdecomp 事后诊断），素材源自 Stata 19 官方 DID 宣传单，全部语法经
  Stata 19.5 实测；配套 `verify/verify-did.do`（全模拟数据，无网络依赖）
  接入 harness（5/5→6/6）与 README/CITATION 同步。
- feat(技能): 新增 `stata-coefplot` skill，完整整合 Ben Jann coefplot 官方
  getting-started + estimates / confidence-intervals / labelling / markers /
  varia 六大页面的系数图方法；配套 `verify/verify-coefplot.do`、
  `demo/dofiles/06_stata-coefplot.do`（4 张 PNG）与 README 更新。
- feat(验证): `verify/test-harness.sh` 回归测试——探针 do-file 故意触发
  错误，断言 harness 必须判 FAIL，锁住判定逻辑本身。
- feat(仓库): GitHub Actions（`.github/workflows/verify.yml`）在 push/PR 自动
  跑 Stata-free 静态层；配套 `run-verify.sh --static`：version 政策 +
  数据集存在 + manifest 登记 + manifest 与 `data/agis6/*.dta` 双向一致性，
  另加 shellcheck 质量门（runner 无商业 Stata，执行层仍由本机承担）。

### Fixed
- fix(验证): 错误码正则改为整行锚定 `^[[:space:]]*r\([0-9]+\);`，捕获
  个位数错误码（如 assert 失败的 `r(9)` 旧版被判 PASS 的假阳性），同时
  仍不误吃 `power(0.90)` / `star(5)` 等合法参数；版本政策校验钉到
  do-file 首行；data readiness 额外校验引用数据集已登记入
  `data/manifest.txt`。
- docs(仓库): 修正 README/CITATION 中 coefplot 加入后的声明漂移（badge 4/4→5/5、
  英文摘要 4→5 skills、对比表 demo 规模 5 do-file + 15 PNG→6 + 19、
  SKILL.md 行数范围）。
- chore(数据): 移除 `data/agis6/` 下 20 个误入库的运行日志（`chapter*.log`、
  `_*.log`）——可再生产物，非 provenance；`.gitignore` 扩为
  `data/agis6/*.log` 防复发，落实「数据目录只放数据」。

### Added
- docs(readme): 首屏加钩子句「**Agent 跑 Stata DID 分析的唯一验证通过入口。**」；
  快速开始节补 `npx skills add jefeerzhang/stataskills` marketplace 安装入口。
- refactor(架构): 拆分 stata-did-community SKILL.md 为 references/ 模式——
  主文件 1219 → 293 行，详细方法签名下沉到 8 个 references/<method>.md
  （仿 stata-coefplot 已有 references/ 目录）。陷阱表统一在主文件一份。
- docs(skills): 7 个 SKILL.md 的「关键陷阱速查」节统一为「**陷阱 → 触发 → Fix → 验证**」
  四件套格式；为每个 Skill 末尾新增「## ❌ Agent 不该做的事（黑名单）」节，
  与 ADR-0001 联动。
- feat(验证): 新增 `verify/test-prompts.sh` 三模式 harness（docs / --prompts / --llm），
  把 test-prompts.json 的 11 条 prompt 从 spec 升级为可执行测试；docs 模式（默认，CI
  友好）断言 JSON 合法 + 覆盖 7 skill + expected_outputs 关键词出现在文档/日志。
  --prompts 模式本机实测 11/11 PASS（2026-08-22 StataNow 19.5 MP）。
  接入 `.github/workflows/verify.yml`。仿 test-harness.sh 与 run-verify.sh 三模式
  设计。

### Fixed
- fix(验证): 本机实测 test-prompts.sh --prompts 模式时发现并修复 3 个 harness bug：
  1. `verify-did-community.do` 用了相对路径 `do "verify/verify-synth-sdid.do"`，
     cwd 切到 data/agis6/ 后路径解析失败——run-verify.sh 改为直接跑 verify-synth-sdid.do，
     主循环结束后复制一份 verify-did-community.log。
  2. harness 解析 sentinel 字符串要求单独成行，但 Stata batch mode 下
     `display "SENTINEL"` 后紧跟 `exit 1` 会让 display 输出变 echo 行
     （`.     display "SENTINEL"`），sentinel 不再单独成行——改为 grep -oE
     抓所有 sentinel 字符串（不要求独立行）。
  3. sentinel 分支的 `exit 1` 写 r(1) 错误码被 harness 计为真实错误——
     检测到 sentinel 时把 r(1) 视为缺包触发的 exit，从 r(错误) 计数中减去。
- fix(脚本): verify-synth-sdid.do 把 `error 1` 改为 `exit 1`（语义一致，行为
  一致）；`estat group/event` 在 40 unit × 10 period 小样本下报 conformability
  r(503) 是已知 csdid 限制，用 capture 包住让脚本继续。

### Planned
- Add `meta/METHODOLOGY.md` documenting the textbook → skill distillation
  process (so other developers can adapt this pattern to their own textbook).
- PR entries into `ComposioHQ/awesome-claude-skills` and
  `hanlulong/awesome-ai-for-economists` (long-tail discovery).
- Submit to skills.sh / clawhub.ai once the README overhaul lands.
  README 已加 `npx skills add jefeerzhang/stataskills` 一行安装入口
  （2026-08-22）；marketplace 实际发布仍需 owner 上传 metadata，从 Planned
  移到 Done 后再勾掉。

## 2026-08-16 — repo polish

### Changed
- refactor(verify): centralise platform paths into `verify/stata.conf`; fix
  demo provenance references — `daaf692`.
- docs(readme): tighten README to be an index of seams; move descriptions of
  skill contents to per-skill files — `11c45bd`.
- refactor(arch): consolidate run conventions into `docs/run-stata.md` seam;
  deepen `verify/` into a verification harness — `d32dc99`.

### Documented
- docs(adr-0001): record decision to keep `SKILL.md` code fences as
  pedagogical pseudocode rather than an executable interface — `a3d9401`.
- docs(demo): fix English-Chinese spacing and fullwidth punctuation in
  `demo/REPORT.md` — `2268b8c`.

## 2026-08-15 — demo

### Added
- feat(demo): end-to-end demonstration using Stata's built-in `auto.dta` —
  5 do-files, 5 logs (all `end of do-file`), 11 PNG graphs, and a full
  REPORT.md walking through each skill — `2394ef9`.

## 2026-08-15 — repo polish

### Fixed
- fix(docs): fix issues identified by code-review pass — `bca861a`.
- chore: configure engineering skills (GitHub issue tracker, default triage
  labels, single-context domain docs) — `6bdd0d5`.

## 2026-08-14 — initial release

### Added
- feat(skills): 4 Stata skills (`stata-basics`, `stata-descriptives`,
  `stata-regression`, `stata-advanced`) covering chapters 1–16 + Appendix A
  of *A Gentle Introduction to Stata* (6th ed.) — `a5db238`.
- feat(book): include the textbook's Markdown text + 170 figures in `book/`
  for reference — `fd0cca5`.
- feat(data): 38 `.dta` files + 16 `chapter*.do` from the AGIS6 dataset
  bundle, with `data/manifest.txt` as the single source of truth.
- feat(verify): initial `verify/` harness with PASS/FAIL judgement.
- feat(docs): `download_data.do` for one-shot re-fetching of the AGIS6 data
  bundle.

---

[Unreleased]: https://github.com/jefeerzhang/stataskills/compare/daaf692...HEAD