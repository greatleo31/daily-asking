#!/usr/bin/env bash
# 版本号提升脚本（git-bash 可用）。
#
# 用法：bash scripts/bump-version.sh <major.minor.patch>
# 例：  bash scripts/bump-version.sh 1.2.0
#
# 同时更新两处（必须保持一致，否则 versionCode 与 versionName 脱节）：
#   1. pubspec.yaml 的 `version:` 行
#   2. lib/core/version.dart 的 kAppVersionName / kAppVersionCode
# versionCode 映射：major*10000 + minor*100 + patch
set -euo pipefail
cd "$(dirname "$0")/.."

NEW="$1"
if ! [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "用法: bash scripts/bump-version.sh <major.minor.patch>" >&2
  exit 1
fi
IFS='.' read -r MAJOR MINOR PATCH <<< "$NEW"
VC=$((MAJOR * 10000 + MINOR * 100 + PATCH))

# pubspec.yaml
if [[ "$(uname -s)" == *MINGW* || "$(uname -s)" == *MSYS* ]]; then
  # CRLF 安全：先把行尾统一为 LF，改完再还原
  python - "$NEW" "$VC" <<'PY'
import io, sys
p = 'pubspec.yaml'
s = io.open(p, encoding='utf-8').read()
crlf = '\r\n' in s
s = s.replace('\r\n', '\n')
import re
s = re.sub(r'^version: .+$', 'version: %s+%d' % (sys.argv[1], int(sys.argv[2])), s, count=1, flags=re.M)
if crlf:
    s = s.replace('\n', '\r\n')
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('pubspec -> version: %s+%d' % (sys.argv[1], int(sys.argv[2])))
PY
  python - "$NEW" "$VC" <<'PY'
import io, sys
p = 'lib/core/version.dart'
s = io.open(p, encoding='utf-8').read()
crlf = '\r\n' in s
s = s.replace('\r\n', '\n')
import re
s = re.sub(r"kAppVersionName = '[^']*'", "kAppVersionName = '%s'" % sys.argv[1], s, count=1)
s = re.sub(r"kAppVersionCode = \d+", "kAppVersionCode = %d" % int(sys.argv[2]), s, count=1)
if crlf:
    s = s.replace('\n', '\r\n')
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('lib/core/version.dart -> v%s (%d)' % (sys.argv[1], int(sys.argv[2])))
PY
else
  sed -i "s/^version: .*/version: $NEW+$VC/" pubspec.yaml
  sed -i "s/kAppVersionName = '[^']*'/kAppVersionName = '$NEW'/" lib/core/version.dart
  sed -i "s/kAppVersionCode = [0-9]*/kAppVersionCode = $VC/" lib/core/version.dart
fi

echo "已提升到 v$NEW (versionCode=$VC)。请提交并走发布流程。"