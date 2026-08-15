# CLAUDE.md

本仓库是基于《A Gentle Introduction to Stata》第 6 版构建的 4 个 Stata skills（`stata-basics`、`stata-descriptives`、`stata-regression`、`stata-advanced`），含配套数据集（`data/agis6/`）、教材原文（`book/`）与验证脚本（`verify/`）。

## Agent skills

### Issue tracker

Issues 和 PRDs 存放在 GitHub Issues 中（使用 `gh` CLI）。See `docs/agents/issue-tracker.md`.

### Triage labels

五个 canonical triage roles 使用默认 label 字符串（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）。See `docs/agents/triage-labels.md`.

### Domain docs

Single-context：repo 根目录 `CONTEXT.md`（尚未创建，由 `/domain-modeling` 在 terms 实际被解决时懒创建）+ `docs/adr/`（已有 ADR-0001，后续决策继续追加）。See `docs/agents/domain.md`.
