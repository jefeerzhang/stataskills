# ADR-0007：verify raw log 不再入库，证据改为可重跑的断言与标记

- 状态：Accepted（2026-09-10）。取代 ADR-0005。

## 背景

ADR-0005 曾否决「不提交 raw log」的候选，理由是完整 transcript 对 reviewer 和审计
有价值，且用户明确选择保留。执行一段时间后的实测代价：

- 一次覆盖 10 个 commit 的 code review 引入约 5000 行新增，其中约 2400 行是
  `verify/*.log`。真实的语义改动（约 250 行 shell 与 do-file）被完全淹没。
- 跨平台重跑（macOS / Windows 的版本横幅、许可、绝对路径不同）产生的 diff 与逻辑
  改动无法区分，reviewer 只能跳过 log。
- 更关键的是 **stale log 可以长期掩盖真实回归**：仓库没有任何机制校验
  `verify/<name>.log` 是否由当前 `<name>.do` 生成。一份全绿的旧 log 可以在 do-file
  已经改坏之后继续留在仓库里充当「证据」。
- 本次 review 中还发现 log 会主动撒谎：`verify/verify-dynamic-panel.log` 被 judge
  判读时报告「xtabond2 未安装已跳过」，而同一份 log 内 `xtabond2` 的工具数、Hansen
  p 值与成功标记俱在。原因是单行 `if !.. display "SENTINEL"` 的回显行以 `. if`
  开头，逃过了 judge 的 `. display` 回显过滤。

## 决策

1. `verify/*.log` 取消跟踪并写入 `.gitignore`。`run-verify.sh` 仍在本地生成并
   `cp` 到 `verify/<name>.log`，供本机阅读，只是不再进仓库。
2. 验证证据改由两类**可重跑**的产物承担：
   - `.do` 内的 `assert`（结构性与交叉不变量，不再是「命令没报错」）；
   - `display "VERIFY_MARKERS_REQUIRED=<M1> <M2> ..."` 声明式标记契约。
3. `judge.sh` 不再硬编码任何 marker 名单，只解释日志里观察到的声明——与
   `community.sh` 对 package 名单的既有约定一致。未声明标记的入口行为不变。
4. 标记必须由标量断言托底，不能只看 return code。实测教训：
   `estat sargan` 在 `vce(robust)` 下打印 "cannot calculate"，但 `_rc` 仍为 0，
   必须 `assert e(sargan) < .` 才能区分「算出来了」与「静默没算」。
5. `demo/logs/*.log` **继续入库**。它是 `check-claims.sh` 的硬依赖（缺失即 BAD），
   且承担 ADR-0002 的 demo 全景层职责，与 verify 证据不是同一类东西。

## 后果

- review diff 只剩语义改动；log 刷屏问题消失。
- 失去「某台机器某时刻实际跑过什么」的 transcript。补偿：证据在同一份 `.do` 里，
  任何人执行 `bash verify/run-verify.sh <skill>` 即可复现，比只能读旧 log 更强。
- README 与各 SKILL 的「本机实测 PASS」声明重新变成**不可核验**的自述。任何此类
  当前态声明都必须能指回一条可重跑的 assert 或 marker，否则不得写入。
- CI 不受影响：四道静态门禁均不读 `verify/*.log`（`--static` 不执行 Stata，
  docs 模式只 `grep` 文档与 `demo/logs/`，且缺关键词只 WARN）。

## 未来再评估

- 若需要跨机器的验证留档，走 CI artifacts 上传 raw log，而不是让它进 git。
- 若要给 log 加新鲜度校验（log 内指纹 ↔ `.do` 内容），应先于恢复入库考虑。
