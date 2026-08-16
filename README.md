# Stata Skills（基于《A Gentle Introduction to Stata》第 6 版）

> 把 800 页英文 Stata 教材压成 4 个可被 Agent 调用的中文教学 Skill：basics / descriptives / regression / advanced。

[English summary](#english-summary) | [中文说明](#中文说明)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![StataNow 19.5](https://img.shields.io/badge/Stata-19.5%20MP-orange.svg)](docs/run-stata.md)
[![Verify](https://img.shields.io/badge/verify-4%2F4%20PASS-brightgreen.svg)](verify/)
[![GitHub](https://img.shields.io/badge/GitHub-jefeerzhang%2Fstataskills-181717)](https://github.com/jefeerzhang/stataskills)

[![skills.sh: stata-basics](https://skills.sh/b/jefeerzhang/stataskills/stata-basics)](https://skills.sh/jefeerzhang/stataskills/stata-basics)
[![skills.sh: stata-descriptives](https://skills.sh/b/jefeerzhang/stataskills/stata-descriptives)](https://skills.sh/jefeerzhang/stataskills/stata-descriptives)
[![skills.sh: stata-regression](https://skills.sh/b/jefeerzhang/stataskills/stata-regression)](https://skills.sh/jefeerzhang/stataskills/stata-regression)
[![skills.sh: stata-advanced](https://skills.sh/b/jefeerzhang/stataskills/stata-advanced)](https://skills.sh/jefeerzhang/stataskills/stata-advanced)

## 特性

- **4 个分章节 Skill**：basics / descriptives / regression / advanced 严格对应教材第 1–16 章 + 附录 A
- **完整命令 + 解读逻辑 + 报告惯例 + 8 条 boxed tips**，每个 SKILL.md 200 – 270 行
- **38 个配套数据集**：AGIS6 完整版（含每章 do-file），用 manifest.txt 作单一来源
- **可一行复现的 verify harness**：`bash verify/run-verify.sh` 当前实测 4/4 PASS
- **真实 demo** 报告：5 个 do-file + 14 张 PNG + 完整 REPORT.md（含 reghdfe 与 regress i.fe 残差对比图 + panelview 缺失模式与处理状态）
- **高维固定效应 `reghdfe`**：2+ 层 FE / 多向聚类 / IV-GMM 吸收 FE / 自动剔除单点组（见 stata-regression 10.5 节）
- **工程化外壳领先**：ADR-0001 + verify + manifest + stata.conf 四条单一来源

![因子分析碎石图](demo/output/04_screeplot.png)
![逻辑回归边际效应](demo/output/03_logit_margins.png)
![MPG 按产地箱线图](demo/output/02_hbox_mpg_by_foreign.png)
![reghdfe 残差与 regress i.fe 残差对比（数学等价性证据）](demo/output/03_reghdfe_resid_compare.png)

## 你什么时候需要它？

- 你是实证研究者（社科 / 经济 / 公共卫生），想用 Stata 但不想读完整本教材
- 你已经会基础 Stata，想做 ANOVA / 多元回归诊断 / 逻辑回归 / SEM（结构方程） / 多层 / IRT 等进阶分析
- 你在 Claude Code / Codex / OpenClaw 里跑 Agent，需要让 Agent 自己会写 do-file

## 快速开始

```bash
# 1. 克隆到 Claude Code / Codex / OpenClaw 的 skills 目录
git clone https://github.com/jefeerzhang/stataskills.git ~/.claude/skills/

# 2. （可选）验证：需要本机 StataNow 19.5（macOS / Windows 路径见 docs/run-stata.md）
bash verify/run-verify.sh
# 预期：4/4 PASS
```

## 触发方式

- **Slash 命令**：`/stata-basics` · `/stata-descriptives` · `/stata-regression` · `/stata-advanced`
- **自然语言**：「用 Stata 帮我做多元回归诊断」/「演示 factor analysis」/「怎么做 IRT」
- **路由表**：

| 用户问题 | 路由到 |
|---|---|
| 录入 / 标签 / 反向编码 / 构建量表 | `stata-basics` |
| 描述统计 / 交叉表 / t 检验 / 相关 | `stata-descriptives` |
| ANOVA / 多元回归 / 逻辑回归 / 功效 / 多维 FE（reghdfe） | `stata-regression` |
| 因子 / SEM / 多重插补 / 多层 / IRT | `stata-advanced` |

## 示例

来自 demo/REPORT.md 的真实运行结果（macOS StataNow 19.5 MP）：

| Skill | 关键结果 |
|---|---|
| basics | 清洗 auto.dta → 74 obs × 12 vars，`rep78` 缺失 5，保存为 `data/auto_clean.dta` |
| descriptives | `rep78 × foreign` χ²(4)=27.26, p<0.001, Cramér's V=0.63 |
| regression | `price ~ weight + foreign` ANCOVA F=35.35, p<0.001, R²=0.499 |
| advanced | `factor ... , pcf` 保留 1 因子解释 74.3% 方差 |

完整命令 + 全部结果见 [demo/REPORT.md](demo/REPORT.md)。

## 它和同类有什么不同？

| 维度 | stataskills（本仓库） | [dylantmoore/stata-skill](https://github.com/dylantmoore/stata-skill) (276⭐) | [codex-stata-for-economists](https://github.com/maxwell2732/codex-stata-for-economists) |
|---|---|---|---|
| 教材驱动 | ✅ AGIS6 全 16 章 + 附录 A | ❌ | ⚠️ 章节切片 |
| 配套数据 | ✅ 38 `.dta` 入库 | ❌ | ❌ |
| 验证 harness | ✅ 一行命令 + 4/4 PASS 实测 | ❌ | ⚠️ log 验证 |
| Demo 报告 | ✅ 5 do-file + 14 PNG + REPORT.md | ❌ | ❌ |
| ADR / 架构决策 | ✅ ADR-0001 | ❌ | ❌ |
| 单一来源 | ✅ `data/manifest.txt` + `verify/stata.conf` | ❌ | ❌ |

我们不是「又一个 Stata skill」——是**唯一带完整数据 + verify + ADR + demo 的工程化外壳**。

## 安全边界

- **默认英文标签作图**：Stata 图形 PostScript 字体不支持中文，会渲染为乱码；需要中文图表时先与用户确认（详见 `docs/run-stata.md`）。
- **不会自动运行你的数据**：所有命令都在 do-file 里，由你控制何时 `do file.do`。
- **已下线 UCLA 包标注**：`chitable` / `chi2power` / `powerreg` / `powerlog` 随 UCLA 服务器下线无法联网安装；各 SKILL.md 已标注等价命令（如 `power twoproportions`、`power rsquared`）。
- **教材原文版权**：`book/` 包含 Alan C. Acock《A Gentle Introduction to Stata》(6th ed.) 原文，仅供教学参考，版权归 Stata Press；详见 [LICENSE](LICENSE) 的附加声明段。

## 文件结构

```
stataskills/
├── README.md                       ← 本文件
├── CLAUDE.md                       ← Agent 工作约定
├── LICENSE                         ← MIT（含教材版权声明）
├── CHANGELOG.md                    ← 变更历史
├── CITATION.cff                    ← 学术引用
├── download_data.do                ← 一键下载全部数据
├── stata-basics/SKILL.md           ← skill 1（数据管理 / 清洗）
├── stata-descriptives/SKILL.md     ← skill 2（描述 / 检验）
├── stata-regression/SKILL.md       ← skill 3（回归）
├── stata-advanced/SKILL.md         ← skill 4（因子 / SEM / 多层 / IRT）
├── book/                           ← 教材原文 Markdown（教学使用）
├── data/
│   ├── manifest.txt                ← 38 个 .dta 清单（单一来源）
│   └── agis6/                      ← 完整 AGIS6 数据集
├── docs/
│   ├── run-stata.md                ← 平台命令速查（单一来源）
│   ├── adr/0001-do-not-execute-skill-code-fences.md
│   └── agents/                     ← Agent 工作流
├── verify/                         ← 验证 harness
│   ├── run-verify.sh               ← 4/4 PASS 判定
│   ├── stata.conf                  ← 平台路径（单一来源）
│   └── verify-{basics,descriptives,regression,advanced}.{do,log}
└── demo/                           ← 端到端示例
    ├── REPORT.md                   ← 完整报告
    ├── dofiles/                    ← 5 个 do-file
    ├── logs/                       ← 5 个 Stata log（exit=0）
    └── output/                     ← 14 张真实 PNG
```

## 验证与测试

```bash
bash verify/run-verify.sh           # 全量（4 个 skill）
bash verify/run-verify.sh advanced  # 单个 skill
```

**判定标准**：日志恰好一次 `end of do-file` 且无 `r(错误码)` → PASS。
当前实测：**4/4 PASS**（`verify/verify-basics.log` 等 4 个 log 均为 `end_of_dofile=1, r_err=0`）。

## 本地开发

修改任何 skill 内容后，重跑 verify 确认 4/4 PASS：

```bash
bash verify/run-verify.sh
```

如果改动了命令，需要同步三处（按 ADR-0001 决策）：

- `*/SKILL.md`（教学围栏）
- `verify/verify-*.do`（验证 harness）
- `data/agis6/chapter*.do`（教材原文）

详见 [CHANGELOG.md](CHANGELOG.md)。

## 引用本 Skill

见 [CITATION.cff](CITATION.cff)（含 APA / BibTeX）。

同时请引用原教材：

> Acock, A. C. (2018). *A Gentle Introduction to Stata* (6th ed.). Stata Press.

## 致谢

- 教材原文：Alan C. Acock《A Gentle Introduction to Stata》(6th ed., Stata Press, 2018)
- 高维固定效应：[reghdfe](https://github.com/sergiocorreia/reghdfe)（**Noah Constantine & Sergio Correia**，里士满联储；[Correia 2017](http://scorreia.com/research/hdfe.pdf)；RePEc [S457874](https://ideas.repec.org/c/boc/bocode/s457874.html)；DOI [10.5281/zenodo.27755549](https://doi.org/10.5281/zenodo.27755549)）
- IV / 2SLS + 多维固定效应：[ivreghdfe](https://github.com/sergiocorreia/ivreghdfe)（Sergio Correia，2024；DOI [10.5281/zenodo.82003805](https://doi.org/10.5281/zenodo.82003805)）
- 面板数据可视化：[panelview](https://github.com/xuyiqing/panelview_stata)（Hongyu Mou & Yiqing Xu；[Mou, Liu & Xu (2023) JSS 107(7)](https://doi.org/10.18637/jss.v107.i07)）
- 同类项目参考：[dylantmoore/stata-skill](https://github.com/dylantmoore/stata-skill)、[hanlulong/stata-mcp](https://github.com/hanlulong/stata-mcp)、[codex-stata-for-economists](https://github.com/maxwell2732/codex-stata-for-economists)
- 教材 → Skill 元流程参考：[Leutenegger/book-to-skill](https://github.com/Leutenegger/book-to-skill)

---

## English Summary

`stataskills` is a collection of 4 Stata skills distilled from Alan C. Acock's *A Gentle Introduction to Stata* (6th edition, Stata Press, 2018):

| Skill | Chapters | Topics |
|---|---|---|
| `stata-basics` | 1–4 | interface, data entry & labels, data prep (reverse coding, scales, missing), do-files |
| `stata-descriptives` | 5–8 | univariate descriptives, crosstabs/χ², mean/proportion tests, correlation & bivariate regression |
| `stata-regression` | 9–11 | ANOVA/ANCOVA, multiple regression, logistic regression, power analysis |
| `stata-advanced` | 12–16 + App. A | reliability/validity, factor, SEM/GSEM, multiple imputation (mi), multilevel (mixed), IRT |

Each SKILL.md contains complete command syntax, result-interpretation logic, menu paths, and an 8-item pitfalls checklist. The 38 `.dta` datasets ship in `data/agis6/`. End-to-end demo (5 do-files + 14 PNGs) lives in `demo/`. Verify harness (`bash verify/run-verify.sh`) currently reports **4/4 PASS** on StataNow 19.5 MP.

```bash
git clone https://github.com/jefeerzhang/stataskills.git ~/.claude/skills/
```

See [demo/REPORT.md](demo/REPORT.md) for the full walkthrough.