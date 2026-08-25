## Why

当前应用在每次记录、追问、产物或设置变更后都会通过 `AppState.reload()` 重新加载全部数据，并在证据问题聚合中形成按 Entry 重复扫描 Question 列表的查询放大；四个常驻页面又统一监听整个 `AppState`，使无关状态变化触发不必要重建。随着证据数据增长，这会降低启动、保存与页面响应速度，并扩大后续功能迭代时的状态管理风险。

## What Changes

- 为 `EvidenceRepository` 增加一次性读取与批量分组能力，消除按 Entry 重复读取/过滤问题列表的查询放大。
- 保留 Provider、手工依赖注入及单一 `AppState` 一致性边界，不引入 Riverpod、事件总线或四套互相协调的 FeatureController。
- 将 `AppState` 收紧为应用组合根与门面：Repository 不再作为 UI 的公开数据入口，操作后按受影响领域定向刷新，避免无条件完整 `reload()`。
- 四个主页面改用 `context.select` 或等价的最小状态选择，只在页面实际依赖的数据变化时重建；保持现有视觉、导航和业务行为。
- 为 EvidenceService 编排、回答回填、级联删除、批量聚合和 AppState 刷新边界补充行为测试与规模化回归测试。
- 记录明确的性能与一致性不变量，为后续是否迁移 Drift/SQLite 提供数据依据。

### Non-goals

- 不迁移到 Riverpod、Bloc 或其他状态管理框架。
- 不在本 change 中迁移 SharedPreferences 到 Drift/SQLite。
- 不重构 LLM/BYOK、出站披露、API Key 存储或更新机制。
- 不改变 Entry、EvidenceQuestion、EvidenceAnswer、Artifact 的用户可观察业务语义。
- 不进行视觉品牌重设计或导航结构调整。

## Capabilities

### New Capabilities

- `evidence-query-efficiency`: 证据问题、回答与指标聚合支持批量读取，避免数据规模增长导致查询放大，同时保持回答回填和级联删除一致性。
- `application-state-facade`: AppState 作为 UI 唯一应用门面，提供按领域刷新的稳定状态边界，并隐藏底层 Repository。
- `targeted-ui-state`: 今日、证据、工作室、设置页面仅订阅其实际依赖的状态，避免无关全局通知触发页面重建。

### Modified Capabilities

- 无。当前 `openspec/specs/` 尚无已归档能力规范，本变更建立首批架构能力基线。

## Impact

- 主要代码：`lib/evidence/`、`lib/app/app_state.dart`、四个主页面及相关测试。
- 数据格式：保持 `entries_v1/questions_v1/answers_v1/artifacts_v1` 不变，无迁移。
- 隐私与 BYOK：不改变现有最小字段、出站披露、secure storage 与日志约束。
- 兼容性：无破坏性 API 或数据格式变更；所有现有 Flutter 测试必须继续通过。
