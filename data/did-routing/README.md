# `data/did-routing/` — project-generated teaching panels

两个面板用于对比 **`xthdidregress`（吸收型错时）** 与 **`xtswitchdid`（可逆/多值）**。  
不是 AGIS6；由本仓库脚本生成。

## 资产

| 基名 | 观测 | 设计 | 真值 | 推荐命令 |
|---|---|---|---|---|
| `absorbing_staggered` | 4800（400×12） | 二元、吸收、错时开通 | 开通后 ATT≈2 + 0.15×暴露期 | `xthdidregress aipw` |
| `switching_multivalued` | 5000（250×20） | dose∈{0,1,2}，可升降撤销 | 每单位 dose ≈ −0.8 | `xtswitchdid` |

## Provenance

- **Source:** `data/did-routing/build_did_routing.do`
- **Stata:** 19.5；**seed:** `20260928`
- **Rebuild（仓库根目录）:**
  ```bat
  "C:\Program Files\StataNow19\StataMP-64.exe" /e do "data/did-routing/build_did_routing.do"
  ```
- **Analysis demo:** `demo/dofiles/09_xtswitchdid_vs_xthdidregress.do`（先 `use` 本目录 `.dta`，再估计）
- **License:** 项目内合成数据，适用仓库许可证

## Schema

### `absorbing_staggered.dta`

```text
id year cohort treat y
```

- `cohort`: 0=从未处理；1=2014 起吸收处理；2=2017 起吸收处理  
- `treat`: 当期是否已开通（吸收）

数值不变量（build 断言）：`N=4800`；`treat==1` 观测数 `1040`；`mean(treat)=0.21666667`。

### `switching_multivalued.dta`

```text
id year dose x1 y treat_bin treat_abs
```

- `dose`: 真处理（0/1/2，可逆）  
- `treat_bin` / `treat_abs`: **错误编码示例**（供反面教材；主估计勿用）

数值不变量：`N=5000`；存在「曾处理后又回到 0」的观测（`dose==0 & treat_abs==1`）。

## DGP（摘要）

**A：** `y = 10 + 0.3*(year-2010) + u + 1{treated}*(2 + 0.15*exposure) + ε`  

**B：** `y = 10 - 0.8*dose + 0.2*x1 + ε`；一类县路径含 1→2→0 的 switch-out。
