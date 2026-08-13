# 晨昏证据图谱（Daily Asking）

> 本地优先的职场证据成长助手：每天记录一件真实小事，把痕迹变成证据，把证据变成成果。

[English](README.en.md) · [日本語](README.ja.md) · [MIT License](LICENSE)

晨昏证据图谱是一款**本地优先**的移动应用：用"今天发生的一件真实小事"作为起点，通过结构化的追问，把零散的工作记录逐步沉淀为可检索、可复用的**职场证据图谱**，并在你需要的时候一键生成简历要点、周报或面试追问卡。

**核心理念：数据是你的，AI 是选修。**

---

## ✨ 特性

- **本地优先，隐私默认**：所有记录默认保存在本机，无账号、无登录、无订阅、无云同步、无遥测。
- **每日一问**：保存记录后，本地规则引擎最多追问一个"最值得补充"的问题（结果 / 背景 / 行动 / 难点 / 个人贡献），帮你把流水账变成完整证据。
- **证据图谱**：按时间与标签检索全部记录，支持全文搜索与近 7 天 / 近 30 天筛选，完整度一目了然。
- **工作室（可选 AI）**：选择一条或多条证据，生成简历要点 / 周报 / 面试追问卡。
- **BYOK（Bring Your Own Key）**：AI 调用使用你自己的 API Key（OpenAI 兼容），Key 只保存在本机隔离存储，页面不回显；每次真实调用前展示**出站披露**，确认后才发送，且只发送你选中的最小字段。
- **主题切换**：跟随系统 / 亮色 / 深色。
- **版本更新**：关于页手动检查更新、启动自动检查；可开启「自动更新」，强制更新不可跳过；更新清单与 APK 校验见 [docs/02-版本与更新机制.md](docs/02-版本与更新机制.md)。

## 🚀 快速开始

### 环境要求

- Flutter 3.44+（Dart 3.12+）
- Android SDK（构建 Android 应用）

### 运行

```bash
flutter pub get
flutter run
```

### 测试与检查

```bash
flutter analyze
flutter test
flutter build apk --release
```

## 📦 安装

目前在 `app-release.apk` 提供 Android 安装包（不纳入仓库）。你也可以按上述步骤自行构建。

## 🧭 界面导览

| 页面 | 说明 |
| --- | --- |
| 今日 | 快速记录一件真实小事，并响应本地追问 |
| 证据 | 检索 / 筛选全部证据记录，查看完整度 |
| 工作室 | 选择证据生成简历要点 / 周报 / 面试追问卡 |
| 设置 | 主题、可选 AI（BYOK）配置、隐私说明 |

## 🏗️ 架构

- `lib/core/` — 领域模型、存储抽象、可选 LLM 客户端
- `lib/evidence/` — 证据记录、追问引擎、证据图谱
- `lib/journal/` — 今日记录页
- `lib/artifacts/` — 工作室与产物管理
- `lib/settings/` — 设置、BYOK 配置与 API Key 加密存储
- `lib/updater/` — 版本检查与更新机制
- `lib/app/` — 应用壳与全局状态

详见 [docs/architecture.md](docs/architecture.md)。

## 🔒 安全

- 日志不记录 API Key、记录正文与提示词全文。
- 真实 AI 调用只发送你选中的最小字段，且出站前必须确认。
- 发现安全问题请参阅 [SECURITY.md](SECURITY.md)。

## 🤝 贡献

欢迎提交 Issue 与 PR。请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 📄 许可证

[MIT License](LICENSE) © 2026 greatleo31