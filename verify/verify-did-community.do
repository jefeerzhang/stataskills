version 19.5
set more off

* ============================================================
* stata-did-community 验证入口（存在凭证）
*
* 本脚本是 stata-did-community skill 的 verify 入口。它本身不承载
* 可执行验证逻辑——该 skill 的社区包（csdid / jwdid / did_imputation /
* synth / sdid）验证集中在 verify-synth-sdid.do。
*
* 为什么不在此直接委托 verify-synth-sdid.do：
*   run-verify.sh 的 run_stata() 对 verify-did-community 这一 target
*   已特判为直接执行 verify-synth-sdid.do（见 run-verify.sh 阶段 3），
*   因此本文件在标准 harness 流程下不会被 do。
*
*   若你手动 `do verify-did-community.do`，Stata batch mode 下
*   c(filename) 返回空（见测试），无法可靠推导同目录路径；且 cwd 可能
*   已被切到 data/agis6/。请在仓库根目录改用：
*
*       bash verify/run-verify.sh did-community
*
*   该命令经 run_stata() 特判，实际执行 verify-synth-sdid.do，并产出
*   verify-did-community.log。
*
* 本文件仅作为 check-claims 第 1 条「skill ↔ verify 脚本一一对应」的
* 存在性凭证存在；不含会执行出错的代码。
* ============================================================

exit
