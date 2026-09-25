#!/usr/bin/env bash
# ============================================================
# 事故锁：CHANGELOG [Unreleased] Added 措辞（#29 C1）
#
# 与 check-claims.sh 分居，因为它守护的是发布台账本身，不属于任何 skill。
# 可独立运行、独立回归：
#   bash verify/claims/changelog.sh
# CLAIMS_REPO_ROOT 可覆盖仓库根（供 test-claims.sh 造红 fixture）。
#
# 锁：不得保留已否决/错误的 PR-A/D 措辞
#   #15 明确不加「特征对照矩阵 TROP 列」；TROP = Triply Robust（非 Targeted Robust OP）；
#   #1 AC 为 method(dr)/method(ipw)，不是 method(dripw)。
# Fixed 小节允许按原文记录已经修复的错误，否则修复台账本身会触发禁词误报。
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="${CLAIMS_REPO_ROOT:-$(cd "$VERIFY_DIR/.." && pwd)}"

# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"

CL="$REPO_ROOT/CHANGELOG.md"
if [ -f "$CL" ]; then
  cl_unreleased_added=$(awk '
    /^## \[Unreleased\]/{unreleased=1; next}
    unreleased && /^## \[/{exit}
    unreleased && /^### Added/{added=1; next}
    added && /^### /{exit}
    added
  ' "$CL")
  cl_bad=""
  echo "$cl_unreleased_added" | grep -q 'method(dripw)' && cl_bad="${cl_bad} method(dripw);"
  echo "$cl_unreleased_added" | grep -q 'Targeted Robust OP' && cl_bad="${cl_bad} Targeted Robust OP;"
  echo "$cl_unreleased_added" | grep -q '特征对照矩阵 TROP 列' && cl_bad="${cl_bad} 特征对照矩阵 TROP 列;"
  if [ -n "$cl_bad" ]; then
    bad "CHANGELOG [Unreleased] Added 含已否决/错误措辞：${cl_bad}"
  else
    ok "CHANGELOG [Unreleased] Added 无 dripw / Targeted Robust OP / 矩阵 TROP 列漂移"
  fi
fi

summary
