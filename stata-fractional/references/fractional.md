# 分数响应工作流

## 1. 数据 gate

确认 share 是份额 (0–1)、百分数 (0–100)、二元事件，还是成功次数/试验次数。记录精确的 0/1、缺失、分母与重复观测；不要用非缺失断言之外的 `y>=0` 判断范围，因为 Stata 缺失值大于普通数值。

## 2. Fractional logit/probit

```stata
fracreg logit share c.x i.treated, vce(cluster id)
predict double fractional_mean, cm
margins, dydx(x) predict(cm)
margins, dydx(treated) predict(cm)
fracreg probit share c.x i.treated, vce(cluster id)
margins, dydx(x treated) predict(cm)
```

这是 E(share|X) 的模型，可保留真实端点。fractional logit 不是对份额逐行构造二元试验；独立数据可用 robust，重复观测应匹配聚类层级。`i.treated` 的 AME 是离散变化；连续 x 的 logit AME 为样本平均 beta_x*mu*(1-mu)，有交互或非线性项时不能只用单个 beta_x。

AME=0.03 表示 share 增加 0.03，即 3 个百分点，不能说增加 3%。是否能称为处理效应依赖外部识别设计。

## 3. 均值设定诊断

估计后记录范围、收敛、异常标准误，比较观察均值与拟合均值、残差随 x/拟合值的结构。以下为 RESET-type 扩展链接项联合 Wald 检验，并非 Stata 专用官方 `estat` 命令：

```stata
fracreg logit share c.x i.treated, vce(cluster id)
predict double link_index, xb
gen double index_sq = link_index^2
gen double index_cube = link_index^3
fracreg logit share c.x i.treated index_sq index_cube, vce(cluster id)
test index_sq index_cube
```

不拒绝仅表示未发现这组扩展方向的误设，不证明均值正确、外生性或因果识别。检验需要足够独立 clusters；固定生成的链接项形式不能任意替代正式的复杂设定检验。logit/probit 敏感性应在相同样本比较 AME 与校准，而非直接比系数大小。

## 4. Beta 回归

```stata
betareg beta_y c.x i.treated, vce(robust)
predict double beta_mean, cmean
margins, dydx(x treated) predict(cmean)
estat ic
```

标准 beta 要求 0<y<1，并增加条件分布与精度参数假设。fixture 的 `beta_y` 是独立生成的内部份额示例，并非从含端点的 `share` 删除边界。实证数据若需要端点混合模型，应单独论证两个端点与内部过程；不能用任意 epsilon 变换后假装没有改变问题。

Beta 精度不等于回归系数标准误。稳健标准误不使 beta 分布自动正确；按内部条件方差和尾部拟合检查分布合理性。AIC/BIC 只在可比完整似然、相同 outcome 与样本下解释。

## 5. 来源与验证

[Stata fracreg](https://www.stata.com/manuals/rfracreg.pdf)、[Stata betareg](https://www.stata.com/manuals/rbetareg.pdf)，参数与后估计来自本机 StataNow 19.5 help。`verify/verify-fractional.do` 生成固定种子数据，验证边界保留和 AME 的解析恒等式；诊断检验不以随机 p 值过线作为软件正确性标准。
