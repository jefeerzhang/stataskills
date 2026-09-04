#!/usr/bin/env bash
# ============================================================
# 回归测试：prompt corpus adapters（verify/lib/prompt_corpus.sh）
#
# Issue #22：
#   - 双 adapter 对合法 corpus 归一化输出一致
#   - malformed fixtures：字段类型 / 空 skill / 缺 actions / 重复 route_branch
#   - 单 adapter 可用时仍能 init
#
# 用法：bash verify/test-prompt-corpus.sh
# ============================================================
set -u

VERIFY_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$VERIFY_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$VERIFY_DIR/lib/prompt_corpus.sh"

fail=0
pass() { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; fail=$((fail + 1)); }

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/stataskills-prompt-corpus.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

HAS_JQ=0
HAS_PY=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1
PY_BIN="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
[ -n "$PY_BIN" ] && HAS_PY=1

if [ "$HAS_JQ" -eq 0 ] && [ "$HAS_PY" -eq 0 ]; then
  bad "本机既无 jq 也无 python，无法测 adapters"
  echo "结果：${fail} 失败"
  exit 1
fi

# ---- 1. 默认 init 只选一次 ----
unset PROMPT_CORPUS_FORCE_ADAPTER
prompt_corpus_init "$REPO_ROOT/test-prompts.json" || { bad "init 合法 corpus 失败"; echo "结果：${fail} 失败"; exit 1; }
adapter1="$(prompt_corpus_adapter)"
count1="$(prompt_corpus_count)" || count1=""
if [ -n "$count1" ] && [ "$count1" -gt 0 ]; then
  pass "默认 adapter=$adapter1 解析 count=$count1"
else
  bad "默认 adapter 解析失败"
fi

# ---- 2. 双 adapter 对拍（两者都有时）----
if [ "$HAS_JQ" -eq 1 ] && [ "$HAS_PY" -eq 1 ]; then
  PROMPT_CORPUS_FORCE_ADAPTER=jq
  prompt_corpus_init "$REPO_ROOT/test-prompts.json" || bad "force jq init 失败"
  jq_norm="$(prompt_corpus_normalize 2>/dev/null | tr -d '\r')" || jq_norm="__ERR__"
  jq_rc=0
  prompt_corpus_count >/dev/null 2>&1 || jq_rc=$?

  PROMPT_CORPUS_FORCE_ADAPTER=python
  prompt_corpus_init "$REPO_ROOT/test-prompts.json" || bad "force python init 失败"
  py_norm="$(prompt_corpus_normalize 2>/dev/null | tr -d '\r')" || py_norm="__ERR__"
  py_rc=0
  prompt_corpus_count >/dev/null 2>&1 || py_rc=$?

  if [ "$jq_rc" -eq 0 ] && [ "$py_rc" -eq 0 ] && [ "$jq_norm" = "$py_norm" ] && [ "$jq_norm" != "__ERR__" ]; then
    pass "jq/python normalize 输出一致且 exit 0"
  else
    bad "jq/python 对拍失败：jq_rc=$jq_rc py_rc=$py_rc equal=$([ "$jq_norm" = "$py_norm" ] && echo 1 || echo 0)"
  fi
  unset PROMPT_CORPUS_FORCE_ADAPTER
else
  pass "跳过双 adapter 对拍（仅有其一：jq=$HAS_JQ py=$HAS_PY）"
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
PROMPT_CORPUS_FORCE_ADAPTER="${adapter1}"
prompt_corpus_init "$WORKDIR/bad_skill_type.json"
if ! prompt_corpus_skill_values >/dev/null 2>&1; then
  pass "malformed：skill 非 string → 非零退出"
else
  bad "malformed：skill 非 string 应失败"
fi

# 3b 空 skill 片段
write_bad bad_empty_skill \
  '{"prompts":[{"id":"x","skill":"stata-basics + ","expected_outputs":["a"]}]}'
prompt_corpus_init "$WORKDIR/bad_empty_skill.json"
if ! prompt_corpus_skill_values >/dev/null 2>&1; then
  pass "malformed：空 skill 片段 → 非零退出"
else
  bad "malformed：空 skill 片段 应失败"
fi

# 3c 缺 expected_actions（有 route_branch）
write_bad bad_missing_actions \
  '{"prompts":[{"id":"r1","skill":"stata-identification","route_branch":"router-entry"}]}'
prompt_corpus_init "$WORKDIR/bad_missing_actions.json"
errs="$(prompt_corpus_route_action_errors 2>/dev/null | tr -d '\r')"
case "$errs" in
  *r1*) pass "malformed：缺 expected_actions 被检出" ;;
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
  pass "malformed：重复 route_branch 可被聚合检出"
else
  bad "malformed：重复 route_branch 未检出：[$dups]"
fi

# ---- 4. 强制仅有的 adapter 仍可用 ----
if [ "$HAS_JQ" -eq 1 ]; then
  PROMPT_CORPUS_FORCE_ADAPTER=jq
  prompt_corpus_init "$REPO_ROOT/test-prompts.json" && prompt_corpus_count >/dev/null \
    && pass "仅 jq 路径可用" || bad "仅 jq 路径失败"
fi
if [ "$HAS_PY" -eq 1 ]; then
  PROMPT_CORPUS_FORCE_ADAPTER=python
  prompt_corpus_init "$REPO_ROOT/test-prompts.json" && prompt_corpus_count >/dev/null \
    && pass "仅 python 路径可用" || bad "仅 python 路径失败"
fi
unset PROMPT_CORPUS_FORCE_ADAPTER

echo ""
if [ "$fail" -eq 0 ]; then
  echo "结果：全部通过"
  exit 0
fi
echo "结果：${fail} 失败"
exit 1
