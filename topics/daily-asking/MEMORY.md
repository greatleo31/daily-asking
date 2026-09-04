# Memory: daily-asking

## Current Status

- OpenSpec 变更 `companion-growth-ui` 已随 v1.2.0 归档至 `openspec/changes/archive/2026-09-04-companion-growth-ui`；主规范 `openspec/specs/companion-growth` 同步建立。
- OpenSpec 变更 `studio-weekly-copy-markdown` 已用户 0.7 通过并归档至 `openspec/changes/archive/2026-09-04-studio-weekly-copy-markdown`：去证据名、标题不可拷、周报七段、直接 Markdown 渲染；`artifactPromptVersion=markdown.v2`。

- OpenSpec 变更 `app-icon-from-favicon` 已用户 0.7 通过并归档至 `openspec/changes/archive/2026-09-04-app-icon-from-favicon`；Android 启动器图标与网站 favicon 同源，放大减留白。

- OpenSpec 变更 `followup-field-priority` 已用户 0.7 通过并归档至 `openspec/changes/archive/2026-09-03-followup-field-priority`；主规范同步 `local-followup-questions`（优先级背景→行动→结果→难点→个人贡献；今日页连续追问；去掉稍后；结果 reason 无「先补它」）。

- OpenSpec 变更 `ui-record-copy-and-list-polish` 已用户 0.7 通过并归档至 `openspec/changes/archive/2026-09-03-ui-record-copy-and-list-polish`；主规范新增 `openspec/specs/record-copy-and-list-ui`（用语「记录」、今日沉淀一行、占位、待补充卡结构、列表去完整度小字+加大圆标）。analyze 0；全量 test 171 绿。

- OpenSpec 变更 `optimize-app-architecture` 已完成规格、后端、前端、自动化验证和雷电真实 UI smoke，并已归档至 `openspec/changes/archive/2026-08-25-optimize-app-architecture`。
- 最终验证：`C:\src\flutter\bin\flutter.bat analyze` 无问题；`flutter test` 69/69；本地 Android MCP 握手和五条真实 UI 路径 smoke 通过。

## Decisions

- 工作室周报输出结构：本周完成工作 / 本周工作总结 / 下周工作计划 / 需协调与帮助 / 备注 / 图片（空段）/ 附件（空段）；阅读页直接 Markdown 渲染（无分块卡片）；块级复制不含标题。How to apply: 新生成走该结构；勿回退旧周报章节或卡片开片。

- 今日页追问：缺字段按 背景→行动→结果→难点→个人贡献；答完/跳过立刻下一缺字段卡直至补齐或全 skip；操作只留「跳过/回答」，无「稍后」；个人贡献可追问，答过或跳过即不再问；结果问 reason 为「结果/验证最能体现价值」。Why: 覆盖完整且连续补齐。How to apply: 新追问逻辑保持引擎顺序与今日连弹，勿回退「仅结果」或「稍后」。

- 用户可见用语统一为「记录」（含底栏原「证据」）；列表卡不展示「完整度 xx%」小字，圆标需容纳 100%；图谱统计「平均完整度」可保留。Why: 扫读密度与文案一致。How to apply: 新 UI 文案默认「记录」；列表卡勿回加完整度字幕。

- 本地优先是硬约束：所有业务数据经 `StorageService` 抽象持久化（当前 SharedPreferences JSON，未来可换 SQLite/Drift 而不动上层）。Why: 隐私默认、无云同步。How to apply: 新增持久化一律走 StorageService 抽象。
- BYOK 最小字段 + 出站披露：真实 AI 调用前必须 `OutboundPayload.toDisclosure(...)` 展示并确认，只发送用户选中的最小字段。Why: 隐私合规。How to apply: 任何新增 AI 出站路径都必须带披露步骤。
- API Key 只存 `flutter_secure_storage`，页面不回显；旧明文 Key 启动时自动迁移。Why: 凭据安全。How to apply: 不得向 SharedPreferences 写入 Key。
- 日志三不记录：API Key、记录正文、提示词全文。Why: 隐私。How to apply: 新代码不得输出这三类内容。
- 版本单一来源 `lib/core/version.dart`，与 pubspec.yaml 同步由 `scripts/bump-version.sh` 维护。How to apply: 改版本走脚本，不手改两处。
- 本地追问引擎是纯业务规则（无 UI 依赖），可单测。How to apply: 新追问逻辑放 question_engine，保持可测。
- 保持 Provider + 单一 AppState 门面：跨 Entry/Question/Answer 操作需要单一一致性刷新边界，不为“架构整洁”拆成互相协调的 FeatureController。Why: 避免跨 Controller 状态同步复杂度。How to apply: 只有测量证明 AppState 或重建成本仍不可控时才拆分。
- 证据聚合使用一次 Question 集合读取并按 Entry 分组；当前存储 key 已按 `entries_v1/questions_v1/answers_v1/artifacts_v1` 分区，不要重复设计“分区 key”。Why: 消除真实 O(E×Q) 查询放大。How to apply: 新证据聚合复用批量路径。
- UI 优化必须保留人的深度参与：用户先提出具体优化点、目标和取舍，助手不得自行决定整套改版、自动创建无明确范围的 PR 或连续批量改动。Why: 视觉与产品判断属于核心决策。How to apply: 先逐点讨论并确认，再按单点实现、验证和更新 PR。
- 伙伴视觉原型已确认为“种子生物开花”四阶段：小芽、花苞、白花、粉花加蜜蜂。主体保持同一软质圆润生物，成长主要通过头顶植物状态和陪伴性小物件表达。Why: 用户已确认该图为伙伴原型。How to apply: 先按此原型拆分四阶段素材并确认透明背景、尺寸、锚点，再进入 Flutter 动态实现；不要擅自替换为其他生物或画风。
- 用户已提供四张完整独立伙伴图，可采用“整图状态切换”而非分层素材：小芽、花苞、白花、粉花加蜜蜂。前端第一版使用四张静态素材，通过淡入淡出、轻微舒展/呼吸和保存成功后的状态切换表达成长。Why: 用户明确只能提供完整单独图片。How to apply: 不要求用户重新拆分身体与植物层；实现前先统一画布、底部基线和显示尺寸。

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

- 以后做清单落盘：`docs/backlog-v2-later.md`（多模态素材中心、每日任务/delay、打卡推送、工作室残留「证据」文案、App 图标对齐网站 favicon）。新功能先记文档再开 change。

- `followup-field-priority`（连续追问 + 去掉稍后）仍待用户明确最终 0.7 / archive；结果问 reason 已改为「结果/验证最能体现价值」。

- 新 OMP 会话启动后确认 `android` server 已挂载；服务应继续锁定雷电 `127.0.0.1:5555`，不要改回桌面 Chrome DevTools MCP。

## Related Topics

- OpenSpec specs（openspec/specs/）— 长期能力规范，归档时同步。
