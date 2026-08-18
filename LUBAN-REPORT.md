# stataskills 打磨报告

> 鲁班工坊 · 2026-08-18

---

## 1. 验料结果（Skill前提挑战）

挑战1 - 真实问题：**成立**。Stata 在经济学/社会科学中广泛使用，但 Agent 生态中几乎没有结构化的 Stata Skill。用户问 Agent "跑个 DID"时，得到的是通用知识，不是经过验证的 Stata 命令。

挑战2 - 独特角度：唯一性来自**三层资产**——(1) 教材原文逐章映射（800 页→4 个 Skill），(2) DID 识别方法全覆盖（9 个方法，含 DCDH/StackedDiD/LPDiD 等前沿），(3) 可执行验证系统（8/8 PASS + 双 manifest + 11 条断言）。同行没有这三层同时具备。

挑战3 - 安装理由：**部分成立**。基础 Skill（basics/descriptives/regression/advanced）的价值有限——Agent 通用知识已覆盖大部分。**安装的核心理由是 DID**：9 个识别方法 + 决策树 + 特征矩阵 + 8 步工作流 + 验证脚本，这是问 Agent 问不来的。需要强化"DID 是安装理由"这个钩子。

挑战4 - 公共传播性：**缺钩子**。首屏没有 GIF/截图，没有"装完第一秒能用"的 demo。有 27 张 PNG 但散落在 `demo/output/` 里，README 没有展示任何一张。有可展示产物（demo logs、verify PASS），但没有摆出来。

验料结论：**好料，继续打磨。** 核心资产（DID 方法库 + 验证系统）有真实差异化。需要做的是：把"DID"从众多功能中拎出来做成首屏钩子，补 showcase。

---

## 2. 访行记录（同类Skill横向对标）

| 同类Skill | 链接 | 类型 | 一句话定位 | 它为什么容易被理解/安装/传播 | 可学的手艺 | 不能照搬的点 |
|---|---|---|---|---|---|---|
| econometrics-skill | [xiaomihu1992/econometrics-skill](https://github.com/xiaomihu1992/econometrics-skill) (33⭐) | 直接 | 17 个因果推断估计器，Python 实现 | Python 生态覆盖面广（OLS→RDD），有 `lib/` 可执行代码 | 方法选择决策树写法、`method_details.md` 分离详细签名 | 它用 Python 不用 Stata，覆盖面广但深度不如 stataskills 的 DID |
| diff-diff | [igerber/diff-diff](https://github.com/igerber/diff-diff) | 直接 | Python DID 全方法库，sklearn API | 23 个估计量、readthedocs 文档、`get_llm_guide()` 专为 Agent 设计 | `get_llm_guide()` API（Agent 专用入口）、decision flowchart | Python 库不是 Skill，没有 SKILL.md 格式 |
| book-to-skill | [virgiliojr94/book-to-skill](https://github.com/virgiliojr94/book-to-skill) (22704⭐) | 手艺 | 把技术书变成 Claude Code Skill | 概念极简（一本书→一个 Skill），首屏 GIF 展示完整流程 | GIF demo、一句话钩子、npx 安装 | 它是通用工具，stataskills 是垂直内容 |
| caveman | [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) (98869⭐) | 手艺 | 省 65% token 的说话方式 Skill | 名字有记忆点、效果可量化（65%）、一条命令安装 | 命名钩子、量化效果、极简安装 | 完全不同领域，学的是传播手艺 |
| mostly-harmless-replication | [vikjam/mostly-harmless-replication](https://github.com/vikjam/mostly-harmless-replication) (660⭐) | 间接 | 《Mostly Harmless Econometrics》Stata/R/Python 复现 | 教材复现+多语言，学术圈自然传播 | 教材锚定（借书的知名度）、多语言对照 | 不是 Skill 格式，没有 Agent 集成 |

---

## 3. 生态位判断

纵向结论：stataskills 从"教材章节 Skill"起步，扩展到"DID 方法全覆盖"。下一阶段方向是成为 **Stata DID 的 Agent 权威入口**——不只是教程，而是 Agent 能直接调用的、经过验证的 DID 工具箱。

横向结论：同类 Skill 的立足点主要来自：(1) Python 生态的广度（econometrics-skill 覆盖 17 个估计器），(2) 传播手艺（book-to-skill 的 GIF + 极简安装），(3) 方法论深度（diff-diff 的 23 个 DID 估计量）。

交叉洞察：stataskills 该抢的生态位不是"又一个 econometrics Skill"，而是 **"Stata DID 的 Agent 权威入口"**——在这个交叉点上，没有同行同时具备：Stata 原生 + 9 个 DID 方法 + 可执行验证 + 决策树路由。econometrics-skill 用 Python 且 DID 只是 17 个方法之一；diff-diff 是 Python 库不是 Skill；stata-did GitHub 仓库只有 1 星。

一句话新定位：**"Agent 跑 Stata DID 分析的唯一验证通过入口"。**

---

## 4. 过尺结果（活体检查 + 质量评分）

### 活体检查

| 检查项 | 结果 | 证据 |
|---|---|---|
| 数据产物新鲜度 | ✅ | demo 08 log 刚填充（今天）；38 个 .dta 文件都在 |
| CI 对账 | ✅ | 8/8 verify PASS；28/28 check-claims PASS |
| 真实渲染 | ⚠️ | 27 张 PNG 存在但 README 未展示；无 GIF |
| 文档命令实跑 | ✅ | `bash verify/check-verify.sh` 和 `bash verify/check-claims.sh` 均通过 |
| GitHub 活跃度 | ⚠️ | 0 stars、0 forks、创建 4 天 |

### 九维评分

| 维度 | 权重 | 得分 | 主要证据 | 最大短板 | 优先级 |
|---|---:|---:|---|---|---|
| Frontmatter与触发条件 | 7 | 5 | 7 个 SKILL.md 都有 frontmatter，但 description 是长串关键词堆叠，不是人话 | description 不是人话 | P1 |
| 工作流清晰度 | 12 | 10 | 每个 Skill 有"运行 Stata 的方式"+命令选择表+陷阱速查；DID 有决策树+8步工作流 | 决策树 16 行超 ADHD 阈值 | P2 |
| 失败模式编码 | 12 | 9 | 陷阱速查表每条有"Fix"；verify 系统检测静默错误 | 陷阱表格式不统一（有的用**Fix**，有的用自然语言） | P2 |
| 检查点设计 | 6 | 5 | verify 系统有 11 条断言；但 SKILL.md 内部无检查点 | Agent 跑完 Skill 后无自检清单 | P2 |
| 可执行具体性 | 17 | 14 | 每个命令有完整语法+示例+陷阱；verify 脚本可直接跑 | 部分示例用模拟数据而非真实数据 | P2 |
| 资源整合度 | 4 | 3 | 38 个 .dta、demo PNG、verify logs；但散落无索引 | demo/output 的 27 张 PNG 无 README 展示 | P1 |
| 整体架构 | 12 | 10 | 4 层架构（ADR 文档化）；verify harness 5 阶段函数；双 manifest | stata-did-community 1212 行偏大 | P2 |
| 实测表现 | 23 | 20 | 8/8 verify PASS、28/28 断言 PASS、demo 08 刚跑通 | 无端到端 Agent 行为实测（test-prompts.json 是 spec 不是可执行测试） | P1 |
| 反例与黑名单 | 7 | 5 | 陷阱表有"Fix"；但无显式"不要做"清单 | 缺"Agent 不该做的事"列表（如：不要用 TWFE 跑错时 DID） | P2 |
| **总分** | **100** | **81** | | | |

---

## 5. 差距清单

### P0：不补就无法公开/无法信任
- 无 GIF/截图展示——首屏无可视化证据
- README 无 `npx skills add` 一行安装（ClawHub/skills.sh 生态缺失）

### P1：补上后明显提升安装率/传播率
- frontmatter description 是关键词堆叠，不是人话
- demo/output 的 27 张 PNG 散落无展示
- 0 stars 无社会证明

### P2：锦上添花，但不是当前阻塞
- stata-did-community 1212 行偏大
- 陷阱表格式不统一
- 无显式"Agent 不该做的事"列表

### 与同行相比，我们最缺的3件事
1. **传播钩子**——econometrics-skill 有"17 estimators"数字钩子，book-to-skill 有 GIF，caveman 有"65%"数字。stataskills 没有一句话能让人停下来。
2. **Agent 专用入口**——diff-diff 有 `get_llm_guide()`，econometrics-skill 有 `method_selection.md`。stataskills 的决策树散在 SKILL.md 里。
3. **可展示产物**——verify PASS 是内部质量信号，不是外部展示物。需要一个"装完跑一下就能看到的东西"。

### 与同行相比，我们最有机会打穿的3件事
1. **DID 方法深度**——9 个方法 + 决策树 + 特征矩阵 + 8 步工作流，没有任何同行在 Stata 生态做到这个深度。
2. **可执行验证**——8/8 PASS + 双 manifest + 11 条断言，同行没有这个级别的验证系统。
3. **教材锚定**——800 页教材→4 个 Skill 的映射关系，借书的知名度传播。

---

## 6. 三个打磨方向

### 方案A：细修——把现在的 Skill 做清楚
新定位：无变化，清理文档
改动范围：(1) 重写 frontmatter description 为人话 (2) README 首屏加截图 (3) 陷阱表格式统一
优点：改动小，不改架构
风险：不解决传播问题
适合条件：只想内部使用

### 方案B：精雕——做出同行没有的可见产物
新定位：**"Stata DID 的 Agent 权威入口"**
改动范围：(1) README 首屏加 GIF demo（从输入"DID 分析"到输出事件研究图）(2) 把 27 张 PNG 精选 3-4 张放进 README showcase (3) 写一句话钩子："9 个 DID 方法，8/8 验证通过，一条命令安装" (4) 把决策树和矩阵提取为独立的 `references/choosing.md` 供 Agent 直接引用
优点：解决传播问题，不改 Skill 架构
风险：需要录制 GIF
适合条件：想公开发布，追求安装率

### 方案C：开套件——从单 Skill 升级为小型 Skill 套件
新定位：**"Stata 统计 Agent 套件"**
改动范围：(1) 把 7 个 Skill 按主题分组（基础/描述/回归/高级/DID）(2) 每组一个 README 索引 (3) DID 部分拆为 3 个子 Skill（cs/jwdid、synth/sdid、DCDH/StackedDiD/LPDiD）(4) 统一的 `install.sh` 脚本
优点：解决 1212 行膨胀问题，架构更清晰
风险：大改，需要重写很多文档
适合条件：长期维护，计划持续扩展

**推荐选择：方案B**
推荐理由：当前最大的短板是传播，不是架构。方案B 以最小改动解决最大问题。方案C 的架构问题可以等第 4 个新方法加入时再做。

---

## 7. 候选改写方案

本轮只刨：**README 首屏 + showcase**
改动边界：只改 README.md，不改 SKILL.md
预期提升：首屏能在 10 秒内说明价值；有可视证据
验证方式：README 首屏信息密度对比（改动前后各用 10 秒扫一遍）

### 建议文件变更

| 文件 | 操作 | 原因 |
|---|---|---|
| README.md | 修改 | 首屏加截图展示 + 一句话钩子 + 重写英文定位 |
| demo/output/ | 不动 | PNG 已有，只需在 README 引用 |

### 关键改写片段

**README 首屏替换为：**

```markdown
# stataskills

> **Agent 跑 Stata DID 分析的唯一验证通过入口。** 9 个识别方法，8/8 验证 PASS，一条命令装上就能用。

[![Skills](https://img.shields.io/badge/Agent%20Skills-7-blueviolet)](skills/)
[![Verify](https://img.shields.io/badge/verify-8%2F8%20PASS-brightgreen)](verify/)
[![Stata](https://img.shields.io/badge/Stata-19.5%20MP-orange)](docs/run-stata.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**你什么时候需要它？**
- 你要跑 DID（双重差分），但不确定该用 `didregress` 还是 `csdid` 还是 `lpdid`
- 你的数据是错时处理（staggered），担心 TWFE 负权重偏误
- 你要处理可逆处理（工会入会/退会）或冲击型处理（飓风）

**它会交付什么？**

| 输入 | 输出 |
|---|---|
| "我有错时 DID 数据，怎么选方法" | 决策树路由 → 推荐估计量 → 完整语法 + 陷阱 |
| "跑个 synth 看加州控烟" | `synth_smoking.dta` + `synth_runner` placebo 完整代码 |
| "验证一下所有 Skill" | `bash verify/run-verify.sh` → 8/8 PASS |

**快速开始**
```bash
git clone https://github.com/jefeerzhang/stataskills.git
# 拷到你的 Agent skills 目录
```

**DID 方法覆盖：**

| 方法 | 包 | 核心价值 |
|---|---|---|
| didregress/xtdidregress | 内置 | 简单 2x2 DID |
| hdidregress/xthdidregress | 内置 | 错时 DID 异质性稳健 |
| csdid | SSC | Callaway-Sant'Anna，DR/IPW/Reg 三方法 |
| jwdid | SSC | Wooldridge ETWFE，支持非线性 |
| did_imputation | SSC | BJS 插补法，leaveout 方差修正 |
| synth/sdid | SSC | 合成控制 / 合成 DID |
| did_multiplegt (DCDH) | SSC | **可逆处理 DID**（唯一） |
| stacked | GitHub | Q 权重 + D 统计量设计诊断 |
| lpdid | SSC | 局部投影 DID，长差分事件研究 |

![DID 决策树](demo/output/07_stata-did_didregress_event_study.png)
```

---

## 8. README与Showcase升级建议

1. **首屏钩子**：用上面的替换片段
2. **截图展示**：精选 3 张 PNG 放在 README：
   - `demo/output/07_stata-did_didregress_event_study.png`（事件研究图）
   - `demo/output/06_stata-coefplot_coefplot_forest.png`（森林图）
   - `demo/output/01_stata-basics_histogram.png`（基础可视化）
3. **GIF demo**（可选）：录制一个从"跑个 DID"到输出事件研究图的 30 秒 GIF
4. **英文定位**：首段英文说明 "Agent-compatible Stata skills for DID analysis, verified on Stata 19.5 MP"

---

## 9. 执行计划

### 24小时内必须完成
- [ ] 重写 README.md 首屏（用上面的替换片段）
- [ ] 精选 3 张 PNG 放进 README showcase

### 3天内完成
- [ ] 重写 7 个 SKILL.md 的 frontmatter description 为人话
- [ ] 录制 30 秒 GIF demo（可选）

### 7天内完成
- [ ] 提交到 ClawHub / skills.sh
- [ ] 写 CHANGELOG 的"为什么做这个项目"段

### 本轮不做
- stata-did-community 拆分（等第 4 个方法加入时）
- 测试 prompt 可执行化（当前 test-prompts.json 是 spec）

---

## 10. 出师证书

```
┌─────────────────────────────────────┐
│  出师证书 · 鲁班工坊                │
│                                     │
│  作品：stataskills                   │
│  过尺：打磨前 81 分 → 打磨后 88 分  │
│  定位：Stata DID 的 Agent 权威入口  │
│  绝活：9 个 DID 方法 + 8/8 验证 PASS │
│  下一步：重写 README 首屏 + 补截图   │
│                                     │
│  验收师傅：鲁班                     │
└─────────────────────────────────────┘
```

打磨后分数为预估（88 分）：首屏钩子 +3 分（传播力），showcase +2 分（可展示产物），frontmatter +2 分（可理解性）。

---

## 11. 回炉清单

### 对标观察清单
- [diff-diff](https://github.com/igerber/diff-diff)：关注其新增估计量（ChaisemartinDHaultfoeuille 已覆盖，下一个是 TROP?）
- [econometrics-skill](https://github.com/xiaomihu1992/econometrics-skill)：关注其 DID 部分是否扩展为独立 Skill
- [book-to-skill](https://github.com/virgiliojr94/book-to-skill)：学其 GIF 录制和安装体验

### 迭代纪律
- 每加一个新方法，同步更新：决策树 + 特征矩阵 + AI Agent 选择逻辑 + 陷阱表
- verify 脚本必须覆盖新方法（`verify-*.do` 或委托）
- commit 即 push（已配置代理 `http://127.0.0.1:1087`）

### 本轮不做
- stata-did-community 拆分
- TROP / SunAbraham 整合（小众）
- test-prompts 可执行化

---

## 12. 需要用户确认的问题

1. **README 首屏替换**：上面的替换片段可以直接用吗？需要调整措辞吗？
2. **GIF demo**：需要录制吗？还是先用静态截图？
3. **发布平台**：先发 GitHub 还是也提交 ClawHub / skills.sh？

---

## 13. 附录：参考来源

| 同类项目 | URL | 类型 |
|---|---|---|
| econometrics-skill | https://github.com/xiaomihu1992/econometrics-skill | 直接 |
| diff-diff | https://github.com/igerber/diff-diff | 直接 |
| book-to-skill | https://github.com/virgiliojr94/book-to-skill | 手艺 |
| caveman | https://github.com/JuliusBrussee/caveman | 手艺 |
| mostly-harmless-replication | https://github.com/vikjam/mostly-harmless-replication | 间接 |
| quant-econometrics-skills | https://github.com/SpideyHp27/quant-econometrics-skills | 直接 |
