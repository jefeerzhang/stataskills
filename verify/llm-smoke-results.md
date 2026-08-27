# LLM 冒烟测试台账（T1）

> 日期：2026-08-27 · 环境：claude CLI 2.1.246（OAuth 登录，无 ANTHROPIC_API_KEY）· 仓库根目录直调 `claude -p`
> 范围：3 条代表 prompt（路由 / 方法执行 / 直接点名入口），验证 harness 通路，非全量。

## 1. 环境与前置发现

1. **harness 硬性要求 ANTHROPIC_API_KEY**（`verify/test-prompts.sh` L523–526）：
   未设置时 `--llm` 模式直接 `SKIP ... exit 0`，即使 claude CLI 已有 OAuth 登录态。
   本机 claude CLI 2.1.246 已 OAuth 登录（`~/.claude/.credentials.json` 存在），`claude -p` 直调可用。
2. **通路结论**：`claude -p "<scenario>" --output-format text` 在仓库根目录可正常出响应（rc=0），
   关键词判定算法（`run_llm_mode` 同款）可跑通；3 条 prompt 消费正常，无配额异常。
3. **行为观察**：`claude -p` 直调不会自动加载仓库 skill 文件——`stata-identification` 的
   router-entry 场景直接凭列名路由到 DID，未走 decision tree / stop rules（见下）。

## 2. 冒烟结果（harness 同款判定算法）

| id | skill / branch | 判定 | 命中 expected_action 关键词 | 质量备注 |
|---|---|---|---|---|
| identification-01-router-entry | stata-identification / router-entry | **FAIL** | 无 | 凭列名直接跳 DID；未加载 router/decision tree、未先定义 estimand、未要求制度或设计证据——违反 router 契约（详见 T3） |
| did-02-csdid-staggered | stata-did-community / - | PASS | `ssc install drdid csdid`（响应含 csdid） | 命令链正确：csdid + notyet + method(dr) + estat event + 手动事件研究图；缺失 estat group/simple 属深度问题，非通路问题 |
| identification-09-psmatch2-direct | stata-selection / named-method-direct | PASS | `gate 通过后进入 stata-selection/references/psmatch2.md` | 正确直接进入 stata-selection、引用 psmatch2.md、区分 ATT/ATET estimand、带探测式代码 |

原始响应保留在 `.scratch/llm-smoke/*.response`（不入库）。

## 3. 结论与对 T2 的建议

- 通路可行：OAuth 下 `claude -p` 可跑、判定可跑、配额消耗正常——**T2 全量 27 条可以跑**。
- 认证决策（2026-08-27）：用户选择 **(b)**，已实施——`verify/test-prompts.sh` 的 `--llm` 闸口
  现为「API key **或** OAuth 登录态（~/.claude/.credentials.json）任一可用即放行」，与仓库
  「CI 不绑定密钥」理念一致；T2 全量在 OAuth 下执行。改动文件：`verify/test-prompts.sh`。
  - (a) 设置 `ANTHROPIC_API_KEY` 环境变量（保持当前 harness 不动）；
  - (b) 修改 `test-prompts.sh`：claude CLI 存在且（API key 或 OAuth 凭据）任一可用即放行
    ——与仓库"CI 不绑定密钥"理念一致，推荐 (b)。
- router-entry FAIL 列入 T3 归类：疑为「行为缺陷」（直调未加载 skill 导致契约不达），
  也可能是 prompt 形态问题（场景未显式要求加载 skill 文件），需 T3 判别。