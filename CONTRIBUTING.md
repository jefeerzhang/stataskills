# 贡献指南

感谢你考虑为本项目做贡献。本仓库的 skill 内容以《A Gentle Introduction to Stata》第 6 版为底本，配合社区包扩展（reghdfe / ivreghdfe / panelview / fect）。

## 提交流程

1. **Fork 本仓库**，创建 feature 分支
2. 编写代码或文档改动
3. **本地验证**（必须）：
   ```bash
   bash verify/run-verify.sh --static
   bash verify/test-harness.sh
   bash verify/test-prompts.sh
   bash verify/check-claims.sh
   bash verify/run-verify.sh        # 全部 10 个 verify target 通过
   ```
   demo 是 ADR-0002 定义的独立全景层；修改 demo 时再运行对应 `demo/dofiles/*.do`。
4. **Commit message** 用 [Conventional Commits 中文规范](https://www.conventionalcommits.org/)：
   - type 英文（`feat` / `fix` / `docs` / `refactor` / `perf` / `test` / `chore` / `ci`）
   - scope 中文（`技能` / `验证` / `演示` / `仓库` / `描述技能` / `回归技能` 等模块名）
   - subject 中文动宾短句，不超过 50 字符
5. **Push 到 fork**，开 Pull Request，标题同 commit message
6. **等 CI / 维护者 review**

## 修改命令的同步规矩（ADR-0001 决策）

按 [ADR-0001](docs/adr/0001-do-not-execute-skill-code-fences.md) 决策，**教学围栏保持伪代码**，所以同一 Stata 命令有三处渲染，**改动必须同步**：

| 改动类型 | 必改文件 |
|---|---|
| 修改命令语法 / 选项 / 陷阱 | `stata-*/SKILL.md`（教学围栏）+ 对应 `verify/verify-<skill>.do`（可执行验证） |
| 修改教材命令示例 | 同步 `data/agis6/chapter*.do`（教材原文 primary source） |
| 新增 AGIS6 数据集 | `data/manifest.txt`（单一来源）+ `verify/` 检查 |
| 新增项目级扩展数据 | `data/manifest-extra.txt` + 对应子目录 README；外部来源走 license/provenance/download 校验，项目内生成走 version/seed/DGP/build/invariants 校验 |
| 新增社区包扩展节 | `*/SKILL.md` 加新节 + frontmatter description 加触发词 + `verify/` 加用例 + `demo/` 加段 + README 致谢段 ¹ |
| 修改平台二进制路径 | **只能改** `verify/stata.conf`（单一来源）+ `docs/run-stata.md` 说明 |

¹ **demo + README 致谢段可后置**：按 [ADR-0002](docs/adr/0002-demo-as-independent-panorama-layer.md)，demo 是独立的全景层（第 4 层），新增扩展节时可只先做 verify；后续扩展 demo 时需补齐。`verify/check-claims.sh` 的覆盖矩阵断言会持续提醒哪些扩展节尚缺 demo（assertion #8 的 facts 段输出）。

## 依赖安装

| 依赖 | 装法 | 何时需要 |
|---|---|---|
| StataNow 19.5 | 见 `docs/run-stata.md` 与 `verify/stata.conf` | 跑任何验证 do-file；版本政策固定为 19.5 |
| `reghdfe` 6.12.3+ | `ssc install reghdfe, replace` + `net install ftools, from(...)` + `ftools, compile` + `mata: mata mlib index` | 跑 `*/SKILL.md` 10.5 / 10.6 / 10.7 节 |
| `ivreg2` 4.1.11+ | `ssc install ivreg2, replace` | 跑 10.6 ivreghdfe |
| `ranktest` 1.3.02+ | `ssc install ranktest, replace` | 跑 10.6 ivreghdfe（弱工具变量诊断需要） |
| `_gwtmean` | `ssc install _gwtmean, replace` | 跑 10.7 fect |
| `panelview` 1.0.0+ | `net install grc1leg / gr0075 / labutil / sencode`（依赖） + `net install panelview, all replace from(...)` | 跑 8.5 panelview |

**强依赖关系**：reghdfe / ivreghdfe / fect 必须装在同一 Stata 实例；`net install X, all replace from(...)` 会把配套 `.dta` 复制到当前目录。

## 协议合规

本仓库代码用 **MIT License**（见 [LICENSE](LICENSE)）。`book/` 含 Alan C. Acock《A Gentle Introduction to Stata》第 6 版原文，**仅供教学参考**，版权归 Stata Press。

集成第三方包（reghdfe / ivreghdfe / panelview / fect）均为 MIT，**致谢段必须保留作者 + 链接 + DOI/SSRN**：

| 包 | 作者 | 引用 |
|---|---|---|
| reghdfe | Noah Constantine, Sergio Correia | [Correia 2017](http://scorreia.com/research/hdfe.pdf) / RePEc [S457874](https://ideas.repec.org/c/boc/bocode/s457874.html) / DOI [10.5281/zenodo.27755549](https://doi.org/10.5281/zenodo.27755549) |
| ivreghdfe | Sergio Correia | DOI [10.5281/zenodo.82003805](https://doi.org/10.5281/zenodo.82003805) |
| panelview | Hongyu Mou, Yiqing Xu | [Mou, Liu & Xu (2023) JSS 107(7)](https://doi.org/10.18637/jss.v107.i07) |
| fect | Licheng Liu, Ye Wang, Yiqing Xu, Ziyi Liu | [Liu et al. (2020) SSRN 3555463](https://papers.ssrn.com/abstract=3555463) |

## 代码风格

- **Stata do-file**：缩进 4 空格；命令小写；注释用 `*`（整行）或 `//`（行尾）；长命令续行 `///`
- **YAML frontmatter**（SKILL.md 顶部）：`name` 小写英文，`description` 含 when-to-use 触发词（参考 anthropics/skills spec）
- **commit scope 中文**：与 SKILL.md 模块名对齐（`技能` / `验证` / `演示` / `仓库` / `描述技能` / `回归技能` 等）
- **文件编码**：UTF-8
- **中文排版**（参考 [中文文案排版指北](https://github.com/sparanoid/chinese-copywriting-guidelines)）：
  - 中英文之间加空格
  - 中文与数字之间加空格（`38 个数据`，不是 `38个数据`）
  - 中文语境用全角标点
  - 专有名词保留英文（reghdfe / fect / IR 等）

## 测试要求（提交前必做）

```bash
# 1. Stata-free 结构与回归层
bash verify/run-verify.sh --static
bash verify/test-harness.sh
bash verify/test-prompts.sh
bash verify/check-claims.sh

# 2. 执行层（10 个 verify target）
bash verify/run-verify.sh
# 预期：10 通过，0 失败；raw logs 按 ADR-0005 保留
```

修改 demo 时另跑对应 `demo/dofiles/*.do`，并检查 log 恰好一次 `end of do-file`、无 `r(错误码)`；demo 数量不等同于 skill 数。

## commit message 模板

```text
<type>(<scope>): <subject>

<body>
- <改动 1>
- <改动 2>

影响范围：<涉及的文件 / 模块>
测试：<PASS 证据>

Refs: <ADR 号 / issue 链接 / 论文>
```

### 好的示例

```
feat(回归技能): 加 10.7 节 fect（TWFE 偏差修正）

按 GitHub xuyiqing/fect_stata 仓库整合。
fect 用 reghdfe 作引擎，专门解决 staggered DiD 下
TWFE 估计 ATT 的负权重偏误。

内容（10.7 节）：
- 解决的特定问题（TWFE 偏差机制）
- 4 种 method：ife / mc / both / 默认

影响范围：SKILL.md 10.7 节新增
测试：bash verify/run-verify.sh 全量 PASS + demo 03 ends=1

Refs: Liu et al. (2020) SSRN 3555463
```

### 反面示例

```
fix: 改了一些东西
chore: 更新
docs: 修改了文档
```

## 提问与讨论

- GitHub Issues：bug 报告 / 功能请求
- 教材内容勘误：因本仓库内容基于教材第 6 版，**教材自身**的勘误请到 [Stata Press](https://www.stata-press.com/) 反馈
- 第三方包问题：去对应仓库（reghdfe / ivreghdfe / panelview / fect 的 GitHub Issues）

## 行为准则

- 善意合作；技术讨论对事不对人
- 接受 review，不强推个人偏好
- 引用别人的代码 / 想法时注明出处