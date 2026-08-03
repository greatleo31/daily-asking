# Daily Asking

Daily Asking 是一个本地优先的 Flutter Android APK：每天记录实习/工作里的真实小事，通过 BYOK AI 追问补全事实，再生成简历 bullet、周报和面试追问卡。

## 产品目标

- Android APK 优先，通过 GitHub Release 发布可安装包。
- 核心记录能力离线可用，不要求账号、后端或 AI 配置。
- 用户自行配置 OpenAI-compatible LLM API Key，Key 只进入系统安全存储。
- 每次真实 AI 调用前明确展示将发送的记录字段，不默认上传整个记录池。
- AI 只基于用户提供的事实整理内容，禁止编造数字、公司名、项目名、成果或职责范围。

## 核心闭环

1. 每日记录：写下任务、背景、行动、结果和卡点。
2. 记录池管理：查看、编辑、删除、搜索、筛选和导出本地记录。
3. AI 追问：针对选中记录补足指标、范围、协作、取舍和复盘。
4. 产物生成：生成简历 bullet、周报和面试追问卡。
5. 本地沉淀：记录、追问和产物默认保存在本机。

## 安装与运行

当前目标发布物是 GitHub Release 中的 Android APK。源码本地运行需要 Flutter SDK 和 Android 构建环境。

```bash
flutter pub get
flutter run
```

如果本机没有 `flutter` 命令，请先安装 Flutter SDK 并加入 PATH；否则无法完成本地 analyze、test 或 APK build。

## BYOK AI 配置

在应用“设置”中配置：

- Provider 名称
- OpenAI-compatible Base URL
- Model
- API Key

保存后 API Key 不会在页面回显，也不应进入数据库、日志、导出包或迁移包。清除配置时必须同时删除系统安全存储中的 Key。

## 离线能力

无网络或未配置 AI 时，应用仍应支持：

- 新增、查看、编辑、删除记录
- 关键词搜索和日期范围筛选
- Markdown / JSON 导出
- 隐私边界查看

真实 AI 追问和产物生成需要用户配置可用的 BYOK provider，并在发送前确认出站内容。

## 隐私边界

- 本地优先：记录默认保存在本机。
- 最小出站：真实 AI 请求只发送当前任务必要字段。
- 明确确认：每次真实 AI 请求前展示 provider、model、调用路径和字段范围。
- 密钥隔离：API Key 只进入系统安全存储，不进入记录、日志、导出包或迁移包。
- 诚实生成：AI 输出必须标记缺失证据和风险，不得把缺失事实改写成确定成果。

## 验证

在 Flutter-ready 环境中执行：

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
# 如果本地 Maven/Google 仓库 TLS 握手失败，可改用：
cd android
.\gradlew assembleRelease --init-script gradle-mirrors.init.gradle
```

OpenSpec PRD/设计/任务验证：

```bash
openspec validate production-v1-prd --strict
openspec status --change production-v1-prd
```

## OpenSpec 工作流

本项目使用 OpenSpec 承载生产级 PRD 和实现任务。

- 项目约束：`openspec/config.yaml`
- 当前 change：`openspec/changes/production-v1-prd/`
- 需求规格：`openspec/changes/production-v1-prd/specs/**/spec.md`
- 技术设计：`openspec/changes/production-v1-prd/design.md`
- 实现任务：`openspec/changes/production-v1-prd/tasks.md`

非平凡业务变更必须先更新 Spec，再改代码。

## 发布标准

GitHub Release 级发布至少需要：

- Android APK 附件
- release notes
- README 使用说明
- 隐私与安全说明
- `flutter analyze`、`flutter test`、release APK build 的验证结果
- APK 签名姿态说明

如果 release APK 仍使用 debug signing，必须标记为 GitHub preview release，不得宣称为应用商店级生产包。详见 `docs/release-signing.md`，release notes 可使用 `docs/release-notes-template.md`。

## 已知限制

- 当前目标不包含云同步账号体系。
- 当前目标不包含应用商店发布。
- 当前目标不默认启用官方 Worker gateway 或邀请码体系。
- 当前仓库仍在执行 `production-v1-prd`，部分生产级能力尚未实现。
