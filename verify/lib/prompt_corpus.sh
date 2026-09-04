#!/usr/bin/env bash
# ============================================================
# Prompt corpus module（#22 / parent #18）
#
# 一次选定 jq 或 Python adapter；对外只暴露规范化查询接口。
# 三种运行模式（docs / prompts / llm）不得再分支 adapter。
#
# 公共 API：
#   prompt_corpus_init <json-path>   # 选 adapter（可被 PROMPT_CORPUS_FORCE_ADAPTER 覆盖）
#   prompt_corpus_adapter            # 打印 jq|python
#   prompt_corpus_count
#   prompt_corpus_skill_values       # 规范化 skill 片段（按 + 分割、trim）
#   prompt_corpus_route_branch_values
#   prompt_corpus_route_action_errors
#   prompt_corpus_branch_action_count <branch>
#   prompt_corpus_branch_action <branch> <index>
#   prompt_corpus_field <index> <field> [join-sep]
#   prompt_corpus_normalize          # 稳定 NDJSON，供双 adapter 对拍
#
# 诊断：失败时非零退出 + stderr 信息（与既有 jq/python assert 语义一致）。
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

  if [ -n "${PROMPT_CORPUS_FORCE_ADAPTER:-}" ]; then
    case "$PROMPT_CORPUS_FORCE_ADAPTER" in
      jq)
        command -v jq >/dev/null 2>&1 || { echo "ERROR: FORCE_ADAPTER=jq 但 jq 不可用" >&2; return 1; }
        PROMPT_CORPUS_ADAPTER="jq"
        ;;
      python)
        [ -n "$PROMPT_CORPUS_PYTHON" ] || { echo "ERROR: FORCE_ADAPTER=python 但 python 不可用" >&2; return 1; }
        PROMPT_CORPUS_ADAPTER="python"
        ;;
      *)
        echo "ERROR: 未知 PROMPT_CORPUS_FORCE_ADAPTER=$PROMPT_CORPUS_FORCE_ADAPTER" >&2
        return 1
        ;;
    esac
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    PROMPT_CORPUS_ADAPTER="jq"
  elif [ -n "$PROMPT_CORPUS_PYTHON" ]; then
    PROMPT_CORPUS_ADAPTER="python"
  else
    echo "ERROR: 解析 prompt corpus 需要 jq、python3 或 python" >&2
    return 1
  fi
}

prompt_corpus_adapter() {
  printf '%s\n' "$PROMPT_CORPUS_ADAPTER"
}

prompt_corpus_count() {
  case "$PROMPT_CORPUS_ADAPTER" in
    jq)
      jq '.prompts | if type == "array" then length else error("prompts must be an array") end' "$PROMPT_CORPUS_JSON"
      ;;
    python)
      "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); p=d.get("prompts"); assert isinstance(p,list), "prompts must be an array"; print(len(p))' "$PROMPT_CORPUS_JSON"
      ;;
    *) echo "ERROR: prompt_corpus 未 init" >&2; return 1 ;;
  esac
}

prompt_corpus_skill_values() {
  case "$PROMPT_CORPUS_ADAPTER" in
    jq)
      jq -r '.prompts[] | .skill | if type != "string" then error("skill must be a string") else split("+")[] | sub("^\\s+"; "") | sub("\\s+$"; "") | if length > 0 then . else error("skill entry must not be empty") end end' "$PROMPT_CORPUS_JSON"
      ;;
    python)
      "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); values=[]
for p in d["prompts"]:
 s=p.get("skill"); assert isinstance(s,str), "skill must be a string"
 for raw in s.split("+"):
  part=raw.strip(); assert part, "skill entry must not be empty"; values.append(part)
print("\n".join(values))' "$PROMPT_CORPUS_JSON"
      ;;
    *) echo "ERROR: prompt_corpus 未 init" >&2; return 1 ;;
  esac
}

prompt_corpus_route_branch_values() {
  case "$PROMPT_CORPUS_ADAPTER" in
    jq)
      jq -r '.prompts[] | select(has("route_branch")) | .route_branch | if type == "string" and length > 0 then . else error("route_branch must be a non-empty string") end' "$PROMPT_CORPUS_JSON"
      ;;
    python)
      "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); values=[]
for p in d["prompts"]:
 if "route_branch" in p:
  b=p["route_branch"]; assert isinstance(b,str) and b, "route_branch must be a non-empty string"; values.append(b)
print("\n".join(values))' "$PROMPT_CORPUS_JSON"
      ;;
    *) echo "ERROR: prompt_corpus 未 init" >&2; return 1 ;;
  esac
}

prompt_corpus_route_action_errors() {
  case "$PROMPT_CORPUS_ADAPTER" in
    jq)
      jq -r '.prompts[] | select(has("route_branch")) | select(if (has("expected_actions") | not) then true elif (.expected_actions | type) != "array" then true elif (.expected_actions | length) == 0 then true else any(.expected_actions[]; if type == "string" then (test("\\S") | not) else true end) end) | (.id // "<missing-id>")' "$PROMPT_CORPUS_JSON"
      ;;
    python)
      "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); bad=[]
for p in d["prompts"]:
 if "route_branch" not in p: continue
 a=p.get("expected_actions")
 if not isinstance(a,list) or not a or any(not isinstance(x,str) or not x.strip() for x in a): bad.append(p.get("id","<missing-id>"))
print("\n".join(bad))' "$PROMPT_CORPUS_JSON"
      ;;
    *) echo "ERROR: prompt_corpus 未 init" >&2; return 1 ;;
  esac
}

prompt_corpus_branch_action_count() {
  local branch="$1"
  case "$PROMPT_CORPUS_ADAPTER" in
    jq)
      jq -r --arg branch "$branch" '[.prompts[] | select(.route_branch? == $branch)] | if length != 1 then error("locked route_branch must occur exactly once") elif (.[0].expected_actions | type) != "array" then error("expected_actions must be an array") else (.[0].expected_actions | length) end' "$PROMPT_CORPUS_JSON"
      ;;
    python)
      "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); matches=[p for p in d["prompts"] if p.get("route_branch")==sys.argv[2]]; assert len(matches)==1, "locked route_branch must occur exactly once"; a=matches[0].get("expected_actions"); assert isinstance(a,list), "expected_actions must be an array"; print(len(a))' "$PROMPT_CORPUS_JSON" "$branch"
      ;;
    *) echo "ERROR: prompt_corpus 未 init" >&2; return 1 ;;
  esac
}

prompt_corpus_branch_action() {
  local branch="$1" index="$2"
  case "$PROMPT_CORPUS_ADAPTER" in
    jq)
      jq -r --arg branch "$branch" --argjson index "$index" '[.prompts[] | select(.route_branch? == $branch)] | if length != 1 then error("locked route_branch must occur exactly once") elif (.[0].expected_actions | type) != "array" then error("expected_actions must be an array") elif $index < 0 or $index >= (.[0].expected_actions | length) then error("expected_actions index out of range") elif (.[0].expected_actions[$index] | type) != "string" then error("expected action must be a string") else .[0].expected_actions[$index] end' "$PROMPT_CORPUS_JSON"
      ;;
    python)
      "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); matches=[p for p in d["prompts"] if p.get("route_branch")==sys.argv[2]]; assert len(matches)==1, "locked route_branch must occur exactly once"; a=matches[0].get("expected_actions"); assert isinstance(a,list), "expected_actions must be an array"; i=int(sys.argv[3]); assert 0<=i<len(a), "expected_actions index out of range"; assert isinstance(a[i],str), "expected action must be a string"; print(a[i])' "$PROMPT_CORPUS_JSON" "$branch" "$index"
      ;;
    *) echo "ERROR: prompt_corpus 未 init" >&2; return 1 ;;
  esac
}

prompt_corpus_field() {
  local index="$1" field="$2" separator="${3:-}"
  case "$PROMPT_CORPUS_ADAPTER" in
    jq)
      if [ -n "$separator" ]; then
        jq -r ".prompts[$index].$field | join(\"$separator\")" "$PROMPT_CORPUS_JSON"
      else
        jq -r ".prompts[$index].$field" "$PROMPT_CORPUS_JSON"
      fi
      ;;
    python)
      "$PROMPT_CORPUS_PYTHON" -X utf8 -c 'import json,sys; v=json.load(open(sys.argv[1], encoding="utf-8"))["prompts"][int(sys.argv[2])][sys.argv[3]]; print(sys.argv[4].join(v) if isinstance(v,list) else v)' "$PROMPT_CORPUS_JSON" "$index" "$field" "$separator"
      ;;
    *) echo "ERROR: prompt_corpus 未 init" >&2; return 1 ;;
  esac
}

# 稳定归一化视图：按 id 排序的 NDJSON（skill 已拆成数组；缺省字段显式 null）
prompt_corpus_normalize() {
  case "$PROMPT_CORPUS_ADAPTER" in
    jq)
      jq -c -S '[.prompts[] | {
        id: (.id // null),
        skill: (if (.skill|type)=="string" then (.skill|split("+")|map(gsub("^\\s+|\\s+$";""))|map(select(length>0))) else null end),
        route_branch: (.route_branch // null),
        expected_actions: (.expected_actions // null)
      }] | sort_by(.id) | .[]' "$PROMPT_CORPUS_JSON"
      ;;
    python)
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
      ;;
    *) echo "ERROR: prompt_corpus 未 init" >&2; return 1 ;;
  esac
}
