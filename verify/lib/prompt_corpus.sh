#!/usr/bin/env bash
# ============================================================
# Prompt corpus module（#22 / #29 C4）
#
# 单一 canonical adapter：Python。仓库本就硬依赖 python3/python
# （check-claims.sh 的 test-prompts.json 校验同样要求它），而 jq 从来不是
# 必需项。历史上这里是 jq/Python 双实现 + 对拍测试——两者语义必须逐字等价、
# 等价性只靠对拍维持，属于「同一 adapter 的两份实现」而不是真 seam；
# #29 C4 收敛为一份（locality：语义只写一遍），不再有 jq 分支与
# PROMPT_CORPUS_FORCE_ADAPTER。
#
# 公共 API：
#   prompt_corpus_init <json-path>
#   prompt_corpus_adapter            # 打印 python
#   prompt_corpus_count
#   prompt_corpus_skill_values       # 规范化 skill 片段（按 + 分割、trim）
#   prompt_corpus_route_branch_values
#   prompt_corpus_route_action_errors
#   prompt_corpus_branch_action_count <branch>
#   prompt_corpus_branch_action <branch> <index>
#   prompt_corpus_field <index> <field> [join-sep]
#   prompt_corpus_normalize          # 稳定 NDJSON 视图（回归对拍用）
#
# 诊断：失败时非零退出 + stderr 信息。
# ============================================================

PROMPT_CORPUS_JSON=""
PROMPT_CORPUS_ADAPTER=""
PROMPT_CORPUS_PYTHON=""

prompt_corpus_init() {
  local path="${1:-}"
  if [ -z "$path" ]; then
    echo "ERROR: prompt_corpus_init 需要 json 路径" >&2
    return 1
  fi
  if [ ! -f "$path" ]; then
    echo "ERROR: 找不到 prompt corpus：$path" >&2
    return 1
  fi
  PROMPT_CORPUS_JSON="$path"
  PROMPT_CORPUS_PYTHON="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
  if [ -z "$PROMPT_CORPUS_PYTHON" ]; then
    echo "ERROR: 解析 prompt corpus 需要 python3 或 python" >&2
    return 1
  fi
  PROMPT_CORPUS_ADAPTER="python"
}

prompt_corpus_adapter() {
  printf '%s\n' "$PROMPT_CORPUS_ADAPTER"
}

prompt_corpus_count() {
  "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); p=d.get("prompts"); assert isinstance(p,list), "prompts must be an array"; print(len(p))' "$PROMPT_CORPUS_JSON"
}

prompt_corpus_skill_values() {
  "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); values=[]
for p in d["prompts"]:
 s=p.get("skill"); assert isinstance(s,str), "skill must be a string"
 for raw in s.split("+"):
  part=raw.strip(); assert part, "skill entry must not be empty"; values.append(part)
print("\n".join(values))' "$PROMPT_CORPUS_JSON"
}

prompt_corpus_route_branch_values() {
  "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); values=[]
for p in d["prompts"]:
 if "route_branch" in p:
  b=p["route_branch"]; assert isinstance(b,str) and b, "route_branch must be a non-empty string"; values.append(b)
print("\n".join(values))' "$PROMPT_CORPUS_JSON"
}

prompt_corpus_route_action_errors() {
  "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); bad=[]
for p in d["prompts"]:
 if "route_branch" not in p: continue
 a=p.get("expected_actions")
 if not isinstance(a,list) or not a or any(not isinstance(x,str) or not x.strip() for x in a): bad.append(p.get("id","<missing-id>"))
print("\n".join(bad))' "$PROMPT_CORPUS_JSON"
}

prompt_corpus_branch_action_count() {
  local branch="$1"
  "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); matches=[p for p in d["prompts"] if p.get("route_branch")==sys.argv[2]]; assert len(matches)==1, "locked route_branch must occur exactly once"; a=matches[0].get("expected_actions"); assert isinstance(a,list), "expected_actions must be an array"; print(len(a))' "$PROMPT_CORPUS_JSON" "$branch"
}

prompt_corpus_branch_action() {
  local branch="$1" index="$2"
  "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); matches=[p for p in d["prompts"] if p.get("route_branch")==sys.argv[2]]; assert len(matches)==1, "locked route_branch must occur exactly once"; a=matches[0].get("expected_actions"); assert isinstance(a,list), "expected_actions must be an array"; i=int(sys.argv[3]); assert 0<=i<len(a), "expected_actions index out of range"; assert isinstance(a[i],str), "expected action must be a string"; print(a[i])' "$PROMPT_CORPUS_JSON" "$branch" "$index"
}

prompt_corpus_field() {
  local index="$1" field="$2" separator="${3:-}"
  "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; v=json.load(open(sys.argv[1], encoding="utf-8"))["prompts"][int(sys.argv[2])][sys.argv[3]]; print(sys.argv[4].join(v) if isinstance(v,list) else v)' "$PROMPT_CORPUS_JSON" "$index" "$field" "$separator"
}

# 稳定归一化视图：按 id 排序的 NDJSON（skill 已拆成数组；缺省字段显式 null）。
# 原用途是 jq/python 双实现对拍；#29 C4 后作为 canonical 视图的回归快照面。
prompt_corpus_normalize() {
  "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys
d=json.load(open(sys.argv[1], encoding="utf-8"))
rows=[]
for p in d.get("prompts", []):
 skill=p.get("skill")
 if isinstance(skill,str):
  parts=[x.strip() for x in skill.split("+") if x.strip()]
 else:
  parts=None
 rows.append({"id": p.get("id"), "skill": parts, "route_branch": p.get("route_branch"), "expected_actions": p.get("expected_actions")})
rows.sort(key=lambda r: (r["id"] is None, str(r["id"] or "")))
for r in rows:
 print(json.dumps(r, ensure_ascii=False, sort_keys=True, separators=(",",":")))' "$PROMPT_CORPUS_JSON"
}
