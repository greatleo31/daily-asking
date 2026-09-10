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
# versionCode / versionName 读自 **APK 自身**（scripts/apk_version.py），并与
# lib/core/version.dart 交叉校验：不一致直接报错，避免清单描述的不是真实发布的包。
# sha256 用 python 计算。
# --out 指向 update/latest.json 时另有护栏：versionCode 低于已发布值 → 报错；
# 相同但 sha256 变化 → 告警（详见 docs/02-版本与更新机制.md §6.2）。
set -euo pipefail
cd "$(dirname "$0")/.."

usage="用法: bash scripts/generate-latest-json.sh <apk路径> [changelog] [--mandatory] [--out <path>] [--asset-url <https-url>] [--allow-mismatch]"
APK="${1:?$usage}"
shift || true
CHANGELOG=""
MANDATORY=false
OUT="build/latest.json"
ASSET_URL=""
ALLOW_MISMATCH=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mandatory) MANDATORY=true ;;
    --allow-mismatch) ALLOW_MISMATCH=true ;;
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

# 寻找可用的 python 命令（兼容 Windows / Git-Bash / Linux，优先无 WSL shim 的真实二进制）
PYTHON_BIN=""
for cmd in python.exe python py python3; do
  if "$cmd" -c "import sys; sys.exit(0)" >/dev/null 2>&1; then
    PYTHON_BIN="$cmd"
    break
  fi
done
[ -n "$PYTHON_BIN" ] || { echo "未找到可用的 Python 环境" >&2; exit 1; }

# 版本号以 **APK 为准**：清单描述的是实际上传给用户的安装包，
# 而 lib/core/version.dart 描述的是源码状态，两者可能脱节（构建时用了
# --build-number/--build-name，或改了源码没重新出包）。
APK_VERSION=$("$PYTHON_BIN" scripts/apk_version.py "$APK") \
  || { echo "无法从 APK 读取 versionCode/versionName: $APK" >&2; exit 1; }
VCODE="${APK_VERSION%% *}"
VNAME="${APK_VERSION#* }"

# 源码单一来源（用于交叉校验）。优先 grep -oP；执行机不支持时用 python 正则兜底。
if grep -oP "kAppVersionCode = \K[0-9]+" lib/core/version.dart >/dev/null 2>&1; then
  SRC_VNAME=$(grep -oP "kAppVersionName = '\K[^']+" lib/core/version.dart)
  SRC_VCODE=$(grep -oP "kAppVersionCode = \K[0-9]+" lib/core/version.dart)
else
  SRC_VNAME=$("$PYTHON_BIN" -c "import re;print(re.search(r\"kAppVersionName = '([^']+)'\", open('lib/core/version.dart',encoding='utf-8').read()).group(1))")
  SRC_VCODE=$("$PYTHON_BIN" -c "import re;print(re.search(r'kAppVersionCode = (\d+)', open('lib/core/version.dart',encoding='utf-8').read()).group(1))")
fi

if [ "$VCODE" != "$SRC_VCODE" ] || [ "$VNAME" != "$SRC_VNAME" ]; then
  if [ "$ALLOW_MISMATCH" = "true" ]; then
    echo "警告: APK 实际为 $VNAME ($VCODE)，lib/core/version.dart 为 $SRC_VNAME ($SRC_VCODE)；已按 APK 生成清单。" >&2
  else
    echo "错误: APK 实际版本为 $VNAME ($VCODE)，但 lib/core/version.dart 写的是 $SRC_VNAME ($SRC_VCODE)。" >&2
    echo "      清单必须描述实际上传的 APK；若 APK 才是正确的，请先用 scripts/bump-version.sh 同步源码后重新出包。" >&2
    echo "      确认两者应并存时，可加 --allow-mismatch 显式放行。" >&2
    exit 1
  fi
fi
SHA=$("$PYTHON_BIN" -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$APK")

# 已发布清单的护栏：往 update/latest.json 写入比线上更低的 versionCode，会让所有
# 已发布的用户一律判定为「无更新」（versionCode 是唯一判定依据），直接拦截。
PUBLISHED_MANIFEST="update/latest.json"
case "$OUT" in
  "$PUBLISHED_MANIFEST"|"./$PUBLISHED_MANIFEST")
    if [ -f "$PUBLISHED_MANIFEST" ]; then
      if ! "$PYTHON_BIN" - "$PUBLISHED_MANIFEST" "$VCODE" "$SHA" <<'PY'
import json, sys
path, vcode, sha = sys.argv[1], int(sys.argv[2]), sys.argv[3]
pub = json.load(open(path, encoding='utf-8'))
pub_vc = int(pub.get('versionCode', 0))
if vcode < pub_vc:
    sys.stderr.write(
        "错误: 新清单 versionCode=%d 低于已发布的 %d；这会让所有已发布的用户判定为「无更新」。\n"
        "      发布新版本请先用 scripts/bump-version.sh 提升版本号。\n" % (vcode, pub_vc))
    sys.exit(1)
if vcode == pub_vc and pub.get('sha256') and pub['sha256'] != sha:
    sys.stderr.write(
        "警告: versionCode 仍为 %d，但 APK 内容已变（sha256 不同）。\n"
        "      客户端只按 versionCode 判定，已装旧包的用户不会收到这次更新。\n" % vcode)
PY
      then
        exit 1
      fi
    fi
    ;;
esac

mkdir -p "$(dirname "$OUT")"
"$PYTHON_BIN" -c '
import io, json, os, sys, datetime
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
    "releaseDate": datetime.date.today().isoformat(),
    "sha256": sha,
}
io.open(out, "w", encoding="utf-8").write(json.dumps(payload, ensure_ascii=False, indent=2))
print("已生成 %s" % out)
print(json.dumps(payload, ensure_ascii=False, indent=2))
' "$VNAME" "$VCODE" "$APK" "$CHANGELOG" "$MANDATORY" "$SHA" "$ASSET_URL" "$OUT"
