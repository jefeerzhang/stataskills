#!/usr/bin/env bash
# ============================================================
# 回归测试：prompt corpus module（verify/lib/prompt_corpus.sh）
#
# #22 建立 seam；#29 C4 收敛为单一 canonical adapter（python）后，本测试守住：
#   - init 选定 python 且能解析合法 corpus
#   - malformed fixtures：字段类型 / 空 skill / 缺 actions / 重复 route_branch
#   - normalize 视图稳定且覆盖全部 prompt（回归快照面）
#   - python 不可用时 init 明确失败（不静默降级）
#   - 反模式：模块内不得再有 jq 分支
#
# 用法：bash verify/test-prompt-corpus.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$VERIFY_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/report.sh"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/prompt_corpus.sh"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/stataskills-prompt-corpus.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ---- 1. init 选定 canonical adapter 并解析合法 corpus ----
if ! prompt_corpus_init "$REPO_ROOT/test-prompts.json"; then
  bad "init 合法 corpus 失败（本机需 python3 或 python）"
  echo "结果：${fail} 失败"
  exit 1
fi
adapter="$(prompt_corpus_adapter)"
count="$(prompt_corpus_count)" || count=""
if [ "$adapter" = "python" ] && [ -n "$count" ] && [ "$count" -gt 0 ]; then
  ok "canonical adapter=$adapter 解析 count=$count"
else
  bad "init 结果异常：adapter=$adapter count=$count"
fi

# ---- 2. normalize 视图稳定且覆盖全部 prompt ----
norm1="$(prompt_corpus_normalize)" || norm1="__ERR__"
norm2="$(prompt_corpus_normalize)" || norm2="__ERR__"
n_ids="$(printf '%s\n' "$norm1" | grep -c '^{' || true)"
if [ "$norm1" = "$norm2" ] && [ "$norm1" != "__ERR__" ] && [ "$n_ids" = "$count" ]; then
  ok "normalize 稳定（两次一致）且覆盖 ${n_ids}/${count} 条 prompt"
else
  bad "normalize 不稳定或覆盖不全：stable=$([ "$norm1" = "$norm2" ] && echo 1 || echo 0) ids=$n_ids count=$count"
fi

# ---- 3. malformed fixtures ----
write_bad() {
  local name="$1"
  shift
  printf '%s\n' "$@" >"$WORKDIR/$name.json"
}

# 3a skill 非 string
write_bad bad_skill_type \
  '{"prompts":[{"id":"x","skill":123,"expected_outputs":["a"]}]}'
prompt_corpus_init "$WORKDIR/bad_skill_type.json"
if ! prompt_corpus_skill_values >/dev/null 2>&1; then
  ok "malformed：skill 非 string → 非零退出"
else
  bad "malformed：skill 非 string 应失败"
fi

# 3b 空 skill 片段
write_bad bad_empty_skill \
  '{"prompts":[{"id":"x","skill":"stata-basics + ","expected_outputs":["a"]}]}'
prompt_corpus_init "$WORKDIR/bad_empty_skill.json"
if ! prompt_corpus_skill_values >/dev/null 2>&1; then
  ok "malformed：空 skill 片段 → 非零退出"
else
  bad "malformed：空 skill 片段 应失败"
fi

# 3c 缺 expected_actions（有 route_branch）
write_bad bad_missing_actions \
  '{"prompts":[{"id":"r1","skill":"stata-identification","route_branch":"router-entry"}]}'
prompt_corpus_init "$WORKDIR/bad_missing_actions.json"
errs="$(prompt_corpus_route_action_errors 2>/dev/null | tr -d '\r')"
case "$errs" in
  *r1*) ok "malformed：缺 expected_actions 被检出" ;;
  *) bad "malformed：缺 expected_actions 未检出：[$errs]" ;;
esac

# 3d 重复 route_branch
write_bad bad_dup_branch \
  '{"prompts":[
    {"id":"a","skill":"stata-identification","route_branch":"router-entry","expected_actions":["x"]},
    {"id":"b","skill":"stata-identification","route_branch":"router-entry","expected_actions":["y"]}
  ]}'
prompt_corpus_init "$WORKDIR/bad_dup_branch.json"
dups="$(prompt_corpus_route_branch_values 2>/dev/null | tr -d '\r' | sort | uniq -d)"
if [ "$dups" = "router-entry" ]; then
  ok "malformed：重复 route_branch 可被聚合检出"
else
  bad "malformed：重复 route_branch 未检出：[$dups]"
fi

# 3e 锁定分支出现两次 → 单条查询必须失败（不能静默取第一条）
if ! prompt_corpus_branch_action_count router-entry >/dev/null 2>&1; then
  ok "malformed：锁定 route_branch 重复 → branch_action_count 非零退出"
else
  bad "malformed：锁定 route_branch 重复时 branch_action_count 应失败"
fi

# ---- 4. python 不可用时 init 明确失败（不静默降级）----
mkdir -p "$WORKDIR/emptybin"
if missing_out="$(env PATH="$WORKDIR/emptybin" "${BASH:-bash}" -c 'set -u; . "$1"; prompt_corpus_init "$2"' _ "$VERIFY_DIR/lib/prompt_corpus.sh" "$REPO_ROOT/test-prompts.json" 2>&1)"; then
  bad "python 不可用时 init 竟然成功：[$missing_out]"
else
  case "$missing_out" in
    *python*) ok "python 不可用时 init 明确失败并指出需要 python" ;;
    *) bad "python 不可用时 init 失败但信息不清：[$missing_out]" ;;
  esac
fi

# ---- 5. 反模式：模块内不得再有 jq 分支（注释除外）----
if grep -vE '^[[:space:]]*#' "$VERIFY_DIR/lib/prompt_corpus.sh" | grep -qE '\bjq\b'; then
  bad "prompt_corpus.sh 仍含 jq 分支（#29 C4 要求单一 canonical adapter）"
else
  ok "prompt_corpus.sh 无 jq 分支（单一 canonical adapter）"
fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "结果：全部通过"
  exit 0
fi
echo "结果：${fail} 失败"
exit 1
