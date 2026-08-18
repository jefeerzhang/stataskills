version 19.5
set more off

* ============================================================
* stata-did-community 验证脚本：委托 verify-synth-sdid.do
*
* 本脚本是 stata-did-community skill 的 verify 入口。
* 社区包（csdid / jwdid / did_imputation / synth / sdid）的
* 实际验证逻辑在 verify-synth-sdid.do 中，此处直接调用。
* ============================================================

do "verify/verify-synth-sdid.do"
