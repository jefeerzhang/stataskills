# 运行 Stata（平台命令速查）

4 份 `stata-*/SKILL.md` 里的「运行 Stata 的方式」只保留平台无关的批处理接口一行；
命令形式与执行机制见本文件；**平台二进制路径的唯一来源是 `verify/stata.conf`**。

## 当前验证环境

本仓库 `verify/` 与 `demo/` 的日志均出自以下环境：

| 项目 | 值 |
|---|---|
| 平台 | macOS（Apple Silicon） |
| Stata | StataNow 19.5，MP — Parallel Edition，Single-user 16-core 永久授权 |
| 可执行文件 | `verify/stata.conf` 的 `STATA_MAC` |
| 批处理方式 | `stata-mp -b do "脚本.do"`（结束生成同名 `.log`） |

## macOS

`stata-mp` 已加入 PATH 时直接使用：

```bash
stata-mp -b do "脚本.do"
```

未加入 PATH 时，用 `verify/stata.conf` 的 `STATA_MAC` 完整路径调用（命令形式同上）。

## Windows

批处理（无界面）：

```bat
"<StataNow 可执行文件路径>" /e do "脚本.do"
```

可执行文件路径见 `verify/stata.conf` 的 `STATA_WIN`。

## 执行机制

- 批处理运行结束后，在当前目录生成与 do-file 同名的 `.log` 文件，内含全部输出。
- `.log` **不含图形输出**；图形需用 `graph export "文件.png", replace` 导出。
- 平台差异只影响「如何调用 Stata」，不影响命令本体；结果解读由各 skill 负责。

## 中文作图的字体乱码（技术原因）

Stata 图形默认使用 PostScript 字体，该字体面向英文字符；中文字符在渲染时缺失，
会输出为乱码/方块。因此：

- 需要生成图形命令（`graph *`、`histogram`、`twoway` 等）且图表文字可能含中文时，
  **先询问用户是否确需中文**，默认按英文标签作图。
- 确需中文时，改用支持中文字符集的图形字体，或在 `graph export` 阶段选择支持中文的方案。

> 行为规矩（先询问用户、默认英文）在每份 SKILL.md 中重复声明——它是 skill 的行为约束，
> 独立分发时必须自带；这里是它背后的技术解释。
