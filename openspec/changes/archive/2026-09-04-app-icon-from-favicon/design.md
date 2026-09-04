## Context

用户指定素材目录：`D:\new-daily-asking\daily-asking-website\_static\favicon\`（含 `android-chrome-512x512.png`、`square.svg`、`android-chrome-192x192.png` 等）。App 当前仅有各密度 `mipmap-*/ic_launcher.png`，Manifest `android:icon="@mipmap/ic_launcher"`。

## Goals / Non-Goals

- Goals：替换 Android launcher 图标资源，与网站 favicon 对齐；可复现生成步骤。
- Non-Goals：iOS、Splash、色板、伙伴、版本 bump、业务代码。

## Decisions

- 主源图：优先 `android-chrome-512x512.png`；若需透明/矢量再以 `square.svg` 导出。
- 输出：覆盖 `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`。
- 工具：[待墨工选择并在 tasks 勾选] 手工导出 **或** 临时/正式加入 `flutter_launcher_icons` 配置指向源图。若加依赖，仅用于图标生成，不改业务 API。
- 自适应图标（anydpi-v26）：若当前工程无 adaptive XML，本 change **不强制新建**；以替换现有 mipmap PNG 为最小路径。若墨工发现缺 roundIcon 且设备显示异常，可补 `ic_launcher_round` 同源图，仍不扩 UI。
- 分层：无 Dart/UI 层改动；只动 Android 资源（及可选 pubspec 生成配置）。

## Risks / Trade-offs

- 桌面可能缓存旧图标 → 验收步骤含卸载重装或清启动器缓存。
- 网站 PNG 偏小（512）→ 导出 xxxhdpi 时注意锐度；不足则从 SVG 导出。

## Migration

- 无用户数据迁移。旧图标随安装包替换。

## Open Questions

- 无。样式以网站 favicon 为准，用户已选定路径。
