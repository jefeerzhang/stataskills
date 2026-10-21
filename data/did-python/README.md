# `data/did-python/` — Python 补位层的生成数据

两个项目内生成的教学面板，供 `stata-did-community/python/did_py.py` 与
`verify/verify-did-python.sh` 使用。不是 AGIS6；无外部来源，无再分发。

## 资产

| 基名 | 观测 | 设计 | 真值 | 用途 |
|---|---|---|---|---|
| `panel_staggered` | 1440（180×8） | 错时处理，cohort 0/3/5/7；单位内剂量不变 | 每单位约 `1.2 × dose` | `continuous` / `dml` / `efficient` |
| `spell_duration` | 2400（240×10） | 两组同时点；二元吸收态（spell 结束） | 未处理风险：对照组 0.05；处理组第 6 期起 0.12 | `duration` |

## Provenance

| 项 | 值 |
|---|---|
| 生成脚本 | `build_did_python.py`（checked-in） |
| Seed | 20261021（duration 面板用 20261022） |
| pandas | 3.0.3 |
| numpy | 2.4.6 |
| Stata 格式 | version 118 |

## DGP

`panel_staggered`：

```
g_i ~ choice({0,0,3,5,7})            # 0 = never treated
dose_i = U(0.5, 3) if g_i > 0 else 0  # 单位内不随时间变
a_i, x1_i, x2_i ~ N(0,1)
D_it = 1[t >= g_i]
y_it = a_i + 0.3 t + 1.2 * dose_i * D_it + 0.5 x1_it + e_it,  e ~ N(0, 0.3)
```

`spell_duration`：

```
treat_i = 1[i 为偶数]
h_it = 0.12 if (treat_i == 1 and t >= 6) else 0.05
spell_end_i = min{ t : U(0,1) < h_it }
y_it = 1[t >= spell_end_i]          # 一旦结束保持 1
```

## 数值不变量

`verify/verify-did-python.sh` 断言以下内容：

- 四个子命令都可跑通，`att` / `se` 有限，`n_obs > 0`。
- `json` / `csv` / `dta` 三种格式都能读回；`dta` 恰好一行。
- `dta` 产物能在本机真实 Stata 中 `use`（无 Stata 的机器此段跳过）。
- 三条设计护栏报错：`dml` 缺协变量、`duration` 收到非二元结果、退化设计返回 NaN 头条时必须 fail closed。

真值方向不变量（人工核对，不进 harness 断言）：`continuous` 的
`overall_acrt` 应接近 1.2；`duration` 的处理组吸收更快，ATT 为正。

## 维护

改 DGP 或 seed 后必须重跑 `build_did_python.py` 并提交新的 `.dta`，同时更新
`data/manifest-extra.txt` 与本文件的不变量段。两份 `.dta` 已登记在
`manifest-extra.txt`。
