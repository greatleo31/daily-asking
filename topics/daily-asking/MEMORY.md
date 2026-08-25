# Memory: daily-asking

## Current Status

- OpenSpec 变更 `optimize-app-architecture` 已完成规格、后端、前端、自动化验证和雷电真实 UI smoke，并已归档至 `openspec/changes/archive/2026-08-25-optimize-app-architecture`。
- 最终验证：`C:\src\flutter\bin\flutter.bat analyze` 无问题；`flutter test` 69/69；本地 Android MCP 握手和五条真实 UI 路径 smoke 通过。

## Decisions

- 本地优先是硬约束：所有业务数据经 `StorageService` 抽象持久化（当前 SharedPreferences JSON，未来可换 SQLite/Drift 而不动上层）。Why: 隐私默认、无云同步。How to apply: 新增持久化一律走 StorageService 抽象。
- BYOK 最小字段 + 出站披露：真实 AI 调用前必须 `OutboundPayload.toDisclosure(...)` 展示并确认，只发送用户选中的最小字段。Why: 隐私合规。How to apply: 任何新增 AI 出站路径都必须带披露步骤。
- API Key 只存 `flutter_secure_storage`，页面不回显；旧明文 Key 启动时自动迁移。Why: 凭据安全。How to apply: 不得向 SharedPreferences 写入 Key。
- 日志三不记录：API Key、记录正文、提示词全文。Why: 隐私。How to apply: 新代码不得输出这三类内容。
- 版本单一来源 `lib/core/version.dart`，与 pubspec.yaml 同步由 `scripts/bump-version.sh` 维护。How to apply: 改版本走脚本，不手改两处。
- 本地追问引擎是纯业务规则（无 UI 依赖），可单测。How to apply: 新追问逻辑放 question_engine，保持可测。
- 保持 Provider + 单一 AppState 门面：跨 Entry/Question/Answer 操作需要单一一致性刷新边界，不为“架构整洁”拆成互相协调的 FeatureController。Why: 避免跨 Controller 状态同步复杂度。How to apply: 只有测量证明 AppState 或重建成本仍不可控时才拆分。
- 证据聚合使用一次 Question 集合读取并按 Entry 分组；当前存储 key 已按 `entries_v1/questions_v1/answers_v1/artifacts_v1` 分区，不要重复设计“分区 key”。Why: 消除真实 O(E×Q) 查询放大。How to apply: 新证据聚合复用批量路径。

## Implementation References

- 存储抽象：`lib/core/storage/` 的 `StorageService` + `JsonStore` 模式；Repository 隔离存储细节。
- 批量证据路径：`lib/evidence/evidence_repository.dart` 的 `listQuestions/listAnswers/questionsByEntryIds`；`lib/evidence/evidence_service.dart::refreshView` 同时构建 metrics 与开放问题分组。
- LLM 客户端：`lib/core/llm/llm_client.dart` — OpenAI 兼容、DNS 预检、有限重试、响应归一化（支持多模态 content 数组与 responses 风格兜底）。
- 全局状态：`lib/app/app_state.dart::AppState` 保留组合根/门面；写操作按证据、产物、设置域定向刷新，UI 用 `context.select` 订阅最小状态。
- 更新机制：`lib/updater/`（update_service/update_info/update_prefs），协议见 docs/02-版本与更新机制.md。
- 本地 Android MCP：`D:/new-daily-asking/tools/android-mcp-server/run_server.py` 作为 stdio 服务入口，`config.yaml` 将设备固定为 `127.0.0.1:5555`；`run_server.py` 将 `D:/leidian/LDPlayer9` 注入本进程 PATH。OMP 注册位于 `C:/Users/胡衍科/.omp/agent/mcp.json` 的 `mcpServers.android`。

## Constraints

- 无账号、无登录、无订阅、无云同步、无遥测。
- Android 目标平台（Flutter 3.44+ / Dart 3.12+）。
- question_engine：每次保存后最多生成一个问题；同条记录上被 skip 的问题不立即重复。

## Known Pitfalls

- 不要在 AppState 之外另起全局状态，避免双源。How to apply: 全局状态统一走 Provider 注入。
- 不要绕过 StorageService 直接读写 SharedPreferences（除 settings_repository 的 BYOK 隔离存储）。
- 不要在 UI 层实现追问规则逻辑，否则无法单测。How to apply: 规则进 question_engine。
- Android UI 验证必须使用本地 `android-mcp-server` 的真实 MCP 工具（`get_uilayout`、`get_screenshot`、`execute_adb_shell_command` 等）；ADB 在线本身不能替代 MCP。配置变更后需要重启 OMP 会话，当前会话的工具清单不会自动热加载。

## Fixes and Lessons

- 架构优化 change 的测试必须覆盖批量读取边界、回答回填、未知问题无部分写入、级联删除和 AppState 定向刷新；已有 11 个定向测试与 69 个全量测试通过。

## Open Follow-ups

- 新 OMP 会话启动后确认 `android` server 已挂载；服务应继续锁定雷电 `127.0.0.1:5555`，不要改回桌面 Chrome DevTools MCP。

## Related Topics

- OpenSpec specs（openspec/specs/）— 长期能力规范，归档时同步。
