## Why

应用启动器图标仍是 Flutter 默认图，与官网/站点 favicon 视觉不一致。用户指定用 `daily-asking-website/_static/favicon` 素材替换 Android 启动器图标，统一品牌识别。

## What Changes

- 用网站 favicon 目录素材生成/替换 Android `mipmap-*/ic_launcher.png`（主源优先 `android-chrome-512x512.png` 或 `square.svg` 导出）。
- 保持 `AndroidManifest` 仍引用 `@mipmap/ic_launcher`；应用名「留痕」不变。
- 真机/模拟器重装或清图标缓存后可见新图标；截屏桌面图标验收。
- 可选：若项目引入 `flutter_launcher_icons` 仅作生成工具，须写入 pubspec 并保证可复现；也可手工导出各密度 PNG。二者择一，design 写明。

## Non-goals

- 不改 iOS 图标（当前交付以 Android 为主，除非用户另开刀）。
- 不改启动页 Splash 插画、色板、伙伴素材、应用内 UI。
- 不改包名 / applicationId / 版本号（除非生成工具强制旁路，禁止顺手 bump）。
- 不做通知小图标定制（除非系统强制共用 launcher，则仅随 launcher 替换）。

## Capabilities

### New Capabilities

- `app-launcher-icon`: Android 启动器图标与网站 favicon 视觉对齐的可观察要求。

### Modified Capabilities

- （无）

## Impact

- 页面：系统桌面启动器图标（非 App 内四页）。
- 路径：`android/app/src/main/res/mipmap-*/ic_launcher.png`；素材源 `../daily-asking-website/_static/favicon/`。
- 测试：无业务单测强制；验收靠重装后桌面截屏；`flutter analyze` / 现有 test 不得因本 change 变红。
- 隐私：无出站、无 BYOK 变更。

## 人工闸门清单

- [x] 0.1 范围确认（用户指定 favicon 路径并允许最小 OpenSpec 后 apply）
- [x] 0.2 样式：采用网站 favicon 既有图形，不另选画风
- [x] 0.3 功能规划：只换 Android launcher 图标
- [x] 0.4 proposal + specs（随本最小包一次确认）
- [x] 0.5 design（随本最小包一次确认）
- [x] 0.6 tasks + 允许墨工 apply（用户明示）
- [ ] 0.7 用户看桌面图标截屏通过后 archive
