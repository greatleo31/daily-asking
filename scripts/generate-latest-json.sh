#!/usr/bin/env bash
# 生成更新清单 latest.json（配合本地 http.server 演示 / 生产发布）。
#
# 用法：bash scripts/generate-latest-json.sh <apk路径> [changelog] [--mandatory]
# 例：  bash scripts/generate-latest-json.sh build/app/outputs/flutter-apk/app-release.apk "本次更新：…"
#
# 输出到 build/latest.json。versionCode 读自 lib/core/version.dart（单一来源），
# sha256 用 python 计算（避免 Windows 无 sha256sum 的问题）。
set -euo pipefail
cd "$(dirname "$0")/.."

APK="${1:?用法: bash scripts/generate-latest-json.sh <apk路径> [changelog] [--mandatory]}"
CHANGELOG="${2:-}"
MANDATORY=false
for a in "$@"; do
  [ "$a" = "--mandatory" ] && MANDATORY=true
done
[ -f "$APK" ] || { echo "APK 不存在: $APK" >&2; exit 1; }

# 从 lib/core/version.dart 读版本（不依赖 python 解析 dart，直接正则）
VNAME=$(grep -oP "kAppVersionName = '\K[^']+" lib/core/version.dart)
VCODE=$(grep -oP "kAppVersionCode = \K[0-9]+" lib/core/version.dart)
SHA=$(python -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$APK")

mkdir -p build
python - "$VNAME" "$VCODE" "$APK" "$CHANGELOG" "$MANDATORY" "$SHA" <<'PY'
import io, json, os, sys
vname, vcode, apk, changelog, mandatory, sha = sys.argv[1:7]
payload = {
    "versionCode": int(vcode),
    "versionName": vname,
    "url": "http://127.0.0.1:8090/%s" % os.path.basename(apk),
    "changelog": changelog,
    "mandatory": mandatory == "true",
    "releaseDate": __import__("datetime").date.today().isoformat(),
    "sha256": sha,
}
out = "build/latest.json"
io.open(out, "w", encoding="utf-8").write(json.dumps(payload, ensure_ascii=False, indent=2))
print("已生成 %s" % out)
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY