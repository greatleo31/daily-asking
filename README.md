# Daily Asking

Daily Asking 是一个本地优先的 Flutter Android APK：每天记录实习/工作里的真实小事，通过 BYOK AI 追问补全事实，再生成简历要点、周报和面试追问卡。

## 产品目标

- Android APK 优先，通过 GitHub Release 发布可安装包。
- 核心记录能力离线可用，不要求账号、后端或 AI 配置。
- 用户自行配置兼容 OpenAI 接口的大模型 API Key，Key 只进入系统安全存储。
- 每次真实 AI 调用前明确展示将发送的记录字段，不默认上传整个记录池。
- AI 只基于用户提供的事实整理内容，禁止编造数字、公司名、项目名、成果或职责范围。

## 核心闭环

1. 每日记录：写下任务、背景、行动、结果和卡点。
2. 记录池管理：查看、编辑、删除、搜索、筛选和导出本地记录。
3. AI 追问：针对选中记录补足指标、范围、协作、取舍和复盘。
4. 产物生成：生成简历要点、周报和面试追问卡。
5. 本地沉淀：记录、追问和产物默认保存在本机。

## 安装与运行

当前目标发布物是 GitHub Release 中的 Android APK。源码本地运行需要 Flutter SDK 和 Android 构建环境。

```bash
flutter pub get
flutter run
```

如果本机没有 `flutter` 命令，请先安装 Flutter SDK 并加入 PATH；否则无法完成本地静态检查、测试或 APK 构建。

## BYOK AI 配置

在应用“设置”中配置：

- 服务商名称
- 兼容 OpenAI 接口的基础地址
- 模型名称
- API Key

保存后 API Key 不会在页面回显，也不应进入数据库、日志、导出包或迁移包。清除配置时必须同时删除系统安全存储中的 Key。

## 离线能力

无网络或未配置 AI 时，应用仍应支持：

- 新增、查看、编辑、删除记录
- 关键词搜索和日期范围筛选
- Markdown / JSON 导出
- 隐私边界查看

真实 AI 追问和产物生成需要用户配置可用的大模型服务商，并在发送前确认出站内容。

## 隐私边界

- 本地优先：记录默认保存在本机。
- 最小出站：真实 AI 请求只发送当前任务必要字段。
- 明确确认：每次真实 AI 请求前展示服务商、模型、调用路径和字段范围。
- 密钥隔离：API Key 只进入系统安全存储，不进入记录、日志、导出包或迁移包。
- 诚实生成：AI 输出必须标记缺失证据和风险，不得把缺失事实改写成确定成果。

## 验证

在已准备 Flutter 环境的机器上执行：

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
# 如果本地 Maven/Google 仓库 TLS 握手失败，可改用：
cd android
.\gradlew assembleRelease --init-script gradle-mirrors.init.gradle
```

OpenSpec PRD、设计和任务验证：

```bash
openspec validate --all --strict
openspec list
```

## OpenSpec 工作流

本项目使用 OpenSpec 承载生产级 PRD 和实现任务。

- 项目约束：`openspec/config.yaml`
- 长期需求规格：`openspec/specs/**/spec.md`
- v0.1 归档变更：`openspec/changes/archive/2026-08-09-production-v1-prd/`
- 新变更目录：`openspec/changes/<change-name>/`

非平凡业务变更必须先更新规格，再改代码。

## 文档语言

项目文档正文必须使用中文。命令、路径、配置键、API 名、包名、GitHub / OpenSpec / Flutter 等产品名，以及 OpenSpec 语法关键字可以保留原文。

## 发布标准

GitHub Release 级发布至少需要：

- Android APK 附件
- 发布说明
- README 使用说明
- 隐私与安全说明
- `flutter analyze`、`flutter test`、发布 APK 构建的验证结果
- APK 签名姿态说明

如果发布 APK 仍使用调试签名，必须标记为 GitHub 预览发布，不得宣称为应用商店级生产包。详见 `docs/release-signing.md`，发布说明可使用 `docs/release-notes-template.md`。

## 已知限制

- 当前目标不包含云同步账号体系。
- 当前目标不包含应用商店发布。
- 当前目标不默认启用官方 Worker 网关或邀请码体系。
- 当前 v0.1 仍使用调试签名，只能作为 GitHub 预览 APK；正式签名与产品体验重构将在后续独立变更中完成。
