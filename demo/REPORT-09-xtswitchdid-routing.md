# 报告：吸收型 vs 可逆多值 DID 路由模拟

> 配套数据：`data/did-routing/absorbing_staggered.dta`、`switching_multivalued.dta`  
> 重建：`do data/did-routing/build_did_routing.do`（Stata 19.5，seed `20260928`）  
> 分析：`demo/dofiles/09_xtswitchdid_vs_xthdidregress.do`  
> 证据：`demo/logs/09_xtswitchdid_vs_xthdidregress.log` + `demo/output/09_*.png`  
> 路由速查：[`docs/learn-did-routing-absorbing-vs-switching.md`](../docs/learn-did-routing-absorbing-vs-switching.md)

本报告记录一次**可复现**的对照实验：同一套磁盘数据上，正确命令 vs 错误编码，给出本机 StataNow 19.5 实测数字与路由结论。

---

## 0. 摘要

| 场景 | 数据 | 正确命令 | 关键估计 | 反面结果 |
|---|---|---|---|---|
| A 吸收错时 | `absorbing_staggered`（N=4800） | `xthdidregress aipw` | overall ATET **2.33**（se 0.11） | 同数据 `xtswitchdid` 可跑，`estat total`≈2.15（参数语义不同） |
| B 多值可逆 | `switching_multivalued`（N=5000） | `xtswitchdid` | exposure1 **−0.74**；total **−0.85** | `treat_bin`→`xthdidregress` **r(498)**；`treat_abs` 能出数但偷看未来 |

**结论：** 处理形态决定命令，不能反过来。吸收二元错时用 `xthdidregress`；离散可逆/多值用 `xtswitchdid`。把可逆处理二值化或 ever-treated 化硬套吸收命令，要么直接报错，要么给出错误识别的「看起来像 ATET」的数。

---

## 1. 环境与复现

| 项目 | 详情 |
|---|---|
| Stata | StataNow 19.5 MP（revision ≥ 2026-07-29，含 `xtswitchdid`） |
| Seed | `20260928`（两份 `.dta` 各自独立重置 seed 生成） |
| 操作系统 | Windows 10 |
| 日志 | `demo/logs/09_xtswitchdid_vs_xthdidregress.log`（exit=0，含 `DONE_ROUTING_DEMO`） |

```stata
do "data/did-routing/build_did_routing.do"
do "demo/dofiles/09_xtswitchdid_vs_xthdidregress.do"
```

---

## 2. 数据设计

### 2.1 场景 A — `absorbing_staggered.dta`

- 400 县 × 12 年（2010–2021），N=4800  
- `cohort`：0 从未处理；1 自 2014 吸收开通；2 自 2017 吸收开通  
- `treat`：吸收型 0/1  
- DGP：开通后 ATT ≈ **2 + 0.15×暴露期**  
- 不变量：`treat==1` 观测 1040；`mean(treat)=0.2167`

### 2.2 场景 B — `switching_multivalued.dta`

- 250 县 × 20 年（2006–2025），N=5000  
- `dose` ∈ {0,1,2}，一类县含 **1→2→0** 的 switch-out  
- DGP：每单位 dose 效应 ≈ **−0.8**  
- 反面编码（仅供错误演示）：`treat_bin = (dose>0)`；`treat_abs` = ever-treated（偷看未来）

Schema / DGP 全文见 `data/did-routing/README.md`。

---

## 3. 场景 A 实测：`xthdidregress aipw`

```stata
use "data/did-routing/absorbing_staggered.dta", clear
xtset id year
xthdidregress aipw (y) (treat), group(id)
estat aggregation, overall
estat aggregation, dynamic
estat ptrends
```

### 3.1 主结果

| 量 | 估计 | se | 说明 |
|---|---|---|---|
| Overall ATET | **2.334** | 0.106 | 贴近真值「2 + 动态」 |
| Exposure = 0 | **1.816** | 0.132 | 开通当年 |
| Exposure = 1 | **2.072** | 0.132 | 随后升高 |
| Exposure = 2 | **2.225** | 0.114 | 与 DGP 逐年略增一致 |
| `estat ptrends` | χ²(9)=12.85 | p=**0.170** | 未拒事前平行趋势 |

Cohort 结构：never=2880，2014 cohort=960，2017 cohort=960。

### 3.2 事件研究图

![吸收型 xthdidregress 动态 ATET](output/09_absorbing_xthdid_dynamic.png)

### 3.3 对照：同数据 `xtswitchdid`

```stata
xtswitchdid (y) (treat), group(id) neffects(4)
estat total
```

- Header：**Absorbing = Yes**（命令识别为吸收）  
- `estat total` ≈ **2.150**  
- 报告的是 **normalized exposure effects**，不是 AIPW 的 ATET 表  

**路由：** 论文若声称 ATET / 事件研究聚合 → 主路径仍是 `xthdidregress aipw`；`xtswitchdid` 最多作稳健性。

---

## 4. 场景 B 实测：`xtswitchdid`

```stata
use "data/did-routing/switching_multivalued.dta", clear
xtset id year
xtswitchdid (y x1) (dose), group(id) neffects(3)
estat ptrends
estat paths
estat total
estat eventplot
```

### 4.1 主结果

| 量 | 估计 | se | 说明 |
|---|---|---|---|
| Exposure 1（归一化） | **−0.738** | 0.134 | 贴近真值 −0.8 |
| Exposure 2 | **−0.496** | 0.065 | — |
| Exposure 3 | **−0.283** | 0.042 | — |
| `estat total`（每单位 dose） | **−0.853** | 0.106 | 总效应汇总 |
| `estat ptrends` | χ²(3)=3.93 | p=**0.269** | 安慰剂未拒 |
| Header Absorbing | **No** | — | 明确非吸收 |

`dose` 分布：0 = 3794（75.9%），1 = 707，2 = 499。

### 4.2 路径分布（`estat paths`，path length 3）

| Path | Freq | Percent |
|---|---|---|
| `0 1 1 1` | 96 | 78.05 |
| `0 1 1 2` | 5 | 4.07 |
| `0 2 2 2` | 22 | 17.89 |

### 4.3 事件图

![可逆多值 xtswitchdid eventplot](output/09_switching_xtswitchdid_event.png)

**路由：** 多值 + 可撤销 → **`xtswitchdid` 是默认主路径**。

---

## 5. 反面教材（必须保留）

### 5.1 `treat_bin` → `xthdidregress` → **r(498)**

```stata
xthdidregress aipw (y) (treat_bin), group(id)
```

```text
invalid treatment
The treatment is assumed to be staggered. Once a unit is treated,
it should remain treated.
r(498)
```

这是**设计信号**：可逆路径不能硬套吸收型 staggered 命令。

### 5.2 `treat_abs`（ever-treated）→ 能出数，但识别错

```stata
xthdidregress aipw (y) (treat_abs), group(id)
estat aggregation, overall
```

- `_rc = 0`，overall ATET ≈ **−1.013**（se 0.116）  
- 限产前年份也被标成处理组 → **偷看未来**  
- 能出系数 ≠ 识别正确  

---

## 6. 路由卡（投稿前）

```text
1. 0/1 且永久开通 + 错时 → xthdidregress aipw
2. 多档或可撤销 → xtswitchdid
3. 连续剂量 / HAD → did_multiplegt / did_had（社区包）
```

- [ ] 处理编码与故事一致（吸收 vs 可逆）  
- [ ] 吸收错时主表是 AIPW + 动态聚合，不是 plain TWFE  
- [ ] 可逆/多值未二值化后硬套 hdid 系  
- [ ] 若见 **r(498)**：改命令族，不是「换选项」  
- [ ] 目标参数写清：ATET vs normalized exposure / `estat total`  

---

## 7. 产物清单

| 文件 | 作用 |
|---|---|
| `data/did-routing/absorbing_staggered.dta` | 场景 A 面板 |
| `data/did-routing/switching_multivalued.dta` | 场景 B 面板 |
| `data/did-routing/build_did_routing.do` | 重建脚本 |
| `demo/dofiles/09_xtswitchdid_vs_xthdidregress.do` | 估计 + 出图 |
| `demo/logs/09_xtswitchdid_vs_xthdidregress.log` | 全量运行日志 |
| `demo/output/09_absorbing_xthdid_dynamic.png` | A 动态 ATET 图 |
| `demo/output/09_switching_xtswitchdid_event.png` | B 事件图 |
| `docs/learn-did-routing-absorbing-vs-switching.md` | 路由学习卡（精简版） |

---

*本报告数字与 `demo/logs/09_xtswitchdid_vs_xthdidregress.log` 同源；重跑以 log 为准。*
