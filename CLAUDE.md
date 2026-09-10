# CLAUDE.md

本仓库是基于《A Gentle Introduction to Stata》第 6 版构建的 14 个 Stata skills 仓库。技能清单、验证入口与协作约定以根目录 `AGENTS.md` 为准；本文件只保留 issue tracker / triage labels / domain docs 入口，不重复项目地图。仓库含配套数据集（`data/agis6/`）、教材原文（`book/`）与验证脚本（`verify/`）。

## Agent skills

### Issue tracker

Issues 和 PRDs 存放在 GitHub Issues 中（使用 `gh` CLI）。See `docs/agents/issue-tracker.md`.

### Triage labels

五个 canonical triage roles 使用默认 label 字符串（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）。See `docs/agents/triage-labels.md`.

### Domain docs

仓库根目录维护 `CONTEXT.md`，作为强制路径、可执行禁令、陷阱四件套与“踢走”等项目术语的单一术语表。命名与 domain 文档规则详见 `docs/agents/domain.md`。

已有 7 份 ADR：`docs/adr/`（ADR-0001 SKILL 围栏不执行化、ADR-0002 demo 独立全景层、ADR-0003 社区包验证、ADR-0004 验证目标注册表、ADR-0005 保留 raw verify logs（已被 ADR-0007 取代）、ADR-0006 四个识别方法支柱与横切路由、ADR-0007 verify raw log 退库与声明式 marker 契约）。详见 `docs/agents/domain.md`。
