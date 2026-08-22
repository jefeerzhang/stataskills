version 19.5
set more off

* ============================================================
* stata-did-community 验证脚本：委托 verify-synth-sdid.do
*
* 本脚本是 stata-did-community skill 的 verify 入口。
* 社区包（csdid / jwdid / did_imputation / synth / sdid）的
* 实际验证逻辑在 verify-synth-sdid.do 中，此处直接调用。
*
* 路径处理：run-verify.sh 把 cwd 切到 data/agis6/，相对路径找不到
* verify-synth-sdid.do。run-verify.sh 在调用前 export VERIFY_DIR（绝对路径），
* 此处用 getenv() 读取。
* ============================================================

local verify_dir = "`c(filename)'"
local verify_dir = substr("`verify_dir'", 1, max(1, length("`verify_dir'") - length("verify-did-community.do")))
if "`verify_dir'" == "" {
  di as error "无法推导 verify 目录路径（c(filename) 为空）；请从项目根目录运行 run-verify.sh"
  exit 601
}
do "`verify_dir'verify-synth-sdid.do"
