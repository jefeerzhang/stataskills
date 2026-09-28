# `data/did-routing/` — project-generated teaching panels

教学面板，用于 **`xthdidregress`（吸收型错时）** 与 **`xtswitchdid`（可逆/多值及其选项）**。  
不是 AGIS6；由本仓库脚本生成。

## 资产

| 基名 | 观测 | 设计 | 真值 | 用途 |
|---|---|---|---|---|
| `absorbing_staggered` | 4800（400×12） | 二元、吸收、错时 | ATT≈2+0.15×暴露 | 路由：默认 `xthdidregress aipw` |
| `switching_multivalued` | 5000（250×20） | dose 0/1/2，含撤销 | 每单位 ≈ −0.8 | 路由：默认 `xtswitchdid` + 反面编码 |
| `switching_features` | 4480（280×16） | 多路径 + 省嵌套 + 2020 缺失 | 每单位 ≈ −0.7 | 功能点：in/out/path/supergroup/raw/… |

## Provenance

| 文件 | Build | Seed | Demo / 报告 |
|---|---|---|---|
| `absorbing_staggered` / `switching_multivalued` | `build_did_routing.do` | 20260928 | `09_*.do` · REPORT-09 |
| Features | `build_switching_features.do` | 20260929 | `10_*.do` · 讲稿 REPORT-10 |


```bat
"C:\Program Files\StataNow19\StataMP-64.exe" /e do "data/did-routing/build_did_routing.do"
"C:\Program Files\StataNow19\StataMP-64.exe" /e do "data/did-routing/build_switching_features.do"
```

**License:** 项目内合成数据，适用仓库许可证。

## Schema

### `absorbing_staggered.dta`

```text
id year cohort treat y
```

不变量：`N=4800`；`treat==1` 为 1040；`mean(treat)=0.21666667`。

### `switching_multivalued.dta`

```text
id year dose x1 y treat_bin treat_abs
```

- `treat_bin`：错误编码（当期 `dose>0`）  
- `treat_abs`：错误编码（粘性 ever-treated，掩盖撤销；**不是**偷看未来）  

不变量：`dose==0 & treat_abs==1` = 352；首次处理前误标 = 0。  
撤销在暴露期 7 → 主估计用 `neffects(7)`。

### `switching_features.dta`

```text
id year province typ dose x1 y
```

| typ | 含义 |
|---|---|
| 0 | never @ 0 |
| 1 | 0→1→2 停留（switch-in） |
| 2 | 0→2→0（升后撤回） |
| 3 | 初始=1 →2（初始非零） |
| 4 | never @ 1 |
| 5 | 初始=2 →1→0（switch-out） |
| 6 | never @ 2 |

不变量：`N=4480`；2020 年 `y` 缺失 280 条。

## DGP（摘要）

**A：** `y = 10 + 0.3*(year-2010) + u + 1{treated}*(2 + 0.15*exposure) + ε`  

**B：** `y = 10 - 0.8*dose + 0.2*x1 + ε`  

**Features：** `y = 10 - 0.7*dose + 0.2*x1 + 0.15*province + u + ε`（2020 缺失）
