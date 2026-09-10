#!/usr/bin/env python3
"""从 APK 内二进制 AndroidManifest.xml 读取 versionCode / versionName。

发布清单必须描述**实际上传的 APK**，而 `lib/core/version.dart` 只描述源码状态：
两者可能不一致（见 docs/02-版本与更新机制.md §6.2），因此这里直接从 APK 读。

纯标准库实现（zipfile + struct），不依赖 aapt/aapt2 或 Android SDK，
Windows Git-Bash / Linux / CI 均可运行。

用法:
    python scripts/apk_version.py <apk路径>
输出:
    <versionCode> <versionName>      # 例: 10203 1.2.3
"""
import struct
import sys
import zipfile

# res/AndroidManifest.xml 的属性资源 ID（android 命名空间）
ATTR_VERSION_CODE = 0x0101021B
ATTR_VERSION_NAME = 0x0101021C

# 二进制 XML 块类型
CHUNK_STRING_POOL = 0x0001
CHUNK_RESOURCE_MAP = 0x0180
CHUNK_START_ELEMENT = 0x0102

# Res_value.dataType
TYPE_STRING = 0x03
TYPE_INT_DEC = 0x10
TYPE_INT_HEX = 0x11


def _u16(buf, off):
    return struct.unpack_from("<H", buf, off)[0]


def _u32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]


def _parse_string_pool(chunk):
    """解析 RES_STRING_POOL_TYPE，按索引返回字符串列表。"""
    count = _u32(chunk, 8)
    flags = _u32(chunk, 16)
    strings_start = _u32(chunk, 20)
    utf8 = bool(flags & (1 << 8))
    offsets = [_u32(chunk, 28 + 4 * i) for i in range(count)]

    out = []
    for off in offsets:
        pos = strings_start + off
        if utf8:
            # UTF-8 变体：u16 长度（字符数）+ u8 长度（字节数），均为变长编码
            n = chunk[pos]
            if n & 0x80:
                pos += 2
            else:
                pos += 1
            n = chunk[pos]
            if n & 0x80:
                n = ((n & 0x7F) << 8) | chunk[pos + 1]
                pos += 2
            else:
                pos += 1
            out.append(chunk[pos:pos + n].decode("utf-8", "replace"))
        else:
            n = _u16(chunk, pos)
            if n & 0x8000:
                n = ((n & 0x7FFF) << 16) | _u16(chunk, pos + 2)
                pos += 4
            else:
                pos += 2
            out.append(chunk[pos:pos + 2 * n].decode("utf-16-le", "replace"))
    return out


def read_manifest_attrs(axml):
    """返回 (manifest 元素属性字典, 字符串池)。键优先用资源 ID，回退用属性名。"""
    strings = []
    res_map = []
    off = 8  # 跳过文件头 ResChunk_header
    while off < len(axml):
        chunk_type = _u16(axml, off)
        chunk_size = _u32(axml, off + 4)
        if chunk_size <= 0:
            break
        if chunk_type == CHUNK_STRING_POOL:
            strings = _parse_string_pool(axml[off:off + chunk_size])
        elif chunk_type == CHUNK_RESOURCE_MAP:
            n = (chunk_size - 8) // 4
            res_map = [_u32(axml, off + 8 + 4 * i) for i in range(n)]
        elif chunk_type == CHUNK_START_ELEMENT:
            name_idx = _u32(axml, off + 20)
            if name_idx < len(strings) and strings[name_idx] == "manifest":
                attr_start = _u16(axml, off + 24)
                attr_count = _u16(axml, off + 28)
                base = off + 16 + attr_start
                attrs = {}
                for i in range(attr_count):
                    a = base + i * 20
                    name = _u32(axml, a + 4)
                    raw = _u32(axml, a + 8)
                    data_type = axml[a + 15]
                    data = _u32(axml, a + 16)
                    key = None
                    if name < len(res_map):
                        key = res_map[name]
                    if key is None and name < len(strings):
                        key = strings[name]
                    if key is None:
                        continue
                    if data_type == TYPE_STRING and data < len(strings):
                        value = strings[data]
                    elif data_type == TYPE_STRING and raw:
                        value = strings[raw] if raw < len(strings) else ""
                    else:
                        value = data
                    attrs.setdefault(key, value)
                return attrs, strings
        off += chunk_size
    return {}, strings


def apk_version(apk_path):
    """返回 (versionCode:int, versionName:str)。读不到则抛 ValueError。"""
    with zipfile.ZipFile(apk_path) as zf:
        try:
            axml = zf.read("AndroidManifest.xml")
        except KeyError:
            raise ValueError("APK 内缺少 AndroidManifest.xml: %s" % apk_path)
    attrs, strings = read_manifest_attrs(axml)

    code = attrs.get(ATTR_VERSION_CODE)
    name = attrs.get(ATTR_VERSION_NAME)
    if code is None or name is None:
        code = code if code is not None else attrs.get("versionCode")
        name = name if name is not None else attrs.get("versionName")
    if not isinstance(code, int):
        raise ValueError("未能从 APK 读取 versionCode: %s" % apk_path)
    if isinstance(name, int) and 0 <= name < len(strings):
        name = strings[name]
    if not isinstance(name, str) or not name:
        raise ValueError("未能从 APK 读取 versionName: %s" % apk_path)
    return code, name


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("用法: python scripts/apk_version.py <apk路径>\n")
        return 2
    try:
        code, name = apk_version(argv[1])
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        sys.stderr.write("读取 APK 版本失败: %s\n" % exc)
        return 1
    print("%d %s" % (code, name))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
