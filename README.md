# Daily Asking

Daily Asking 是一个本地优先的 Flutter APK：每天把实习/工作里的小事记录下来，通过 AI 追问补全事实，再生成简历 bullet、周报和面试追问卡。

## 第一版目标

- Android APK 优先，核心功能离线可用。
- 用户自行导入 OpenAI-compatible LLM API Key，Key 只进入系统安全存储。
- AI 调用前明确展示将发送的内容，不默认上传整个记录池。
- 不在客户端放邀请码生成规则、硬编码模型 Key 或第三方远程脚本。

## 核心闭环

1. 每日记录：写下今天做了什么、背景、行动、结果和卡点。
2. AI 追问：补足指标、范围、协作、取舍和复盘。
3. 产物生成：输出简历 bullet、周报、面试追问卡。
4. 本地沉淀：记录、追问与产物默认保存在本机。

## 安全原则

- 本地优先：无 AI 配置也能记录、编辑、搜索和导出。
- BYOK：用户 Key 不进入日志、数据库或迁移包。
- 最小出站：只发送当前任务必要上下文。
- 诚实生成：禁止编造数字、公司名、成果和职责范围。

## 开发

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

> 当前环境如果没有安装 Flutter CLI，需要先安装 Flutter SDK 并加入 PATH。
