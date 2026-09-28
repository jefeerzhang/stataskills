---
name: stata-did-xtswitchdid
description: StataNow 内置可逆/多值处理 DID：xtswitchdid（de Chaisemartin & D'Haultfœuille 异质性稳健事件研究）。主文件见 stata-did/SKILL.md。
---

# stata-did-xtswitchdid

> **加载时机**：主 `SKILL.md` 强制路径已命中「处理可逆 / 离散多值 / 非吸收」时加载本文件。

> **边界约定**：本文件只补详细签名与工作流。陷阱统一在主 `SKILL.md`「关键陷阱速查」维护。

---

## 何时用

`xtswitchdid` 估计面板上的**事件研究效应**（normalized exposure effects），允许：

- 处理**可逆**（nonabsorbing：开了又可关、或升/降剂量）
- 处理**离散多值**（0/1/2/…，如安全规则条数）
- 组不必从 0 开始观测（可有正的 initial treatment）

理论：de Chaisemartin & D'Haultfœuille (2026) 异质性稳健 DID；与社区包 `did_multiplegt (dyn)` 同源问题族，但是 **StataNow 官方内置**（[CAUSAL] xtswitchdid），无需 `ssc install`。

**不要用 `xtswitchdid` 的场景**（踢走）：

| 场景 | 去向 |
|---|---|
| 二元吸收错时、要 ATET / AIPW | `xthdidregress aipw`（本 skill 第 6 节） |
| 连续剂量 / IV-DID / HAD 无 stayer | `stata-did-community` → `did_multiplegt` / `did_had` |
| 少数处理单位 + 长前期 | `synth` / `sdid` |
| 分数线 / 年龄门槛 / 地理边界 | `stata-rdd` |

**版本门槛**：StataNow 19；需 revision ≥ **2026-07-29**（引入该命令的更新）。本机探测：`which xtswitchdid` 应指向 `ado/base/x/xtswitchdid.ado`。

---

## 核心语法

必须先 `xtset` 面板与时间。语法骨架与 `xthdidregress` 类似：第一对括号结局（+ 协变量），第二对括号处理变量；**没有 `time()`**（时间来自 `xtset`）。

```stata
xtset team year
xtswitchdid (injdays lwinpct schedule) (safety), group(team)
```

| 要素 | 含义 |
|---|---|
| `(ovar [omvarlist])` | 结局 + 可选协变量（可含因子变量） |
| `(tvar)` | 处理水平（二元或离散多值；可随时间变化） |
| `group(groupvar)` | **必填**；处理发生的组层；默认也作聚类 |
| 面板变量 | 由 `xtset` 设定；须嵌套在 `group()` 内 |

### 常用选项

| 选项 | 作用 | 默认 / 备注 |
|---|---|---|
| `neffects(#)` | 最多估计多少个暴露期效应（从 ℓ=1 起） | 默认尽量多；演示用 `neffects(3)` |
| `commonswitchers` | 所有暴露期用同一批 switcher | 不加则短暴露期样本量更大 |
| `switchgroup(all\|in\|out)` | 只用升剂量 / 降剂量 / 全部 switcher | `all` |
| `controlgroup(all\|never)` | 对照：全部可用 vs 仅 never-switcher | `all` |
| `path(pathspec)` | 只估某一处理路径的效应 | 常与 `estat paths, generate()` 联用 |
| `supergroup(var)` | 只在同一超组内比较（如县嵌套州） | 可选 |
| `raw` | 报告未归一化效应 | 默认报告 normalized |
| `vce(cluster clustvar)` 等 | 推断 | 默认按 `group()` 聚类 |

报告的是 **normalized** 事件研究效应：相对「处理保持在初始水平」的反事实，暴露 ℓ 期后、按剂量变化归一化后的平均效应。

---

## 最短工作流（实测）

数据：官方 `webuse hockey`（也可本地模拟同等结构）。本仓库 verify 用本地模拟，不依赖网络。

```stata
version 19.5
webuse hockey, clear
xtset team year

* 1. 主估计：多值 + 可切换的 safety
xtswitchdid (injdays lwinpct schedule) (safety), group(team) neffects(3)

* 2. 平行趋势 / 无预期：安慰剂期联合检验
estat ptrends

* 3. 事件研究图
estat eventplot

* 4. 看处理路径分布（会生成 _did_paths）
estat paths

* 5. 平均总效应（每单位处理）
estat total
```

路径特定效应（可选）：

```stata
quietly estat paths, generate(safetypath)
* 选一条路径指示变量再估，例如：
xtswitchdid (injdays lwinpct schedule) (safety), group(team) ///
    path(safetypath5) neffects(3)
```

---

## 与 `xthdidregress` / `did_multiplegt` 对照

| 维度 | `xthdidregress` | `xtswitchdid` | `did_multiplegt (dyn)` |
|---|---|---|---|
| 来源 | Stata 内置 | **StataNow 内置** | SSC 社区包 |
| 处理形态 | 二元吸收 | 二元/多值，**可逆** | 二元/多值/连续，可逆 |
| 目标 | ATET / cohort·动态聚合 | normalized 事件研究 + `estat total` | 事件研究 / 归一化效应 |
| 面板 | 要 `xtset` | 要 `xtset` | 位置参数 G T |
| 何时优先 | 吸收错时默认 | **离散可逆/多值** | 连续剂量、HAD、点名 DCDH、无 StataNow 更新 |

**默认**：离散可逆或多值切换 → `xtswitchdid`。连续剂量或 HAD → 社区包。

---

## 事后命令速查

| 命令 | 作用 |
|---|---|
| `estat ptrends` | 安慰剂期效应 + 平行趋势与无预期联合检验 |
| `estat eventplot` | 事件研究图（批处理可跑；**不要**写 `nograph`，会报 not allowed） |
| `estat paths` | 处理路径频数表；可 `generate()` 出路径指示 |
| `estat total` | 平均总效应（每单位处理） |
| `estat aggregation` | **无效**（那是 `hdidregress` 系） |

---

## 参考文献

- de Chaisemartin, C., & D'Haultfœuille, X. (2026). Difference-in-Differences Estimators of Intertemporal Treatment Effects. *Review of Economics and Statistics*（方法基础；与 `did_multiplegt_dyn` 同族）.
- StataCorp. [CAUSAL] **xtswitchdid** — Difference in differences with switching treatments for panel data（StataNow）.  
  手册 PDF：https://www.stata.com/manuals/causalxtswitchdid.pdf  
  功能页：https://www.stata.com/statanow/DID-with-switching-treatments-for-panel-data/
- Stata Blog (2026-07-29). A new update to StataNow…（引入 `xtswitchdid`）.

社区对照实现见 `stata-did-community/references/dcdh.md`。
