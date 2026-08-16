#!/usr/bin/env bash
# ============================================================
# PASS/FAIL 报告协议：verify 脚本群的共享 interface。
#
# 用法：source "$VERIFY_DIR/lib/report.sh"
#   ok   "描述"   → 打印 PASS 并递增 pass 计数
#   bad  "描述"   → 打印 FAIL 并递增 fail 计数
#   summary       → 打印汇总行并以 $fail == 0 返回
# ============================================================
pass=0
fail=0
ok()      { echo "PASS  $1"; pass=$((pass+1)); }
bad()     { echo "FAIL  $1"; fail=$((fail+1)); }
summary() { echo; echo "结果：${pass} 通过，${fail} 失败"; [ "$fail" -eq 0 ]; }
