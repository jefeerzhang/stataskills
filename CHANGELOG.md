# Changelog

All notable changes to stataskills are documented here. This format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/) (skill content is
versioned by Stata compatibility).

## [Unreleased]

### Added
- feat(verify): 新增 `verify/check-claims.sh` 文档断言检查器（架构评审
  candidate 1）：从文件系统数出 facts（skill 数 / .dta 数 / manifest 条数 /
  demo dofiles、logs、PNG）与结构断言比对，接入 CI；顺手修复两处已实证
  漂移（docs/run-stata.md「5 份」→6、demo/REPORT.md 加快照范围声明）。
- feat(skills): 新增 `stata-did` skill，覆盖 Stata 官方 DID 命令族
  （didregress 重复截面/DDD、xtdidregress 面板、hdidregress/xthdidregress
  异质性稳健错时处理，及 trendplot/ptrends/granger/aggregation/atetplot/
  bdecomp 事后诊断），素材源自 Stata 19 官方 DID 宣传单，全部语法经
  Stata 19.5 实测；配套 `verify/verify-did.do`（全模拟数据，无网络依赖）
  接入 harness（5/5→6/6）与 README/CITATION 同步。
- feat(skills): 新增 `stata-coefplot` skill，完整整合 Ben Jann coefplot 官方
  getting-started + estimates / confidence-intervals / labelling / markers /
  varia 六大页面的系数图方法；配套 `verify/verify-coefplot.do`、
  `demo/dofiles/06_stata-coefplot.do`（4 张 PNG）与 README 更新。
- feat(verify): `verify/test-harness.sh` 回归测试——探针 do-file 故意触发
  错误，断言 harness 必须判 FAIL，锁住判定逻辑本身。
- feat(ci): GitHub Actions（`.github/workflows/verify.yml`）在 push/PR 自动
  跑 Stata-free 静态层；配套 `run-verify.sh --static`：version 政策 +
  数据集存在 + manifest 登记 + manifest 与 `data/agis6/*.dta` 双向一致性，
  另加 shellcheck 质量门（runner 无商业 Stata，执行层仍由本机承担）。

### Fixed
- fix(verify): 错误码正则改为整行锚定 `^[[:space:]]*r\([0-9]+\);`，捕获
  个位数错误码（如 assert 失败的 `r(9)` 旧版被判 PASS 的假阳性），同时
  仍不误吃 `power(0.90)` / `star(5)` 等合法参数；版本政策校验钉到
  do-file 首行；data readiness 额外校验引用数据集已登记入
  `data/manifest.txt`。
- docs: 修正 README/CITATION 中 coefplot 加入后的声明漂移（badge 4/4→5/5、
  英文摘要 4→5 skills、对比表 demo 规模 5 do-file + 15 PNG→6 + 19、
  SKILL.md 行数范围）。
- chore(data): 移除 `data/agis6/` 下 20 个误入库的运行日志（`chapter*.log`、
  `_*.log`）——可再生产物，非 provenance；`.gitignore` 扩为
  `data/agis6/*.log` 防复发，落实「数据目录只放数据」。

### Planned
- Add `meta/METHODOLOGY.md` documenting the textbook → skill distillation
  process (so other developers can adapt this pattern to their own textbook).
- PR entries into `ComposioHQ/awesome-claude-skills` and
  `hanlulong/awesome-ai-for-economists` (long-tail discovery).
- Submit to skills.sh / clawhub.ai once the README overhaul lands.

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