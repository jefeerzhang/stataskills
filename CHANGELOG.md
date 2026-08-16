# Changelog

All notable changes to stataskills are documented here. This format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/) (skill content is
versioned by Stata compatibility).

## [Unreleased]

### Added
- feat(skills): 新增 `stata-coefplot` skill，完整整合 Ben Jann coefplot 官方
  getting-started + estimates / confidence-intervals / labelling / markers /
  varia 六大页面的系数图方法；配套 `verify/verify-coefplot.do`、
  `demo/dofiles/06_stata-coefplot.do`（4 张 PNG）与 README 更新。

### Planned
- Add `meta/METHODOLOGY.md` documenting the textbook → skill distillation
  process (so other developers can adapt this pattern to their own textbook).
- Refine `verify/run-verify.sh` PASS regex so it does not falsely match
  legitimate commands like `sd(6)`, `n(100)`, `r(6)`.
- Add GitHub Actions workflow to auto-run `bash verify/run-verify.sh` on PR.
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