# ADR-0004：验证目标注册表作为 target → do-file / log 解析的单一来源

## 背景

`verify/run-verify.sh` 与 `verify/check-claims.sh` 中，`did-community → synth-sdid` 的委托关系散落在多处：枚举排除、`run_stata` 的 do-file 换名、`parse_log` 与 `evaluate` 各一次的 log 名换名、`check-claims` 第 1 条的数量排除，外加一份只作「存在性凭证」的占位 `verify-did-community.do`。同一份别名知识在 6 处代码里重复，且 `parse_log` 与 `evaluate` 内部又各重复一次。

## 决策

新增 `verify/lib/targets.sh` 作为验证目标解析的单一来源，暴露两个函数：

- `targets_run_dofile <entry>`：把验证入口解析为实际运行的 do-file 基名（默认恒等；`verify-did-community` → `verify-synth-sdid`）。
- `targets_delegates`：纯委托 do-file 基名清单，供 `check-claims` 孤儿检测放行。

`run-verify.sh` 与 `check-claims.sh` 均 source 该 lib；全量枚举改为按 `stata-*/SKILL.md` 驱动入口，不再 glob `verify-*.do` 再排除。删除占位 `verify-did-community.do`。

## 理由（load-bearing）

1. 委托关系是「一条 seam、多个 adapter」：枚举、执行、日志解析、文档断言四处都要知道 did-community 跑的是 synth-sdid，跨了 seam 泄漏。集中到一处换取 locality。
2. 删除测试：删除 `targets.sh` 会让别名知识重新散回多处 caller，说明该 module 在承载行为，而非 pass-through。
3. 顺带修复一个隐藏缺口：原 `check_version` / `check_data_ready` 跑在占位 `verify-did-community.do`（无 `use` 语句）上，真正的 `verify-synth-sdid.do` 反而未被检查。解析提前后，这些检查落在真文件上。
4. 与 ADR-0003「未来再评估」对齐：社区包验证脚本可能增多，委托 seam 是已记录轨迹上的正确落点，而非 speculative 未来投机。

## 后果

- 新增 skill 的入口由 `stata-*/SKILL.md` 决定，`verify/verify-<name>.do` 必须存在（或经注册表解析为存在的 do-file）。
- 纯委托脚本（如 `verify-synth-sdid.do`）不再需要「存在性凭证」占位文件；`check-claims` 通过 `targets_delegates` 放行孤儿。
- `run-verify.sh synth-sdid`（显式单目标）仍可用——单目标路径不经过全量枚举，`targets_run_dofile` 对 `verify-synth-sdid` 恒等返回。
- 若未来出现多个委托，按 ADR-0003 预告把 `targets.sh` 的两个函数沉淀为 TSV 数据文件。

## 未来再评估

- 若 `stata-did-community` 的验证逻辑扩展为覆盖全部六个社区包方法，`verify-synth-sdid.do` 的命名可能不再准确（它目前验证 synth + sdid 两个），届时重新评估委托命名或拆分脚本。
