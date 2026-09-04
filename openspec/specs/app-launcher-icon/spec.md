# app-launcher-icon Specification

## Purpose
TBD - created by archiving change app-icon-from-favicon. Update Purpose after archive.
## Requirements
### Requirement: 启动器图标来源

Android 应用在系统桌面上的启动器图标 SHALL 使用与 `daily-asking-website/_static/favicon` 同源的品牌图形（以该目录下高分辨率 PNG 或 SVG 导出为准），SHALL NOT 继续使用替换前的默认 Flutter 占位图标。

#### Scenario: 安装后桌面可见
- **WHEN** 用户安装或重装本应用并查看系统桌面/应用抽屉
- **THEN** 启动器图标外观 SHALL 与网站 favicon 品牌图形一致（允许系统圆角/遮罩裁切）
- **AND** 应用显示名仍为「留痕」

### Requirement: 密度资源齐全

应用 SHALL 为 Android 常用密度提供 `ic_launcher` 资源，使 mdpi 至 xxxhdpi 桌面均显示清晰图标，无明显拉伸模糊（相对同目录源图）。

#### Scenario: 多密度
- **WHEN** 在不同屏幕密度的设备或模拟器上查看启动器图标
- **THEN** 图标 SHALL 保持可辨识，不出现明显像素拉花

### Requirement: 不扩大范围

本能力 SHALL NOT 要求修改应用内页面 UI、色板、伙伴素材或 iOS 图标（除非另有 change）。

#### Scenario: 范围
- **WHEN** 仅完成本 change
- **THEN** 今日/记录/工作室/设置页视觉除系统任务切换器可能显示的新图标外 SHALL 无强制改动

