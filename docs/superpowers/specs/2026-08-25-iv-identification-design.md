# IV 识别与论文解释设计

## 目标

在现有 IV 命令选择与检验体系之外，增加面向实证论文的最小识别与解释层。完成后，Agent 能说明 IV 系数估计的对象、按同一设定报告结果链，并避免把诊断统计量误写成排除限制或全样本平均效应的证明。

## 范围

新增 `stata-regression/references/iv-identification.md`，只处理以下四个分支。

1. **联合识别**：区分数量条件 `L >= K` 与秩条件；多个工具联合识别多个内生变量，不要求一一配对。修正主 `SKILL.md` 中“每个内生变量至少一把专属工具”的表述。
2. **识别假设与 estimand**：定义 relevance、independence、exclusion、monotonicity 与 SUTVA；区分数据可诊断的相关性/弱识别与必须由制度及研究设计论证的假设。二元工具和二元处理下定义 always-takers、never-takers、compliers、defiers，说明 IV 通常识别 LATE，而非自动识别 ATE、ATT 或全样本平均效应。
3. **结果三角**：要求第一阶段 `Z -> D`、简约式 `Z -> Y`、2SLS `D -> Y` 使用相同样本、外生控制、固定效应、权重与 VCE。恰好识别时说明 Wald ratio。简约式用于结果链一致性检查，不作为排除限制的证据。
4. **论文解释与最低报告**：第一阶段单独成列；报告工具系数、偏 R2、排除性 F/KP F、控制/FE 与聚类层级。主表按弱识别状态选择 2SLS 或 LIML/Fuller，并报告弱工具稳健推断。明确 OLS-IV 差异可能同时来自内生性与不同加权人群的处理效应异质性，不能机械归因。提供正文、表注和外推限制模板。

## 文件边界

| 文件 | 责任 | 变更 |
| --- | --- | --- |
| `stata-regression/SKILL.md` | 路由与高优先级陷阱 | 增加“IV 识别/LATE/第一阶段-简约式-2SLS”路由；以联合秩条件替换“专属工具”规则。 |
| `stata-regression/references/iv.md` | 五命令选择与语法 | 增加到识别文档的 context pointer；不重复识别规则。 |
| `stata-regression/references/iv-testing.md` | 统计检验、弱工具推断、出表 | 增加到识别文档的交叉引用；保留检测命令和统计量解释。 |
| `stata-regression/references/iv-identification.md` | 识别假设、estimand、结果解释、论文写法 | 新建，承载四项范围内容。 |
| `test-prompts.json` | Agent 行为回归场景 | 增加或改造 2-3 条 IV prompt，覆盖 LATE、结果三角及 OLS-IV 差异解释。 |
| `verify/verify-regression.do` | 可执行 Stata 证据 | 增加同一模拟数据/样本/控制/FE/VCE 下的第一阶段、简约式与 2SLS 命令，且不引入新社区包。 |

## 文档结构

`iv-identification.md` 按 Agent 执行顺序组织：

1. 先判定设计是否适用 IV，并画出 `Z -> D -> Y` 与所有可能的 `Z -> Y` 旁路。
2. 将可诊断的条件与只能由设计论证的条件分开列出。
3. 定义系数的目标人群和 LATE 边界；多工具或处理效应异质时禁止把系数直接称为 ATE。
4. 按同一设定运行并报告结果三角。
5. 用论文正文、表注和限制说明模板完成表述。

每一节都以可检查的完成条件收束：识别图已列出旁路、假设逐项说明证据来源、三类回归设定一致、主表和文字没有超出 LATE 的主张。

## 行为要求

新增/调整的行为 prompt 必须验证：

- 遇到二元工具与二元处理时，回答者说明 LATE/compliers 与单调性，而不把 IV 系数默认写为 ATE。
- 回答者列出第一阶段、简约式和 2SLS，并明确三者共享样本、控制、FE、权重和 VCE。
- 回答者不把 reduced form 显著或 Hansen J 不拒绝当作排除限制证明。
- 回答者不把 OLS-IV 差异全部归因于内生性偏差。

## 验证

1. `verify/verify-regression.do` 成功运行新增结果三角段，产生一个 `end of do-file` 且没有 `r(N)`。
2. `bash verify/run-verify.sh regression` 与 `bash verify/test-prompts.sh --prompts` 通过。
3. `bash verify/check-claims.sh`、`bash verify/run-verify.sh --static` 与 JSON 校验通过。
4. 现有社区包 sentinel 语义不变；新增结果三角仅使用官方 Stata 命令。

## 明确排除

本轮不实现控制函数、非线性 IV、shift-share/Bartik、judge leniency、Conley/plausibly exogenous bounds、MTE、少簇推断、动态面板或 system GMM。这些主题都需要额外的识别假设、命令验证和独立验收标准。

## 完成标准

- 新识别文档承担全部 IV 识别与论文解释语义，命令/检验文件只保留指针，避免重复。
- 主 skill 不再要求“专属工具”，而是准确说明数量条件与联合秩条件。
- 所有新增文档规则都有可观察的行为 prompt 或 Stata 验证证据。
- 全部现有 claims、Stata verify 和 prompt 测试保持通过。
