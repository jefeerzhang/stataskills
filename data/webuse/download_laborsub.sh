#!/usr/bin/env bash
# ============================================================
# 下载 + 字节级校验 laborsub.dta（StataCorp webuse 库）
#
# 来源  : https://www.stata-press.com/data/r16/laborsub.dta
#         （StataCorp 官方 webuse 库；通过 stata-press.com 而非
#          stata.com 直连，是稳定的可下载路径）
# 目标  : data/webuse/laborsub.dta
# 许可  : 随 Stata EULA，不二次分发
#
# 行为：
#   1. curl 下载到目标路径（--fail 让 4xx/5xx 报错而非静默写入）
#   2. 字节数校验（必须等于 EXPECTED_SIZE，否则拒绝覆盖并报错）
#   3. 用 `file` 命令确认是合法 Stata 数据文件
#
# 用法：
#   bash data/webuse/download_laborsub.sh
#
# 当 EXPECTED_SIZE 与上游不符时（说明 StataCorp 真的改了文件），
# 先与团队确认是否更新 README 的"字节校验值"列再放宽阈值；
# 不要默默改 EXPECTED_SIZE。
# ============================================================
set -eu

EXPECTED_SIZE=3501
SOURCE='https://www.stata-press.com/data/r16/laborsub.dta'
TARGET="$(cd "$(dirname "$0")" && pwd)/laborsub.dta"

echo "==> 下载 $SOURCE 到 $TARGET ..."

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if ! curl --fail -fsSL --max-time 30 "$SOURCE" -o "$tmp"; then
  echo "ERROR: curl 下载失败（网络问题或 URL 已失效）。请检查网络或更新 SOURCE。" >&2
  exit 1
fi

actual=$(wc -c < "$tmp")
if [ "$actual" -ne "$EXPECTED_SIZE" ]; then
  echo "ERROR: 下载字节数=$actual 与 EXPECTED_SIZE=$EXPECTED_SIZE 不符；" >&2
  echo "       StataCorp 可能更新过文件。请先与团队确认是否更新 data/webuse/README.md" >&2
  echo "       的\"字节校验值\"列，再修改 EXPECTED_SIZE 后重跑。" >&2
  exit 1
fi

mv "$tmp" "$TARGET"
trap - EXIT

# `file` 命令确认是合法 Stata 数据
file_out="$(file -b "$TARGET")"
case "$file_out" in
  "Stata "*)
    echo "OK: 写入 $TARGET ($actual bytes)；file 命令识别为 ${file_out}"
    ;;
  *)
    echo "ERROR: file 命令识别异常：${file_out}" >&2
    exit 1
    ;;
esac

echo "==> 完成。"