# data/webuse/ — Stata 官方 webuse 数据集（项目本地副本）

> **不要把这里的 `.dta` 加进 `data/manifest.txt`**。本目录是项目从 StataCorp
> 官方站点下载并固化下来的 `webuse` 数据集本地副本，用于让 `verify-` 脚本
> 在**离线 / 网络受限**环境下仍可稳定复现（详见 verify/run-verify.sh
> 关于"非 agis6 数据集"的契约段）。由 `data/manifest-extra.txt` 单独管理。

## 资产清单

| 基名 | 字节数 | 字节校验值 | 来源 | 许可 | 用途 |
|---|---|---|---|---|---|
| `laborsub` | 3501 | `wc -c` 必须等于 3501 | https://www.stata-press.com/data/r16/laborsub.dta（StataCorp 官方 webuse 库） | 见下方「许可」段 | `stata-coefplot` 第 17 节系数匹配（`eqstrict` / `asequation` / `noeqlabels` / `rename`），原 SKILL.md 示例用 `webuse laborsub` 取数 |

## 许可

`laborsub.dta` 是 StataCorp 官方发行数据集，随 Stata 一起授权用户使用（详见
Stata EULA）。本目录是该数据集的本地副本，仅用于离线复现仓库 `verify/` 脚本。
不二次分发；上游变更许可时本目录的处置应跟随 StataCorp EULA。

## 更新流程

如需更新本目录下某数据集（例如上游修了字段、新增变量）：

1. 跑 `bash data/webuse/download_laborsub.sh`（脚本内含字节数校验，差异超过阈值时拒绝覆盖）
2. 重新跑 `bash verify/run-verify.sh coefplot`，确认验证通过
3. 更新本 README 的"字节校验值"列
4. 提交时单独成一个 commit（与 verify 脚本 / SKILL.md 的改动分开）

## 为什么用单独目录而非 `data/agis6/`？

`data/manifest.txt` 顶部注释明确写："这是 `data/agis6/` 下 `.dta` 文件的单一来源"。
AGIS6 数据集与教材章节一一对应、来源稳定、CI 上无需网络下载。本目录的数据集是
**StataCorp webuse 库的本地副本**，与教材解耦、来源是 StataCorp 而非 AGIS6 教材
配套，单独管理以保护 `data/manifest.txt` 的"AGIS6 单一来源"语义不被稀释。

## 与 `data/synth/` 的区别

- `data/synth/`：第三方研究示例数据集（scunning1975/mixtape），需项目自维护字节校验 + 下载脚本
- `data/webuse/`：StataCorp 官方 webuse 库（一手来源稳定），字节校验价值是"防止本地副本意外被改"

两个目录都走 `data/manifest-extra.txt` 登记，harness 校验机制相同。