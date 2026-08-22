---
name: stata-basics
description: Stata 数据清洗与基础操作：录入、打标签、反向编码、构建量表、写可复现 do-file。对应教材第 1–4 章。触发词：数据清洗 / recode / mvdecode / 缺失码 / 量表 / label / do-file 模板。
---

# Stata 入门与数据管理（本书第 1–4 章）

本 skill 浓缩自 Alan C. Acock《A Gentle Introduction to Stata》第 6 版第 1–4 章，适合"学 Stata 数据管理"的场景：录入/导入数据、打标签、反向编码、构建量表、写 do-file 复现分析。

## 运行 Stata 的方式

- 批处理（无界面，推荐在 do-file 里跑完整流程）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log` 文件，内含全部输出。平台二进制路径与 Windows 等价命令见 `docs/run-stata.md`。
- 本书配套数据位于仓库 `data/agis6/` 目录。示例命令中的 `use 文件名, clear` 假定已 `cd` 到该目录；若不在，用完整路径 `use "…/data/agis6/firstsurvey.dta", clear`。
- **中文作图规矩**：需要生成图形命令（`graph *`、`histogram`、`twoway` 等）且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 强制路径

匹配到第一条就停。章节语法见下文；禁令见文末黑名单。

**何时用**：录入、打标签、缺失码、反向编码、构建量表、写可复现 do-file。
**何时踢走**：描述统计 / 卡方 / t 检验 → `stata-descriptives`；回归 / ANOVA → `stata-regression`；政策评估 / DID → `stata-did`。

反向编码（本 skill 最高频任务）：

```stata
clonevar old_orig = old
mvdecode old, mv(99=.a \ 98=.b)
recode old (1=4) (2=3) (3=2) (4=1) (.a=.a) (.b=.b)
tab old_orig old, miss
```

1. `clonevar` 留底。2. `mvdecode` 先转缺失码。3. `recode` 反向，显式保留 `.a`/`.b`。4. `tab old new, miss` 交叉核对。禁止 `gen new = 5 - old`。

## 核心语法

```
command varlist if/in, options
```
- varlist：变量列表；不写 = 对所有变量（如 `summarize`）。
- if/in 限定观测；选项必须在逗号之后（漏逗号是最常见错误）。
- 关系运算符：`==`(是) `!=`/`~=`(不是) `>` `>=` `<` `<=`。
- 逻辑与用 `&`（不是单词 and）；比较用 `==`（不是 `=`）。
- Stata 区分大小写：命令全小写，`Summarize` 会报错。
- 长命令在 do-file 中续行用行尾 `///`；命令窗口里结果窗口的续行提示 `>` 不要输入。
- **缺失值是巨大数值，比任何数字都大**：`if age > 64` 会把缺失者也选进来，必须写 `if age > 64 & age < .`。

## 第 1 章 起步

- 打开自带示例数据：`sysuse cancer, clear`；查看数据描述：`describe`。
- 汇总统计：`summarize`（N、均值、SD、min、max）；`summarize varlist, detail` 给分位数/方差/偏度/峰度（50% 即中位数）。
- 直方图：`histogram age, width(2.5) start(45) frequency title(标题) scheme(s1mono)`。
- 在线数据：`use https://stats.idre.ucla.edu/stat/data/hsb2`。
- 帮助：`help 命令名`；联网搜索：`search 关键词`。

## 第 2 章 录入数据

### 变量命名与标签
- 变量名 ≤32 字符、建议 ≤10（最好 8 以内）、全小写、以字母开头、无空格；保留字 `_all _cons _N using with` 等不可用。
- 变量标签（variable label）：`label variable age "年龄"`，说明变量含义。
- 值标签（value label）两步走：先定义（昵称），再指派到变量：
  ```stata
  label define sex 1 "Male" 2 "Female"
  label values gender sex
  ```
  一个昵称可复用于多个变量（如 30 个 1/2 编码的变量共用一个 `yes_no` 标签）。
- 给变量加备注：`note` 命令或 Variables Manager；`notes` 查看；`describe` 输出中带 `*` 的变量表示有备注。

### 数据编辑器
- 编辑模式：`edit`；只读浏览：`browse`（带 `, nolabel` 看数值）。
- 字符串变量转数值：`destring varlist, replace`（输入时误打字母 l 会把变量变字符串）。
- 压缩存储：`compress`（从 SPSS 等导入大文件后建议执行）。

### 检查数据
- `codebook`：逐变量描述（类型/范围/唯一值/缺失数/频数表）；`codebook, compact` 简洁版。
- `describe`：数据集整体概况（obs/vars/变量列表）。

### 导入导出
- Excel：菜单 File → Import/Export（`import excel` / `export excel`）；导入后统一变量名小写：`rename ID-ZODIAC, lower`。
- SAS XPORT：File → Import/Export SAS XPORT。
- 存旧版本给老用户：`saveold 文件名, version(11)`。

## 第 3 章 数据准备（本 skill 的重点）

### 3.1 缺失值代码转 Stata 缺失值
- Stata 缺失值：`.`、`.a`–`.z` 共 27 种，**均大于任何数值**。
- 调查数据常把拒答编码为负值，用 `mvdecode` 转换（规则间用 `\` 分隔）：
  ```stata
  mvdecode _all, mv(-5=.a\-4=.b\-3=.c\-2=.d\-1=.e)
  ```
  例如 -5=流失→.a、-4=合法跳过→.b、-3=非法跳过→.c、-2=不知道→.d、-1=拒答→.e。
- 转换后才能安全做算术（否则 `.a` 内部是大数，参与运算出错）。

### 3.2 反向编码（reverse-code）
- 原则：**分数越高 = 特质越强**；负向题需反转。
- 用 recode 生成**新变量**（保留原变量），规则放括号里，`generate()` 给新变量名：
  ```stata
  recode r3483700 r3483900 r3485300 r3485500 (0=4)(1=3)(2=2)(3=1)(4=0), ///
      generate(momcritr momblamer dadcritr dadblamer)
  ```
- 常见规则：多值合并 `(1 2 3=0)`；折叠高端 `(5/max=5)`；折叠低端 `(min/8=8)`。
- 新变量须**重新定义值标签**（编号已反转）：
  ```stata
  label define often_r 4 "Never" 3 "Rarely" 2 "Sometimes" 1 "Usually" 0 "Always"
  label values momcritr momblamer dadcritr dadblamer often_r
  ```
- 算术反向（0–4 量表：`4 - 原值`；1–5 量表：`6 - 原值`）：`generate facritr = 4 - r3485300`。**必须先 mvdecode**。
- **生成新变量后必须验证**：`tabulate 新变量 原变量, miss nolabel`（`miss` 把缺失纳入表，`nolabel` 显示数值）。

### 3.3 创建和修改变量
- 复制变量（保留缺失编码与值标签）：`clonevar 新名 = 原名`。
- 简单复制（不转移值标签）：`generate 新名 = 原名`。
- 算术运算符：`+ - * / ^`；运算顺序：括号 → 乘方 → 乘除 → 加减；**任一操作数缺失则结果缺失**；多加括号保可读。
- 删除变量：`drop varlist`；删除观测：`drop if 条件`、`drop in 范围`（如 `drop in 1/20`）；保留：`keep if 条件`、`keep in 1/500`。

### 3.4 构建量表（scale）
- 目标：把多个条目合成一个总分/均分。
- 直接相加的问题：任一题缺失则总分缺失。
- **egen 与 rowmiss/rowmean**：
  ```stata
  egen float 缺失数 = rowmiss(mompraise momcritr momhelp momblamer)
  egen float 均分 = rowmean(mompraise momcritr momhelp momblamer)
  egen float 均分75 = rowmean(同左) if 缺失数 < 2
  ```
  - `rowmiss()` 数每行缺失题数；`rowmean()` 用已回答题目算均值（与条目同尺度，好解释），可选 `if` 要求至少答 75%。
  - 菜单：Data → Create or change data → Create new variable (extended)。
- **不要用 rowtotal 把缺答当 0**（1–4 量表中无意义）；若必须总分：`generate 总分 = 均分 * 条目数`。
- 扩展 egen 函数库：`ssc install egenmore, replace`。

### 3.5 变量名大小写
- 从国家数据库（NLSY97 等）导入的变量常全大写，统一转小写：
  ```stata
  rename R0000100-R3828700, lower
  ```

## 第 4 章 do-file 与结果管理

- Do-file 是命令脚本，保证可复现。开头写注释与版本：
  ```stata
  * my_first.do
  version 15
  use "firstsurvey_chapter4.dta", clear
  ```
- 注释：行首 `*`（整行）；长注释 `/* ... */`。
- 运行：Window → Do-file Editor → New Do-file Editor；可高亮部分命令只跑选中段。
- 打开数据用 `use 文件名, clear`；**路径含空格必须加引号**。
- 换工作目录：`cd "路径"`。
- 复制本书网页的 do-file：`copy http://www.stata-press.com/data/agis6/chapter4.do .`（结尾 `空格+点` 表示存当前目录）。
- 结果记录：
  - 复制到 Word：Results 窗口选中 → 右键 Copy（用 Courier 9 号定宽字体防错位）；表格可用 Copy table / Copy table as HTML / Copy as Picture。
  - **log 文件**：菜单 File → Log → Begin；默认 SMCL 格式（`.smcl` 只能 Stata 读），Word 用纯文本格式存 `.log`；`log 不含图形输出`。命令：`log using 文件名.log, replace` / `log close`。
- 列出数据：`list varlist in 1/5`（`nolabel` 看数值）；`browse` 图形化浏览。

## 关键陷阱速查

> 统一格式：**陷阱 → 触发 → Fix → 验证** 四件套。每条陷阱都给出可执行的修复 + 验证；Agent 在 SKILL.md 读到警告时即拿到完整修复路径。

1. 漏掉选项前的逗号
   - **触发**：Stata 报 `option not allowed` 或 `invalid syntax`；常见于把 `summarize varname, detail` 漏写逗号写成 `summarize varname detail`。
   - **Fix**：选项前永远先写逗号再接 `, option`；do-file 里 `grep -nE '^\s*[a-z]+\s+[a-z]' myscript.do` 找无逗号行。
   - **验证**：`do myscript.do` 应无 `option not allowed` 错误；grep 无匹配行。

2. `==` 与 `=` 混用；`&` 写成 and
   - **触发**：条件判断 `if x=1` 报 `invalid syntax`；逻辑与写 `if x==1 and y==2` 报 `and not found`。
   - **Fix**：用 `==` 表相等、`&` 表与；`=` 仅在 `gen x = ...` 或选项赋值时用。`assert x==1` 是自检利器。
   - **验证**：`assert x==1` 应 PASS；写错的 `assert x=1` 会报 `invalid syntax`。

3. if 条件漏掉 `& 变量 < .`（缺失值被误选）
   - **触发**：写 `if age > 64` 把缺失者也选进来（缺失值是巨大数值，比任何数字都大），导致回归样本量异常、结果偏。
   - **Fix**：数值比较的 if 子句全部加 `& var < .`；或先 `mvdecode var, mv(99=.)` 把缺失码转 `.`。
   - **验证**：跑完 `summarize age if age > 64` 看 N 是否包含缺失值；正确做法 `summarize age if age > 64 & age < .`。

4. 反向编码前忘了 mvdecode，缺失代码参与算术出错
   - **触发**：缺失码 `.a`/`.b` 参与 `recode` 或算术运算（如 `new = 5 - old`）时，结果变成 `.` 而非保留缺失码区分。
   - **Fix**：`mvdecode var, mv(99=.a)` 在反向编码前先跑；用 `tab var, miss` 验证缺失码已合并。
   - **验证**：`tab newvar, miss` 应能看到原 `.a`/`.b` 仍保留或正确合并。

5. 生成新变量不验证（必须 tabulate 交叉核对）
   - **触发**：写 `gen newvar = ...` 后直接进分析，结果异常但不自知。
   - **Fix**：`assert inrange(newvar, min, max)` 或 `tab old new, miss` 交叉表核对；`codebook newvar` 查分布。
   - **验证**：交叉表的边缘合计应与原变量一致；分布应在理论合理范围内。

6. 用算术法反向会丢失缺失原因的区别（.a/.b 都变 `.`）
   - **触发**：`gen new = 5 - old` 把原 `.a`/`.b` 都变成 `.`（缺失），丢失缺失原因信息。
   - **Fix**：缺失码有区别时用 `recode var (1=4) (2=3) (3=2) (4=1) (.a=.a) (.b=.b)` 显式保留；先 `clonevar var_orig = var` 留底。
   - **验证**：`tab old new, miss` 应显示 `.a` → `.a`、`.b` → `.b`（不是 → `.`）。

7. 变量名 >8 字符显示被截断（如 `educat~n`）
   - **触发**：输出表格时变量名被 Stata 截断为 `educat~n`，但变量本身无问题。
   - **Fix**：用 `label variable varname "全名"` 给长变量名加标签；导出表格时用 `estimates table, b(%9s)` 或 `outreg2`。
   - **验证**：`describe` 看变量标签是否完整；导出 CSV 后变量名应完整。

8. 命令全小写（Stata 区分大小写）
   - **触发**：写 `Summarize x` 报 `command Summarize not found`（Stata 命令区分大小写）。
   - **Fix**：所有命令 lower-case；写完跑 `do myscript.do` 验证——不要依赖 IDE 高亮判断大小写。
   - **验证**：`do myscript.do` 应无 `command ... not found`；报错行的命令首字母应为大写。

## ❌ Agent 不该做的事（黑名单）

> 与 ADR-0001 联动：本节是「**主动反模式**」清单——「关键陷阱速查」是被动警告，本节是主动规范。Agent 在写 do-file 前必查一遍。

- ❌ **不要用算术法做反向编码**（`gen new = 5 - old`）：丢失缺失码区分（`.a`/`.b` 都变 `.`）。**替代**：`recode var (1=4) (2=3) (3=2) (4=1) (.a=.a) (.b=.b)`，先 `clonevar var_orig = var` 留底。
- ❌ **不要在 if 条件里漏 `& var < .`**：缺失值是巨大数值（`> 任何数字`），会把缺失者误选进来。**替代**：数值比较的 if 子句全部加 `& var < .`；或先 `mvdecode var, mv(99=.)`。
- ❌ **不要在 do-file 里写 `drop _all`**：会清空数据集且不可恢复。**替代**：用 `clear`（仅当不需要保留数据时）或 `preserve` / `restore`。
- ❌ **不要把 `clear all` 当"重置"用**：会清空所有 `estimates store` 的模型、`matrix`、标签——不可恢复。**替代**：用 `estimates drop _all` 或选择性 `clear matrix` / `clear label`。
- ❌ **不要复制 .dta 文件当变量名用**（如 `gen 教育年限 = ...`）：中文字段名在批处理模式可能渲染为乱码，且某些导出命令（`outreg2` / `estout`）不支持中文标签。**替代**：用拼音（如 `educ`）+ `label variable educ "教育年限"`。
- ❌ **不要用 Excel 输入数据后不 `destring`**：误打字母会把变量变字符串，回归报错 `variable ... not found`。**替代**：导入后跑 `destring varlist, replace force`；或用 `import excel, cellrange(A2:I100) clear` 严格列范围。
- ❌ **不要在 do-file 里用 `cd "~/..."` 绝对路径**：换机器就跑不了。**替代**：用相对路径（`cd data/agis6/`）+ 项目根目录约定。
