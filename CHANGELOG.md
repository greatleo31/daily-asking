# 更新日志（Changelog）

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0.0] - 2026-08-11

### 新增

- 首个公开版本（晨昏证据图谱 v2）。
- 本地优先的证据记录：今日快速记录 + 本地追问规则引擎（结果 / 背景 / 行动 / 难点 / 个人贡献，每次最多一问）。
- 证据图谱：全文搜索、按标签与时间筛选、完整度展示。
- 工作室：从选中证据生成简历要点 / 周报 / 面试追问卡。
- BYOK 可选 AI：OpenAI 兼容调用、API Key 隔离存储、出站披露与最小字段发送。
- 隐私与安全：无账号、无遥测、日志不记录 API Key / 正文 / 提示词。
- 主题切换：跟随系统 / 亮色 / 深色。
- 文档：README（中 / 英 / 日）、SECURITY、CONTRIBUTING、架构说明。

### 修复

- 修复 Android 无法发送网络请求的问题（清单缺少 INTERNET 权限导致 BYOK 调用失败）。
- 修复 LLM 响应解析：支持 OpenAI 多模态 content 数组、responses 风格兜底、空响应与非法 JSON 的错误处理。

### 技术

- Flutter 3.44+ / Dart 3.12+。
- 存储基于 SharedPreferences 的 JSON 序列化（通过 Repository / Storage 抽象隔离，后续可替换为 SQLite / Drift）。
- `flutter analyze` 0 issue；`flutter test` 全绿。