# data/synth/ — 项目级扩展数据集（区别于 AGIS6）

> **不要把这里的 `.dta` 加进 `data/manifest.txt`**。AGIS6 是教材配套数据集的
> 单一来源；本目录是项目自己额外使用的、与具体技能章节强相关、来源
> 非 AGIS6 的数据集，受 `data/manifest-extra.txt` 单独管理。
>
> 验证 harness 见 `verify/run-verify.sh --help`（同时校验 agis6 +
> manifest-extra两份清单；`--community` 模式额外执行依赖社区包的命令）。

## 资产清单

| 基名 | 字节 | 字节数校验 | 来源 | 许可 | 用途 |
|---|---|---|---|---|---|
| `synth_smoking` | 47045 | `wc -c` 必须等于 47045 | https://github.com/scunning1975/mixtape（commit 由 `download_synth_smoking.sh` 锁定） | 见下方「许可」段 | `stata-did` 第 14 节合成控制示例（加州 1989 Prop 99 经典案例） |

## 许可

`scunning1975/mixtape` 仓库整体采用 MIT 许可（见 `https://github.com/scunning1975/mixtape/blob/master/LICENSE`）。
本目录的数据集是该项目产物在该许可下的再分发。如上游变更许可，项目应同步评估。

## 更新流程

如需更新本目录下某数据集（例如上游修了字段、新增变量）：

1. 跑 `bash data/synth/download_synth_smoking.sh`（脚本内含字节数校验，差异超过阈值时拒绝覆盖）
2. 重新跑 `bash verify/run-verify.sh did --community`，确认验证通过
3. 更新本 README 的"字节数校验"列
4. 提交时单独成一个 commit（与 SKILL.md / verify 脚本的改动分开）

## 为什么用单独目录而非 `data/agis6/`？

`data/manifest.txt` 顶部注释明确写："这是 `data/agis6/` 下 `.dta` 文件的单一来源"。
AGIS6 数据集与教材章节一一对应、来源稳定、CI 上无需网络下载。本目录的数据集
是**社区包示例**或**外部研究的衍生数据**，与教材解耦，单独管理以保护
`data/manifest.txt` 的"单一来源"语义不被稀释。