# 更新日志（Changelog）

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.2.0] - 2026-09-04

### 新增

- 伙伴成长：按累计记录自然日推进「小芽→花苞→白花→粉花加蜜蜂」四阶段；今日页伙伴卡与克制语录、第 1/7/14/30 天节点庆祝、保存记录即时回应；设置页伙伴管理（命名/重置）。纯本地规则，不调用 LLM、不联网。
- 本地追问字段优先级与连续补齐：按「背景→行动→结果→难点→个人贡献」逐缺追问，答完/跳过立即续问；去掉「稍后」；结果追问引导改为「结果/验证最能体现价值」。
- 界面统一「记录」用语与列表润色：今日未记录占位、待补充卡、列表完整度圆标（去掉小字百分比）。
- 工作室：周报七段结构（本周完成/总结/下周计划/需协调与帮助/备注/图片/附件），阅读页直接 Markdown 渲染、块级复制不含标题、去证据名；产物详情 Agent/LLM 决策结果视图（总体评价→逐条点评→热点→补强→原文核验，不虚构评级/置信度），操作收敛到 ⋯ 菜单并支持 Markdown 导出与重新分析。
- App 图标与网站 favicon 同源（放大减留白）。

### 修复

- 今日跨天进程存活不刷新：恢复前台/切回今日页重算日期与列表。
- 逐条点评多行字段解析：支持空标签续行与字段内子标签行，空字段不渲染空标签。

### 技术

- 架构优化（openspec `optimize-app-architecture`）：证据批量读取收敛、Repository 边界与 AppState 定向刷新。
- AI 提示词结构化（prompt 版本推进）；OpenSpec 主规范同步归档五项变更。

## [1.1.1] - 2026-08-13

### 新增

- 版本与更新机制（需求 2）：`关于` 页「检查更新」、启动自动检查、设置页「自动更新」开关；强制更新不可关闭。
- 更新清单协议 `latest.json`（versionCode / versionName / url / changelog / mandatory / sha256 等），DownloadManager 下载 + SHA-256 校验 + 系统安装页。
- API Key 迁移到加密存储：flutter_secure_storage（Android Keystore + EncryptedSharedPreferences），旧明文自动迁移并删除。
- 发布脚本：`scripts/bump-version.sh`（单一来源版本号）、`scripts/generate-latest-json.sh`（生成更新清单）。
- 关于页展示版本号与上次检查时间。

### 技术

- 版本号单一来源 `lib/core/version.dart`（v1.1.1 / versionCode 10101），与 pubspec 同步。
- 更新相关单元测试：清单解析容错、版本比对三态、versionCode 公式。

## [1.0.0] - 2026-08-11

### 新增

- 首个公开版本（留痕 v2）。
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