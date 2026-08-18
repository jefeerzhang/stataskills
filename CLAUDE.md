# CLAUDE.md

本仓库是基于《A Gentle Introduction to Stata》第 6 版构建的 4 个教材章节 skill + 3 个扩展 skill（`stata-coefplot`、`stata-did`、`stata-did-community`），共 7 个 Stata skills（`stata-basics`、`stata-descriptives`、`stata-regression`、`stata-advanced`、`stata-coefplot`、`stata-did`、`stata-did-community`），含配套数据集（`data/agis6/`）、教材原文（`book/`）与验证脚本（`verify/`）。

## Agent skills

### Issue tracker

Issues 和 PRDs 存放在 GitHub Issues 中（使用 `gh` CLI）。See `docs/agents/issue-tracker.md`.

### Triage labels

五个 canonical triage roles 使用默认 label 字符串（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）。See `docs/agents/triage-labels.md`.

### Domain docs

仓库当前不维护 `CONTEXT.md`。Single-context 文档（按 `domain` 术语的实际出现懒创建）由 `/domain-modeling` 在 terms 实际被解决时创建。

已有 ADR：`docs/adr/`（ADR-0001 SKILL 围栏不执行化、ADR-0002 demo 作为独立全景层；后续决策继续追加）。详见 `docs/agents/domain.md`。
