#!/usr/bin/env bash
# 生成更新清单 latest.json（配合本地 http.server 演示 / 生产发布）。
#
# 用法：bash scripts/generate-latest-json.sh <apk路径> [changelog] [--mandatory] [--out <path>] [--asset-url <https-url>]
# 例：  bash scripts/generate-latest-json.sh build/app/outputs/flutter-apk/app-release.apk "本次更新：…"
#       bash scripts/generate-latest-json.sh build/app/outputs/flutter-apk/app-release.apk "发布 1.2.3" \
#             --asset-url https://<mirror>/v1.2.3/app-release.apk --out build/update-gitee/latest.json
#
# --asset-url 缺省时 url 写本地演示地址 http://127.0.0.1:8090/<apk文件名>；
# 提供时原样写入该 HTTPS 直链（生产发布必须提供，指向与 latest.json 同一镜像的 APK）。
# --out 缺省为 build/latest.json，输出前自动创建父目录。
# versionCode 读自 lib/core/version.dart（单一来源），sha256 用 python 计算。
set -euo pipefail
cd "$(dirname "$0")/.."

usage="用法: bash scripts/generate-latest-json.sh <apk路径> [changelog] [--mandatory] [--out <path>] [--asset-url <https-url>]"
APK="${1:?$usage}"
shift || true
CHANGELOG=""
MANDATORY=false
OUT="build/latest.json"
ASSET_URL=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mandatory) MANDATORY=true ;;
    --out)
      [ "$#" -ge 2 ] || { echo "$usage" >&2; exit 1; }
      OUT="$2"; shift ;;
    --out=*) OUT="${1#--out=}" ;;
    --asset-url)
      [ "$#" -ge 2 ] || { echo "$usage" >&2; exit 1; }
      ASSET_URL="$2"; shift ;;
    --asset-url=*) ASSET_URL="${1#--asset-url=}" ;;
    --*) echo "未知参数: $1" >&2; echo "$usage" >&2; exit 1 ;;
    *) CHANGELOG="$1" ;;
  esac
  shift
done
[ -f "$APK" ] || { echo "APK 不存在: $APK" >&2; exit 1; }

# 从 lib/core/version.dart 读版本（单一来源）。优先 grep -oP；执行机不支持时
# 用 python 正则兜底，两种方式得到完全相同的值。
if grep -oP "kAppVersionCode = \K[0-9]+" lib/core/version.dart >/dev/null 2>&1; then
  VNAME=$(grep -oP "kAppVersionName = '\K[^']+" lib/core/version.dart)
  VCODE=$(grep -oP "kAppVersionCode = \K[0-9]+" lib/core/version.dart)
else
  VNAME=$(python -c "import re;print(re.search(r\"kAppVersionName = '([^']+)'\", open('lib/core/version.dart',encoding='utf-8').read()).group(1))")
  VCODE=$(python -c "import re;print(re.search(r'kAppVersionCode = (\d+)', open('lib/core/version.dart',encoding='utf-8').read()).group(1))")
fi
SHA=$(python -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$APK")

mkdir -p "$(dirname "$OUT")"
python - "$VNAME" "$VCODE" "$APK" "$CHANGELOG" "$MANDATORY" "$SHA" "$ASSET_URL" "$OUT" <<'PY'
import io, json, os, sys
vname, vcode, apk, changelog, mandatory, sha, asset_url, out = sys.argv[1:9]
if asset_url:
    url = asset_url
else:
    url = "http://127.0.0.1:8090/%s" % os.path.basename(apk)
payload = {
    "versionCode": int(vcode),
    "versionName": vname,
    "url": url,
    "changelog": changelog,
    "mandatory": mandatory == "true",
    "releaseDate": __import__("datetime").date.today().isoformat(),
    "sha256": sha,
}
io.open(out, "w", encoding="utf-8").write(json.dumps(payload, ensure_ascii=False, indent=2))
print("已生成 %s" % out)
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY
