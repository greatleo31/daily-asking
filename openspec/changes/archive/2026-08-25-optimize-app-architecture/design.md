## Context

参见 proposal.md 的动机。当前 AppState 同时是组合根、应用门面和缓存，并在多数写操作后执行完整 `reload()`。证据聚合按 Entry 重复读取/过滤 Question 集合，四个常驻页面又通过 `context.watch<AppState>()` 监听整个对象。存储已经按 `entries_v1/questions_v1/answers_v1/artifacts_v1` 分区，本设计不重复做 key 分区，也不改变数据格式。

## Goals / Non-Goals

**Goals:**

- 消除证据问题与指标计算中的按 Entry 查询放大。
- 保留 AppState 作为跨 Entry/Question/Answer 操作的一致性边界。
- 将完整 reload 替换为按领域刷新，并隐藏 UI 不应直接使用的 Repository。
- 将四个主页面改为最小状态选择，降低无关 Widget 重建。
- 用行为测试固定回答回填、级联删除、指标聚合和刷新边界。

**Non-Goals:**

- 不拆成四个互相协调的 FeatureController。
- 不引入 Riverpod、Bloc、get_it 或事件总线。
- 不迁移 Drift/SQLite，不改变现有持久化 key 和 JSON 结构。
- 不重构 LLM/BYOK、更新机制或视觉品牌。

## Decisions

### 1. 保留 AppState 作为 Composition Root 与 Application Facade

AppState 继续统一承载跨实体业务操作和页面快照，避免 `answerQuestion` 需要跨多个 Controller 同步。底层 Repository 字段改为私有，仅通过门面方法访问。手工 `AppState.create()` 继续负责依赖注入。

### 2. EvidenceRepository 提供批量读取能力

Repository 一次读取 Question/Answer 集合，并在内存中按 `entryId`/`questionId` 分组。EvidenceService 的指标与开放问题聚合复用同一批数据，不再为每条 Entry 调用会重新扫描集合的方法。

建议接口形态：

```dart
Future<List<EvidenceQuestion>> listQuestions();
Future<List<EvidenceAnswer>> listAnswers();
Future<Map<String, List<EvidenceQuestion>>> questionsByEntryIds(
  Iterable<String> entryIds,
);
```

具体命名可遵循现有 Repository 风格，但必须保证每次刷新每类集合只读取有界次数。

### 3. AppState 使用按领域刷新

保留 `reload()` 作为 bootstrap 的完整加载路径；写操作改为调用以下私有刷新单元的必要组合：

- entries/today/open questions/metrics
- artifacts
- settings/theme/API key

回答追问和删除 Entry 刷新证据域；Artifact 写操作只刷新 artifacts；主题写操作只更新 theme。避免无关 StorageService 读取。

### 4. 页面使用最小状态选择

今日、证据、工作室、设置页面用 `context.select<AppState, T>()` 或 Selector 订阅实际字段。需要多个相关字段时使用不可变快照/record，避免选择器每次创建不相等的新集合；AppState 对列表快照应使用不可变或稳定引用。

### 5. 测试先固定行为和读取边界

测试使用内存 Repository 或记录调用次数的 fake，覆盖：

- 批量聚合读取次数不随 Entry 数量线性增长；
- answerQuestion 的 Question/Answer/Entry 一致结果；
- deleteEntryCascade 不影响其他 Entry；
- AppState 的主题、产物和证据操作只刷新相应领域；
- 四页关键交互与导航行为保持不变；
- GPT-5.5 使用已运行的雷电模拟器和现有本地 MCP 完成真机式 UI 路径验证，不新建模拟器，不以纯 mock 代替界面验证。

## Risks / Trade-offs

- SharedPreferences 不提供多实体事务；本变更固定成功路径一致性，但不承诺进程中断时的跨 key 原子回滚。若未来要求事务，需要独立 Drift migration change。
- `context.select` 对可变 List 引用敏感；AppState 必须替换列表引用而不是原地修改，并避免 selector 中临时构造不稳定对象。
- AppState 仍是单类门面，规模会继续增长；只有后续测量证明其职责或重建成本仍不可控时，才拆分 FeatureState。
- 批量读取仍会加载每类完整 JSON 列表；本 change 解决重复读取而非大规模数据库索引。数据规模证明需要时再迁移 Drift。
