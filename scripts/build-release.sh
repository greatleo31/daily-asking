#!/usr/bin/env bash
# 发布构建：把更新源**固化注入**，避免手工拼参数漏 `--dart-define` 导致
# 构建出来的包 `isConfigured == false` —— 那样更新功能会永久静默失效，
# 客户端连一次网络请求都不会发，且没有任何用户可见的报错。
#
# 用法:
#   sh scripts/build-release.sh [flutter build 的其它参数…]
#
# 环境变量:
#   UPDATE_BASE_URLS  覆盖默认更新源列表（逗号分隔；首个为主镜像，其余为回退）
#   FLUTTER_BIN       指定 flutter 可执行文件（默认从 PATH 找，找不到时试 /c/src/flutter）
#
# 默认更新源（与 docs/02-版本与更新机制.md §3.1 一致）:
#   1. Gitee 主镜像：稳定目录 …/raw/main/update
#   2. GitHub 回退：releases/latest/download 稳定别名（Release 里必须带 latest.json 附件）
set -euo pipefail
cd "$(dirname "$0")/.."

DEFAULT_BASE_URLS="https://gitee.com/yankehu/daily_asking/raw/main/update,https://github.com/greatleo31/daily-asking/releases/latest/download"
# 未设置 → 用默认源；显式设为空 → 视为误操作（要求显式给出源，拒绝静默产出一个
# 更新功能失效的包）。本地演示可传 UPDATE_BASE_URLS=http://127.0.0.1:8090。
if [ -z "${UPDATE_BASE_URLS+x}" ]; then
  UPDATE_BASE_URLS="$DEFAULT_BASE_URLS"
fi
if [ -z "$UPDATE_BASE_URLS" ]; then
  echo "UPDATE_BASE_URLS 被显式设为空：拒绝构建（更新功能会静默失效）。" >&2
  echo "  如确需本地演示源：UPDATE_BASE_URLS=http://127.0.0.1:8090 sh scripts/build-release.sh" >&2
  exit 1
fi

FLUTTER_BIN="${FLUTTER_BIN:-}"
if [ -z "$FLUTTER_BIN" ]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="flutter"
  elif [ -x "/c/src/flutter/bin/flutter.bat" ]; then
    FLUTTER_BIN="/c/src/flutter/bin/flutter.bat"
  else
    echo "未找到 flutter，可用 FLUTTER_BIN=... 指定" >&2
    exit 1
  fi
fi

echo "更新源: $UPDATE_BASE_URLS"
"$FLUTTER_BIN" build apk --release \
  --dart-define=UPDATE_BASE_URLS="$UPDATE_BASE_URLS" \
  "$@"

APK="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK" ]; then
  echo "产物: $APK"
  for cmd in python.exe python py python3; do
    if "$cmd" -c "import sys; sys.exit(0)" >/dev/null 2>&1; then
      "$cmd" scripts/apk_version.py "$APK"
      break
    fi
  done
  echo "下一步: 按 docs/02-版本与更新机制.md §6.4 生成并上传各镜像的 latest.json"
else
  echo "警告: 未找到 $APK" >&2
fi
