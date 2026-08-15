# Stata Skills（基于《A Gentle Introduction to Stata》第 6 版）

4 个 Stata skill，内容浓缩自 Alan C. Acock《A Gentle Introduction to Stata》第六版（Stata Press, 2018），
面向真实执行场景：中文说明 + 英文 Stata 命令，可直接调用本机 Stata 运行。

## 包含的 skills

| Skill | 覆盖章节 | 主题 |
|---|---|---|
| `stata-basics` | 第 1–4 章 | 界面起步、数据录入与标签、数据准备（反向编码/量表构建/缺失值）、do-file 与结果管理 |
| `stata-descriptives` | 第 5–8 章 | 单变量描述统计与图形、双分类变量交叉表与卡方、均值/比例检验、相关与双变量回归、功效分析 |
| `stata-regression` | 第 9–11 章 | ANOVA/ANCOVA/双因素/重复测量、多元回归（诊断/交互/非线性/加权）、逻辑回归（OR/margins/嵌套）、功效分析 |
| `stata-advanced` | 第 12–16 章 + 附录 A | 信效度与因子分析、SEM/GSEM、多重插补（mi）、多水平模型（mixed）、项目反应理论（irt） |

每个 skill 均为单文件 `SKILL.md`，包含：完整命令语法与选项、结果解读逻辑、菜单路径线索、陷阱清单（boxed tips）。

## 目录结构

```
stataskills/
├── README.md
├── CLAUDE.md
├── download_data.do          # 一键下载全部配套数据（按 data/manifest.txt）
├── stata-basics/SKILL.md     # skill 1
├── stata-descriptives/SKILL.md
├── stata-regression/SKILL.md
├── stata-advanced/SKILL.md
├── data/                     # 数据集清单与配套数据
│   ├── manifest.txt          # 38 个 .dta 数据集清单（单一来源）
│   └── agis6/                # 书配套数据集（.dta + relate.cdb + 每章 do/log）
├── docs/                     # 平台命令与架构决策
│   ├── run-stata.md          # 平台二进制路径与批处理命令（单一来源）
│   └── adr/                  # 架构决策记录（ADR）
├── verify/                   # 验证 harness 与四个 skill 的验证脚本/日志
│   ├── run-verify.sh         # 验证 harness（执行 + 判定 + 汇总）
│   ├── verify-basics.do / .log
│   ├── verify-descriptives.do / .log
│   ├── verify-regression.do / .log
│   └── verify-advanced.do / .log
├── demo/                     # 技能演示（REPORT.md + dofiles + logs + output）
└── book/                     # 教材原文 Markdown 与图片
```

## 安装

1. 将需要的一个或多个 skill 目录复制到 skills 目录（例如 `C:\Users\<用户名>\.agents\skills\` 或 `.zcode\skills\`）。
2. 在 skill 内使用 `/stata-basics` 等斜杠命令或直接说明引用。

## 数据准备

数据来自 Stata Press 官网（`http://www.stata-press.com/data/agis6/`），已下载在本仓库 `data/agis6/`。
若重新克隆后需要重下数据，在 Stata 中运行：

```stata
do download_data.do
```

运行示例命令时，先 `cd` 到数据目录（或把 `use 文件名, clear` 改为完整路径）：

```stata
cd "路径/stataskills/data/agis6"
use firstsurvey, clear
```

## 运行 Stata

本仓库 skill 面向 StataNow 19（兼容 Stata 15 及以后版本，书基于 Stata 15 编写）。
无界面批处理运行方式（本仓库验证环境为 macOS）：

```
stata-mp -b do "脚本.do"
```

运行结束后在当前目录生成同名 `.log` 文件（含全部输出）。
平台二进制路径与 Windows 等价命令见 `docs/run-stata.md`。

## 验证

`verify/` 下的 do 文件覆盖四个 skill 的关键命令，已用 StataNow 19 实际运行通过，
`.log` 为运行记录（含错误检查）。修改 skill 内容后可重跑验证：

```
bash verify/run-verify.sh            # 全量（四个 skill）
bash verify/run-verify.sh advanced   # 单个 skill（basics/descriptives/regression/advanced）
```

runner 依次在每个 skill 的数据目录下以批处理方式执行 do 文件，判定标准与 demo 一致：
日志恰好一次 `end of do-file` 且无 `r(错误码)` → 通过；任一失败以非零退出码结束。
平台二进制路径见 `docs/run-stata.md`。

### 全书 16 章逐命令实测结果（StataNow 19.5）

教材官方 `chapter1.do`–`chapter16.do` 全部逐章实跑（见 `data/agis6/chapter*.log`）：

| 章节 | 结果 |
|---|---|
| ch1–5, 7–9, 12–16 | ✅ 全部命令通过 |
| ch6 | ⚠️ 仅 `chitable`、`chi2power`（UCLA 社区包，已下线）无法运行，其余通过；`table` 需用 Stata 17+ 新语法 |
| ch10 | ⚠️ 仅 `powerreg`（UCLA 包，已下线）无法运行，其余通过；已用官方 `power rsquared` 验证等价 |
| ch11 | ⚠️ 仅 `powerlog`（UCLA 包，已下线）无法运行，其余通过 |
| ch13 | ✅ 手动安装 `mibeta` 后通过 |

**结论**：本书全部**官方命令**在 StataNow 19 中可运行；唯一的问题是 4 个 UCLA 社区辅助包
（`chitable`、`chi2power`、`powerreg`、`powerlog`）随 UCLA 服务器下线无法联网安装。
书正文已标注这些是"需 search 联网安装"的外部命令，不影响核心分析流程。

## 与书/版本的差异说明

- 书基于 **Stata 15**，本机为 **StataNow 19**（MP 版）。绝大多数命令与选项在 19 中完全兼容。
- **Stata 17+ 语法变化**：`table` 命令的 `contents()` 与 `row` 选项自 Stata 17 起被 `statistic()` 取代，新旧写法对照见 `stata-descriptives/SKILL.md` 第 6 章。
- **社区命令安装**：各 skill 的正文与「关键陷阱速查」已说明直接 `ssc install` 可装的命令（`fre`、`binscatter`、`lrdrop1`）与需从 GitHub 镜像手动安装的包（`listcoef` 见 `stata-regression/SKILL.md`，`mibeta` 见 `stata-advanced/SKILL.md`）。
- 中文作图规矩与字体乱码的技术说明见 `docs/run-stata.md`。
