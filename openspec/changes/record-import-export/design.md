# design — record-import-export

## 0. 决策记录（2026-09-15 访谈，Q1–Q27 全部按推荐采纳）

| # | 决策 | 结论 |
| --- | --- | --- |
| Q1 | 入口 | 设置页新增「导入记录」条目，走系统文件选择器、可多选；不做「用留痕打开」的 share intent（下一版） |
| Q2 | 范围 | 只导入记录本身（含其追问与回答），不带产物、不动伙伴成长与设置 |
| Q3 | 兼容 | 尽力解析 + 明确报告；结构化格式优先 |
| Q4 | 判重 | 按 id 跳过；无 id 用「日期 + 正文指纹」；默认不覆盖 |
| Q5 | 部分失败 | 逐条独立导入，坏的收集成清单；不做整体回滚 |
| Q6 | 预览 | 先预览再确认 |
| Q7 | 整库恢复 | 不做 |
| Q8 | 结构化导出 | 本期补一个 JSON 导出，导入优先吃它；Markdown 走兜底 |
| Q9 | 选文件 | `file_picker`（唯一新增依赖，SAF 免存储权限） |
| Q10 | 缺字段补齐 | 新生成 id（`e_`/`q_`/`a_` 前缀），`date` 取文件里的日期 —— 时间戳部分被 Q14 修正 |
| Q11 | 来源标记 | 导入记录在 tags 打标 |
| Q12 | 导出入口/形态 | 设置页「数据」组成对放「导出数据」与「导入记录」；一个 JSON 装全部；记录页「导出全部 Markdown」保持原样 |
| Q13 | schema | 新 schema `daily_asking.export.v2`，字段名与存储层一致；导入逐字段校验，未知枚举值只判该条失败 |
| Q14 | 时间戳（修正 Q10） | `createdAt/updatedAt` 取原记录日期（不被钳制），列表按真实时间线插入；**导入绕过伙伴成长记账** |
| Q15 | 批次标记 | tags 加 `#导入-YYYYMMDD`；不做一键撤销 |
| Q16 | 有损导入的交代 | 汇总「成功 N 条，其中 M 条不完整解析」；预览页固定一行损失提示；不做逐字段清单 |
| Q17 | 解析口径 | 严格状态机：行首 `## <日期>` 才开新记录，只认已知 `**标签**：`，未知行忽略并计数，完整度重算 |
| Q18 | 预览粒度 | 三个数字 + 可展开清单；超过 50 条只渲染前 50 并注明总数 |
| Q19 | 文件限制 | 仅 `.json`/`.md`；≤10 MB 且 ≤5000 条；仅 UTF-8，非法序列整文件拒绝 |
| Q20 | 自动快照 | 落盘前快照，保留最近 3 份；设置页只显示「上次自动备份」一行，不做恢复 UI |
| Q21 | 验收 | 解析器单测 + 预览/结果页 widget 测 + 雷电模拟器用自制 JSON/Markdown 回灌 |
| Q22 | 旧 v1 JSON | 支持导入，缺 `createdAt/updatedAt` 回落到 `date` |
| Q23 | 隐私 | 导出成功后一句「请谨慎分享」；文件仍落 App 私有目录、走分享面板；不做公共目录 |
| Q24 | 导入中交互 | 复用并泛化等待蒙层（现在是「正在导入…」并挡返回）；不做假进度 |
| Q25 | 产物选材 | 不排除导入记录；但给出站确认补「将发送 N 条记录」（最小版） |
| Q26 | 结果页收尾 | 提供「查看导入的记录」按钮；不自动跳转 |
| Q27 | 不做清单 | 见 proposal 的 Non-goals（已并入） |

## 1. 分层与新增文件

沿用现有分层 `UI → AppState(Provider) → 领域层 → StorageService`，解析与规划全部做**纯 Dart 逻辑**（便于单测，参照 `question_engine` 的先例）。

```
lib/core/transfer/
  transfer_schema.dart      // schema 常量、v2 组装、三格式分派与解析（纯函数）
  import_parser.dart        // Markdown 状态机解析（纯函数）
  import_plan.dart          // 判重、时间戳、标签、报告模型（纯函数）
  data_transfer_service.dart// 编排：读文件 → 解析 → 规划 → 快照 → 批量落盘
  file_pick_service.dart    // file_picker 薄包装（可注入 fake，widget 测用）
lib/settings/import_preview_page.dart  // 预览页
lib/settings/import_result_page.dart   // 结果页
```

改动：`lib/settings/settings_page.dart`（插入「数据」组）、`lib/core/export/markdown_exporter.dart`（JSON 导出 + 文件名）、`lib/app/app_state.dart`（`importEntries`）、三个 Repository（`saveAll`）、`generation_waiting_overlay.dart`（泛化）、`pubspec.yaml`。

## 2. 交换格式（schema `daily_asking.export.v2`）

```json
{
  "schema": "daily_asking.export.v2",
  "schemaVersion": 2,
  "exportedAt": "2026-09-15T18:30:12.345",
  "appVersion": "1.2.6",
  "entries":   [ /* Entry.toJson() 原样 */ ],
  "questions": [ /* EvidenceQuestion.toJson() 原样 */ ],
  "answers":   [ /* EvidenceAnswer.toJson() 原样 */ ]
}
```

- **字段名与存储层逐字一致**（`Entry.toJson()` `models.dart:63-74`；`EvidenceQuestion.toJson()` `:129-137`；`EvidenceAnswer.toJson()` `:167-171`），**不引入映射层**：存储格式即交换格式。`Entry` 的必填项是 `id/date/task/createdAt/updatedAt`（`:76-87`），`context/action/result/blocker` 缺省空串、`tags` 缺省空数组。
- **关系靠 id 维持**：`EvidenceQuestion.entryId → Entry.id`，`EvidenceAnswer.questionId → EvidenceQuestion.id`。导入时若某 entry 被判重跳过，其 questions/answers **连带跳过**（否则产生孤儿）。
- 旧格式 `daily_asking.entries.export.v1`（`{schema, exportedAt, entries[]}`）**没有 questions/answers、没有独立版本字段**；读取时按 schema 串分派，缺 `createdAt/updatedAt` 回落 `date`（保留旧版宽容度），并计入报告的「旧格式」计数。
- 未知 `schema` 或 `schemaVersion > 2` → 整文件拒绝，提示「文件来自更新版本的留痕，请先升级 App」。**不做**「尽力导入未来版本」。

## 3. Markdown 兜底解析（`import_parser.dart`）

严格状态机，一次遍历：

1. 只认**行首** `## <日期>`（形如 `## 2026年8月14日`）作为新记录起点；文件头的 `# 留痕 · 全部证据导出`、`> 导出时间：…`、`> 共 N 条证据` 为前导块，忽略但计入「忽略行数」。
2. 「导出全部」里每条前的 `## 证据 N · 日期` 会先于 `## 日期` 出现：识别为**同一记录的分节标题**并吞掉，不作为新记录（这是既有瑕疵，解析侧吸收，不改导出格式）。
3. 字段行只认已知标签集合：`**任务**：`、`**完整度**：`、`- **背景**：`、`- **具体行动**：`、`- **结果 / 验证**：`、`- **难点 / 取舍**：`、`- **标签**：`；其余行归入当前字段的多行正文（正文里的 `**任务**：` 因不在行首位置或不在段首，不触发新字段——**字段一旦开始，只由下一个已知标签或标题结束**）。
4. `### 追问与回答` 之后按 `- 【<类型>】<问题> → **<状态>**：<回答>` 解析；导出时状态只会是「待补充/已答/稍后/已跳过」中的某个，**多答案已被「；」拼成一条**、`reason` 已丢失——原样接受为单条 Answer，`reason` 置空，并计入「不完整解析」。
5. 完整度不采信文件里的数字，一律由五要素现算（`models.dart:34-40`）。
6. id 全部新生成（`genId(prefix: 'e_'|'q_'|'a_')`，`core/utils.dart:11`）；`date` 取标题里的日期补本地时间 00:00；`createdAt/updatedAt` = 该 `date`（Q14）。
7. 必要的失败：标题日期无法解析、或该记录一段正文都没有 → 该条判为**非法**并记录原因（第几条、什么原因），不影响其它条。

**判重指纹**（无 id 数据）＝ `yyyy-MM-dd` + `'|'` + 规范化 `task`（trim + 连续空白折叠为单个空格 + 全角空格归一）。不引 `crypto`（它只是传递依赖），不需要哈希——指纹只在本机内存里比对。

## 4. 落盘与一致性

- 现状：四个 key 由三个 Repository 持有（`journal_repository.dart`、`evidence_repository.dart`、`artifact_repository.dart`），**每次 save 都是全量重写**（`_persist` → `JsonStore.writeList`，`storage.dart:57`），**没有批量写**。
- 本期为三个 Repository 各加 `saveAll(List<T>)`：内存合并后**只调一次 `_persist`**。导入一批 N 条 = 3 次全量写（entries/questions/answers 各一次），而不是 3N 次。
- **不是真事务**：三个 key 分别写，中途失败可能留下部分写入。兜底就是 Q20 的自动快照（写在前、失败可人工恢复），这一点在结果页文案里不夸大为「已回滚」。
- 导入**不经** `AppState` 的保存路径（`app_state.dart:268` `saveQuickToday` → `_recordCompanionGrowth` `:378`），而是新增 `AppState.importEntries(plan)`：写 Repository → 刷新内存快照 → `notifyListeners()`，**不调用伙伴成长记账**。

## 5. UI

- **设置页**：在第 3、4 组之间（`settings_page.dart:108` 的 `SizedBox` 处）插入「数据」Card + ExpansionTile，内含两个 ListTile：「导出数据（可再导入）」「导入记录」，以及 Q20 的只读「上次自动备份」说明行。
- **导入流程**：选择文件 → `GenerationWaitingOverlay`（泛化后文案「正在导入…」，挡返回）→ 预览页 → 用户确认 → 快照 + 批量落盘 → 结果页。
- **蒙层泛化**：`GenerationWaitingOverlay` 增加通用文案参数（如 `title` / `hint`），`ArtifactType` 变为可选；工作室调用点（`studio_page.dart:214-254`）改用新参数，行为与文案不变（回归由 `test/generation_waiting_overlay_test.dart` 守住）。
- **文案**（硬编码中文，与现状一致）：
  - 预览页顶部固定提示：「Markdown 是给人读的格式，导入会有信息损失；要完整迁移请用本机的「导出数据」。」
  - 预览页三数字：「将新增 X 条 · 已存在跳过 Y 条 · 无法导入 Z 条」。
  - 结果页：「已导入 X 条（其中 M 条为不完整解析，缺 id / 追问状态等，已用默认值补齐）· 跳过 Y 条 · 失败 Z 条」+「查看导入的记录」。
  - 拒绝类错误：「文件编码不是 UTF-8」「文件超过 10 MB」「文件包含超过 5000 条记录」「文件来自更新版本的留痕，请先升级 App」「无法识别的文件格式」。

## 6. 依赖与退路

- 新增 `file_picker`（Android SAF，无需存储权限；`targetSdk 36` 下仍是推荐做法）。若 pub 拉取失败或插件与 Flutter 3.44.8 不兼容，**退路是自写 `ACTION_OPEN_DOCUMENT` 的 MethodChannel**——原生已有 `update`/`export` 两个 channel 先例（`MainActivity.kt:184-209`），多写一个读文件通道即可，交换格式与解析层完全不受影响。

## 7. 测试策略（对应 Q21）

| 层 | 文件 | 覆盖 |
| --- | --- | --- |
| 解析/格式 | `test/transfer_schema_test.dart` | v2 往返（导出→导入等价）、未知 schema 拒绝、schemaVersion>2 拒绝、缺必填判该条失败、未知枚举值只判该条失败 |
| 解析 | `test/import_parser_test.dart` | 单条/全部 Markdown 往返、正文里伪造 `**任务**：` 与 `**完整度**：100%` 不被采信、`## 证据 N` 分节标题不被当成新记录、多行正文、空文件、超限、非 UTF-8、旧 v1 JSON 的 `date` 回落 |
| 规划 | `test/import_plan_test.dart` | id 判重、指纹判重、连带跳过、时间戳取原日期、`#导入-YYYYMMDD` 标记、计数汇总 |
| UI | `test/import_ui_test.dart` | 预览页三数字与超 50 条截断、结果页文案与「查看导入的记录」、拒绝类错误文案 |
| 回归 | `test/markdown_export_test.dart`、`test/generation_waiting_overlay_test.dart` | 导出格式未被改动、蒙层泛化后工作室文案不变 |

端到端（人工闸门 0.6）：在雷电模拟器上跑当前构建，先「导出数据」得到 JSON、再导入回来（应为全部跳过）；另用 App 自己导出的 Markdown 与一份手工构造的旧 v1 JSON 各导入一次。

## 8. 2026-09-17 批准修订（优先于上述单文件与回归约定）

`transfer_partition.dart` 按记录及其全部追问/回答为原子组，生成每片 ≤5000 条且 UTF-8 编码 ≤10 MB 的普通 v2 JSON。每片只有原有七个键，可独立解析，不引入新 schema；超限文件名追加 `part-001-of-002`。正常容量仍单文件。单组加文件开销仍超过 10 MB 时明确拒绝，分享/备份都不得发布残缺数据；不能生成安全快照则阻止导入。

`transfer_backup_store.dart` 支持旧式 `auto-<时间戳>.json` 和多片 `auto-<时间戳>/part-001-of-002.json`。同秒使用数字后缀避免覆盖；临时 `.pending` 目录写完全部分片后 rename 成完整批次，未完成目录不进入最近备份时间或保留计数；最近三个完整批次按批保留/删除。

新增 `test/transfer_backup_store_test.dart` 覆盖混合批次保留、同秒命名、pending 排除、6000 条落盘分片独立解析与关联完整性。2026-09-17 用户要求仅新增功能定向测试，取消最终全量回归；主代理负责串行测试、构建安装，用户负责安装后的设备验收。测试执行结果由主代理确认，本修订不预先声明通过。
