# record-import-export

> 来源：2026-09-15 与用户的 `grill-me` 设计访谈（Q1–Q27，全部结论按推荐采纳）。逐题结论见 `design.md` 的「决策记录」。

## Why

1. **数据只进不出。** 应用是本地优先、无账号、无云同步，但至今**没有任何把记录带回设备的手段**——换机、重装、误删即永久丢失。现有 4 个导出入口（记录页「导出全部」、记录详情页分享、工作室产物菜单、产物阅读页菜单）产出的全是**给人读的 Markdown**：不含 id、不含 `createdAt/updatedAt`，无法可靠回灌。
2. **Markdown 的信息损失是结构性的**，不是实现瑕疵：tags 值含空格或 `#` 会被拆错；追问的 `reason`、多答案（导出时以「；」拼成一条）、`稍后 / 已跳过` 状态在**导出那一刻**就已经丢了；字段值裸插值未转义，正文里自己写一行 `**完整度**：100%` 会被当成字段。
3. **老用户的文件会被今天的解析器直接判死。** v1.1 曾有过结构化导出（schema `daily_asking.entries.export.v1`，`8b422ff` 引入、`dae6e83` 删除），当时缺 `createdAt/updatedAt` 会回落到 `date`；而今天 `Entry.fromJson`（`lib/core/models.dart:76-87`）遇到缺失直接抛异常。
4. **导入会放大两个既有风险**：工作室的产物选材是**手选表且无任何时间范围**（`lib/artifacts/studio_page.dart:118`），「全选」（`:108-116`）会把列表里全部记录送进请求，而出站确认（`lib/core/llm/llm_client.dart:28`）**不显示条数**——库里突然多出几千条历史记录后，一次生成会把它们全部发往外部模型。

## What Changes

- **设置页新增「数据」分组**（沿用现有 Card + ExpansionTile + ListTile 结构，插在第 3、4 组之间），内含两个条目：**「导出数据（可再导入）」** 与 **「导入记录」**。记录页原有的「导出全部 Markdown」保持原样，两者并存、用途不同（人读 / 机器读）。
- **结构化导出（新）**：正常容量用一个 JSON 文件装全部数据，超限按下述 2026-09-17 修订自动分片，schema `daily_asking.export.v2`，顶层 `{schema, schemaVersion, exportedAt, appVersion, entries[], questions[], answers[]}`，字段名**与存储层完全一致**（camelCase，直接复用各模型的 `toJson()`，不做映射层）。文件名 `daily-asking-export-<yyyyMMdd-HHmm>.json`，落 App 私有外部目录并走系统分享面板；导出成功后提示一句「文件含你的全部记录（N 条），请谨慎分享」。文件天然不含 API Key（Key 在 `flutter_secure_storage`）。
- **导入（新）**：`file_picker` 选文件（可多选）→ 按 schema 分派解析：
  - v2 JSON：完整字段导入；
  - **旧 v1 JSON**：认 `daily_asking.entries.export.v1`，缺 `createdAt/updatedAt` 时回落到 `date`；
  - **Markdown 兜底**：严格状态机解析，只认行首 `## <日期>` 开新记录、只认已知的 `**字段**：` 标签，未知行忽略并计数，完整度**重算**，缺失字段用默认值补齐。
- **判重与冲突**：按 `id` 判重跳过（记录、追问、回答连带跳过）；无 id 的走「日期 + 规范化任务」指纹；**默认不覆盖**，本期不做覆盖开关。
- **时间戳策略**：导入记录的 `date/createdAt/updatedAt` 一律取**原记录日期**（缺失时用导入时刻），记录按真实时间线插回列表（列表按 `createdAt` 倒序，`lib/journal/journal_repository.dart:29-30`）。**导入路径绕过伙伴成长记账**（不走 `AppState._recordCompanionGrowth`），避免「导入一次，伙伴成长从第 3 天跳到第 30 天」。
- **来源标记**：导入的记录在 tags 追加 `#导入-YYYYMMDD`（批次标记），便于事后筛选；**本期不做一键撤销**。
- **预览与结果**：导入前先预览（新增 / 跳过重复 / 非法 三个数字 + 可展开清单，超过 50 条只渲染前 50 并注明总数）；落盘后结果页给出同样的三个数字与失败原因清单，并提供「查看导入的记录」按钮（关闭结果页并切到记录 Tab）。
- **落盘方式**：一次读入 → 内存合并 → 一次批量写回（为三个 Repository 增加 `saveAll`），不做逐条保存；部分失败不整体回滚（逐条独立校验，合法的全部写入）。
- **导入前自动快照**：落盘前把当前数据按同一 schema 快照到 App 私有目录 `backup/auto-<yyyyMMdd-HHmmss>.json`，只保留最近 3 份；设置页显示一行只读的「上次自动备份：…」，**本期不做恢复入口**。
- **文件限制**：只接受 `.json` 与 `.md`；单文件 ≤ 10 MB 且 ≤ 5000 条，超限直接拒绝并说明；只接受 UTF-8，非法序列整文件拒绝（不猜 GBK、不做容错替换）。
- **导入进行中**：泛化 `GenerationWaitingOverlay`（去掉对 `ArtifactType` 的硬绑定），显示「正在导入…」并挡系统返回；不做假百分比进度。
- **出站确认补条数**：工作室出站确认增加「将发送 N 条记录」，让「全选 + 导入」的规模变得可见。

## Non-goals

1. 不做「用留痕打开 .md」的 share / `ACTION_OPEN_DOCUMENT` intent 入口（本期只走设置页里的一次性文件选择）。
2. 不做「整库恢复」（清空后恢复）、不做覆盖同 id 记录。
3. 不做导入撤销（只有 `#导入-YYYYMMDD` 标记供人工筛选）。
4. 不做自动备份的恢复 UI（文件留在那里，需要时由人工/我们指导恢复）。
5. 不导入/导出产物、伙伴成长状态、设置（含主题、LLM 配置、API Key）。
6. 不支持 zip、目录、多文件合并之外的批量形态；不做云盘/网络导入。
7. 不做非 UTF-8 编码嗅探与容错替换。
8. 不改包名 / applicationId / MethodChannel 标识；不新增原生读文件通道（导出继续复用既有 `shareMarkdown`，导入由 `file_picker` 自带）。
9. 不把导入做成后台任务 / 断点续传；不做流式解析。
10. 不改 Markdown 导出格式本身（含「导出全部」里同一条记录出现两级同号标题这一既有瑕疵）。

## Capabilities

### New Capabilities

- `record-structured-export`：结构化 JSON 导出的 schema、入口、文件命名、隐私提示，以及导入前自动快照的可观察行为。
- `record-import`：导入入口、文件分派与限制、三种格式的解析契约、判重与时间戳策略、预览/结果页、批量落盘与来源标记。

### Modified Capabilities

- 无。工作室出站确认补条数属于 UI 文案增量，随 `record-import` 的边界要求一并声明，不改既有能力语义。

## Impact

- **页面**：设置页（新增「数据」分组与两个入口）、新增导入预览页与结果页、工作室（出站确认条数、等待蒙层泛化后行为不变）、记录页（导入后列表出现历史记录，无 UI 改动）。
- **模块**：新增 `lib/core/transfer/`（`transfer_schema.dart`、`import_parser.dart`、`import_plan.dart`、`data_transfer_service.dart`、`file_pick_service.dart`）；改动 `lib/settings/settings_page.dart`、`lib/core/export/markdown_exporter.dart`（新增 JSON 导出函数）、`lib/app/app_state.dart`（`importEntries` 批量入口，绕过成长记账）、`lib/journal/journal_repository.dart` + `lib/evidence/evidence_repository.dart` + `lib/artifacts/artifact_repository.dart`（各加 `saveAll`）、`lib/artifacts/generation_waiting_overlay.dart`（泛化）、`pubspec.yaml`（+`file_picker`）、`CHANGELOG.md`。
- **存储**：不新增 key、不改既有四个 key（`entries_v1`/`questions_v1`/`answers_v1`/`artifacts_v1`）的结构；新增只写的外部文件（导出文件、`backup/auto-*.json`）。
- **测试**：新增 `test/transfer_schema_test.dart`、`test/import_parser_test.dart`、`test/import_plan_test.dart`、`test/import_ui_test.dart`（widget）；回归 `test/markdown_export_test.dart`。
- **隐私 / BYOK**：导出文件**不含** API Key（Key 在安全存储，普通存储只有主题与 LLM 配置）；导入不产生任何网络请求；不新增遥测；日志三不记录不变。导入是纯本地写操作，仍需在预览页显著说明「Markdown 是给人读的格式，导入有信息损失；要完整迁移请用 JSON 导出」。

## 人工闸门清单

- [x] 0.1 用户逐题确认访谈结论（Q1–Q27 全部按推荐采纳；1.2.6 更新链议题按已解决处理，不在本 change 范围内）
- [x] 0.2 用户确认本 proposal 与两个 delta spec（2026-09-17）
- [x] 0.3 用户确认 design（分层、schema、解析口径、批量落盘；2026-09-17）
- [x] 0.4 用户确认 tasks，并授权「现在立刻开始执行」（2026-09-17）
- [ ] 0.5 按用户 2026-09-17 最新要求，仅运行新增功能定向测试，由主代理串行执行并确认；不再要求最终全量回归。开工基线 analyze 与原有 30/30 文件已通过，不代表最终新增测试通过。
- [ ] 0.6 主代理构建 APK 并安装雷电模拟器；安装后由用户自行验收 JSON / Markdown / 旧 v1 与分片导入导出。目前安装和用户验收均待确认。
- [ ] 0.7 版本号与 CHANGELOG 归档（目标 v1.2.6），发布流程另行确认

## 2026-09-17 用户批准修订：超限分片与验收方式

- 超过每文件 5000 条或 10 MB 时自动分片，每片仍是普通 v2 JSON，保留原有七个顶层键，不新增 schema。文件名附 `part-001-of-002`；正常单文件命名兼容旧行为。
- 一条记录及其全部追问、回答是不可拆分组；每片独立可再导入。单组连同必要文件开销超过 10 MB 时，在分享/备份前明确拒绝；无法安全生成导入前备份时禁止本次导入写入。
- 多片备份先写临时批次目录，全部完成后 rename 发布；只保留最近三个完整批次，按批清理，不拆散分片。既有 `auto-<时间戳>.json` 单文件按一个批次兼容；未完成 pending 不算有效备份。
- 用户最新指示替代旧全回归闸门：仅新增功能测试，主代理串行执行；随后安装 APK 到模拟器，用户自行验收，不由代理宣称设备验收通过。
