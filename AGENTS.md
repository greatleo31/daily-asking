# Daily Asking 智能体协作说明

始终使用中文回答，保持直接、简洁、工程化，不写空话。

## 项目定位

Daily Asking 是本地优先的 Flutter Android APK，用于记录真实工作经历，通过 BYOK AI 追问补足事实，并生成简历要点、周报和面试追问卡。

## 默认工作流

1. 先探索现状，再下结论；能通过代码、配置、OpenSpec 文档确认的，不要靠猜。
2. 非平凡业务变更必须先更新或读取对应 OpenSpec 变更，再改代码。
3. 优先做最小可验证改动，避免无关重构。
4. 每完成一个原子任务，运行匹配验证；若本机缺少 Flutter/Dart 环境，明确记录未验证项。
5. 最终汇报必须说明：做了什么、验证了什么、还有什么风险或未验证项。
6. 项目文档正文必须使用中文；命令、路径、配置键、API 名、包名和 OpenSpec 语法关键字可保留原文。

## OpenSpec 约束

- v0.1 生产规格基线已归档到 `openspec/changes/archive/2026-08-09-production-v1-prd/`。
- 长期需求真相源在 `openspec/specs/**/spec.md`。
- 新的非平凡业务变更必须创建独立 `openspec/changes/<change>/`，不得继续修改已归档基线。
- 项目级约束在 `openspec/config.yaml`。
- 变更需求在 `openspec/changes/<change>/proposal.md` 和 `specs/**/spec.md`。
- 技术方案在 `openspec/changes/<change>/design.md`。
- 实现顺序在 `openspec/changes/<change>/tasks.md`。
- 代码、测试、构建结果只能作为验证证据，不能替代规格。

## 安全边界

- 不要硬编码 API Key、令牌、密码或签名凭据。
- API Key 只能进入系统安全存储，不能进入日志、本地记录、导出包、迁移包或提交文件。
- AI 请求前必须披露服务商、模型、调用路径和将发送的字段范围。
- 默认最小出站：只发送用户当前选择任务所需记录，禁止默认上传整个记录池。
- AI 产物不得编造数字、公司名、项目名、职责范围或影响；证据不足时必须标记缺失信息。

## 验证命令

在已准备 Flutter 环境的机器上默认执行：

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

OpenSpec 文档变更默认执行当前变更的严格校验；无活动变更时校验全部主规格：

```bash
openspec validate --all --strict
```
