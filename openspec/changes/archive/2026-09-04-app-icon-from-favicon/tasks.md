## 0. 人工闸门

- [x] 0.1–0.6 用户确认最小包并允许墨工 apply
- [x] 0.7 用户确认桌面图标截屏后 archive

## 1. 替换图标资源

- [x] 1.1 从 `daily-asking-website/_static/favicon/` 选取主源（优先 512 PNG，必要时 SVG）生成 mdpi–xxxhdpi `ic_launcher.png` 并覆盖 `android/app/src/main/res/mipmap-*/`
- [x] 1.2 确认 Manifest 仍为 `@mipmap/ic_launcher`；不改 label「留痕」；不 bump 版本
- [x] 1.3 未引入 flutter_launcher_icons；手工：Pillow 从 website android-chrome-512x512.png LANCZOS 导出 mdpi48/hdpi72/xhdpi96/xxhdpi144/xxxhdpi192 覆盖 mipmap-*/ic_launcher.png

## 2. 验证

- [x] 2.1 `flutter analyze` 0；现有 test 不因本 change 失败
- [x] 2.2 模拟器/真机重装后桌面截屏（至少一台）；问题表发回工笔
- [x] 2.3 等用户 0.7；合入勿夹无关 dirty
