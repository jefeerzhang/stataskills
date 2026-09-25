#!/usr/bin/env bash
# ============================================================
# 回归测试：事故锁 seam（verify/claims/*.sh，#29 C1）。
#
# 事故锁从 check-claims.sh 下沉为按 owner 分居、可独立运行的文件后，本测试
# 守住三件事：
#   1. 每个 claims 文件对当前仓库为绿（独立运行 interface，exit 0）；
#   2. 每条锁 red-capable：经 CLAIMS_REPO_ROOT 指向造好的漂移 fixture 时
#      必须非零退出并报告漂移（否则锁只是摆设）；
#   3. 聚合器契约：check-claims.sh 发现式聚合 claims/，且已下沉的事故锁短语
#      不得回流（回流即说明下沉被撤销）。
#
# 用法：bash verify/test-claims.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"

CLAIMS_DIR="$VERIFY_DIR/claims"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/stataskills-claims.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ---- 1. seam 形状 ----
if [ -d "$CLAIMS_DIR" ]; then
  ok "claims seam 存在：verify/claims/"
else
  bad "缺 verify/claims/ 目录（事故锁须按 owner 分居）"
fi
claims_files=0
for cf in "$CLAIMS_DIR"/*.sh; do
  [ -f "$cf" ] || continue
  claims_files=$((claims_files + 1))
done
if [ "$claims_files" -ge 1 ]; then
  ok "claims 文件存在（${claims_files} 个）"
else
  bad "verify/claims/ 下无 .sh 文件"
fi

# ---- 2. 每条锁对当前仓库为绿（独立运行 interface）----
for cf in "$CLAIMS_DIR"/*.sh; do
  [ -f "$cf" ] || continue
  cf_name="$(basename "$cf")"
  if bash "$cf" >/dev/null 2>&1; then
    ok "claims/${cf_name} 对当前仓库 exit 0"
  else
    bad "claims/${cf_name} 对当前仓库非零退出（bash verify/claims/${cf_name} 可见详情）"
  fi
done

# ---- 3. red-capable：漂移 fixture 必须让锁变红 ----

# 3a. did-community 计数漂移：description 10 个方法 vs 正文 9 个社区包
mkdir -p "$WORKDIR/dc-count/stata-did-community/references"
cat > "$WORKDIR/dc-count/stata-did-community/SKILL.md" <<'EOF'
---
description: 社区包（10 个方法）
---
## 详细方法参考
| `did_imputation` | [csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
## 正文
共 9 个社区包可用。
EOF
dc_out="$(CLAIMS_REPO_ROOT="$WORKDIR/dc-count" bash "$CLAIMS_DIR/did-community.sh" 2>&1)" && dc_rc=0 || dc_rc=$?
if [ "$dc_rc" -ne 0 ] && printf '%s\n' "$dc_out" | grep -q '计数漂移'; then
  ok "red-capable：did-community 计数漂移被捕获"
else
  bad "did-community 计数漂移未被捕获（rc=${dc_rc}）：$(printf '%s' "$dc_out" | tr '\n' ' ')"
fi

# 3b. CHANGELOG 措辞漂移：[Unreleased] Added 含已否决的 method(dripw)
mkdir -p "$WORKDIR/cl-bad"
cat > "$WORKDIR/cl-bad/CHANGELOG.md" <<'EOF'
# Changelog
## [Unreleased]
### Added
- 默认改用 method(dripw)
EOF
cl_out="$(CLAIMS_REPO_ROOT="$WORKDIR/cl-bad" bash "$CLAIMS_DIR/changelog.sh" 2>&1)" && cl_rc=0 || cl_rc=$?
if [ "$cl_rc" -ne 0 ] && printf '%s\n' "$cl_out" | grep -q 'dripw'; then
  ok "red-capable：CHANGELOG 已否决措辞被捕获"
else
  bad "CHANGELOG 措辞漂移未被捕获（rc=${cl_rc}）：$(printf '%s' "$cl_out" | tr '\n' ' ')"
fi

# 3c. 绿 fixture：干净的 [Unreleased] Added 不得误红
mkdir -p "$WORKDIR/cl-ok"
cat > "$WORKDIR/cl-ok/CHANGELOG.md" <<'EOF'
# Changelog
## [Unreleased]
### Added
- 干净措辞
EOF
if CLAIMS_REPO_ROOT="$WORKDIR/cl-ok" bash "$CLAIMS_DIR/changelog.sh" >/dev/null 2>&1; then
  ok "green fixture：CHANGELOG 干净时锁为绿"
else
  bad "green fixture：CHANGELOG 干净时锁误红"
fi

# 3d. 绿 fixture：did-community 计数一致且索引登记齐全时锁为绿
mkdir -p "$WORKDIR/dc-ok/stata-did-community/references"
cat > "$WORKDIR/dc-ok/stata-did-community/SKILL.md" <<'EOF'
---
description: 社区包（10 个方法）
---
## 详细方法参考
| `did_imputation` | [csdid-jwdid-imputation.md](references/csdid-jwdid-imputation.md) |
| trop | [trop.md](references/trop.md) |
| 功效 | [power-analysis-template.do](references/power-analysis-template.do) |
## 正文
共 10 个社区包可用。
## 关键陷阱速查
- TROP 的推断依赖 placebo
EOF
printf 'SA-IW\nmethod(twostage)\n' >"$WORKDIR/dc-ok/stata-did-community/references/csdid-jwdid-imputation.md"
printf '### did_imputation\n详解\n' >>"$WORKDIR/dc-ok/stata-did-community/references/csdid-jwdid-imputation.md"
printf 'Roth 2022\n' >"$WORKDIR/dc-ok/stata-did-community/references/workflow-8step.md"
printf '# trop\n' >"$WORKDIR/dc-ok/stata-did-community/references/trop.md"
printf '# sdid\n' >"$WORKDIR/dc-ok/stata-did-community/references/sdid.md"
printf '// 无浮点插值变量名\n' >"$WORKDIR/dc-ok/stata-did-community/references/power-analysis-template.do"
if CLAIMS_REPO_ROOT="$WORKDIR/dc-ok" bash "$CLAIMS_DIR/did-community.sh" >/dev/null 2>&1; then
  ok "green fixture：did-community 全部锁为绿"
else
  bad "green fixture：did-community 锁误红（bash verify/claims/did-community.sh + CLAIMS_REPO_ROOT 可复现）"
fi

# ---- 4. 聚合器契约：发现式聚合 + 事故锁不回流 ----
if grep -q 'claims_dir=.*VERIFY_DIR/claims' "$VERIFY_DIR/check-claims.sh" \
   && grep -q 'for cf in "\$claims_dir"/\*\.sh' "$VERIFY_DIR/check-claims.sh"; then
  ok "check-claims.sh 发现式聚合 claims/*.sh"
else
  bad "check-claims.sh 未发现式聚合 claims/*.sh（新增锁需改聚合器 = 违背 C1）"
fi

reflow=""
for phrase in 'method(dripw)' 'Targeted Robust OP' '3cae231' 'SA-IW' 'did_imputation' 'rejected_`att'; do
  if grep -qF "$phrase" "$VERIFY_DIR/check-claims.sh"; then
    reflow="${reflow} ${phrase};"
  fi
done
if [ -n "$reflow" ]; then
  bad "已下沉的事故锁短语回流 check-claims.sh：${reflow}"
else
  ok "事故锁短语未回流 check-claims.sh（下沉未被撤销）"
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "结果：全部通过"
  exit 0
fi
echo "结果：${fail} 失败"
exit 1
