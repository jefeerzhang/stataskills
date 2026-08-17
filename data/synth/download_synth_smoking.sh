#!/usr/bin/env bash
# ============================================================
# 下载 + 字节级校验 synth_smoking.dta
#
# 来源  : https://github.com/scunning1975/mixtape
#         (Scott Cunningham, *Causal Inference: The Mixtape* 官方 repo)
# 目标  : data/synth/synth_smoking.dta
# 许可  : MIT（上游 LICENSE，见 data/synth/README.md）
#
# 行为：
#   1. 通过 GitHub API 拿 base64 内容（避免 raw.githubusercontent.com 的匿名 rate limit）
#   2. 解码后写到目标路径
#   3. 字节数校验（必须等于 EXPECTED_SIZE，否则拒绝覆盖并报错）
#   4. 用 `file` 命令确认是合法 Stata 数据文件
#
# 用法：
#   bash data/synth/download_synth_smoking.sh
#
# 当 EXPECTED_SIZE 与上游不符时（说明上游真的改了文件），先和团队确认
# 是否更新 README 的"字节数校验"列再放宽阈值；不要默默改 EXPECTED_SIZE。
# ============================================================
set -eu

EXPECTED_SIZE=47045
REPO="scunning1975/mixtape"
FILE="synth_smoking.dta"
TARGET="$(cd "$(dirname "$0")" && pwd)/$FILE"

echo "==> 下载 $REPO/$FILE 到 $TARGET ..."

# GitHub API：拿 base64 编码的内容
api_url="https://api.github.com/repos/${REPO}/contents/${FILE}"
tmp_json="$(mktemp)"
trap 'rm -f "$tmp_json"' EXIT

curl -fsSL --max-time 30 "$api_url" -o "$tmp_json"

# 解码并写到目标
python3 - "$tmp_json" "$TARGET" "$EXPECTED_SIZE" <<'PY'
import sys, json, base64, os

json_path, target, expected = sys.argv[1], sys.argv[2], int(sys.argv[3])

with open(json_path) as f:
    d = json.load(f)

if d.get("encoding") != "base64":
    sys.exit(f"ERROR: 上游 encoding={d.get('encoding')} 不是 base64，请检查 API 返回")

size = d.get("size", 0)
if size != expected:
    sys.exit(
        f"ERROR: 上游 size={size} 与 EXPECTED_SIZE={expected} 不符；"
        f"上游可能更新过文件。请先与团队确认是否更新 data/synth/README.md 的"
        f"\"字节数校验\"列，再修改 EXPECTED_SIZE 后重跑。"
    )

data = base64.b64decode(d["content"])
with open(target, "wb") as f:
    f.write(data)

# 落盘后再校验一次（防御 API 返回的 size 字段不准确）
actual = os.path.getsize(target)
if actual != expected:
    os.remove(target)
    sys.exit(f"ERROR: 写入后字节数={actual} 与 EXPECTED_SIZE={expected} 不符，已回滚")

print(f"OK: 写入 {target} ({actual} bytes)")
PY

# `file` 命令确认是合法 Stata 数据
file_out="$(file -b "$TARGET")"
case "$file_out" in
  "Stata "*)
    echo "OK: file 命令识别为 ${file_out}"
    ;;
  *)
    echo "ERROR: file 命令识别异常：${file_out}"
    exit 1
    ;;
esac

echo "==> 完成。"