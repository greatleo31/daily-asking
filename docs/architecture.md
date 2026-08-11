# 架构说明（Architecture）

> 晨昏证据图谱（Daily Asking）—— 本地优先的职场证据成长助手。

本文件描述项目的整体架构、模块职责与关键设计决策。适用于阅读代码、二次开发与贡献。

## 概览

应用是单页 Flutter 应用，采用「Repository / Service 抽象 + Provider 全局状态」的轻量架构。所有数据默认保存在本机（当前基于 SharedPreferences 的 JSON 序列化），AI 能力为可选的 BYOK（自带 API Key）。

```
┌────────────────────────────────────────────┐
│  UI 层：今日 / 证据 / 工作室 / 设置         │
│  lib/journal · lib/evidence · lib/artifacts│
│  lib/settings · lib/app(shell)             │
├────────────────────────────────────────────┤
│  状态层：AppState (ChangeNotifier, Provider)│
├────────────────────────────────────────────┤
│  领域层：core/models · evidence/question_..│
│  core/llm(llm_client)                      │
├────────────────────────────────────────────┤
│  持久化层：core/storage (StorageService)    │
│  settings_repository (BYOK 隔离存储)        │
└────────────────────────────────────────────┘
```

## 目录结构

| 目录 | 职责 |
| --- | --- |
| `lib/main.dart` | 应用入口：初始化 AppState 并注入 Provider |
| `lib/app/` | `AppShell`（底部导航壳）、`AppState`（全局状态）、`theme` |
| `lib/core/models.dart` | 领域模型：`Entry`、`EvidenceQuestion`、`EvidenceAnswer`、`Artifact`、枚举 |
| `lib/core/storage/` | 存储抽象 `StorageService` 与 SharedPreferences 实现 |
| `lib/core/llm/llm_client.dart` | 可选 OpenAI 兼容客户端；`OutboundPayload` 出站披露与最小字段发送 |
| `lib/core/utils.dart` | 通用工具 |
| `lib/evidence/` | 证据记录页、详情页、图谱、追问卡片、`question_engine`（本地追问规则引擎） |
| `lib/journal/` | 今日记录页 |
| `lib/artifacts/` | 工作室、产物生成与查看 |
| `lib/settings/` | 设置页、BYOK 配置页、`settings_repository` |

## 关键设计

### 1. 本地优先（Local-first）

- 所有业务数据（证据、追问、回答、产物）通过 `StorageService` 抽象持久化到本机。
- 当前实现将整个数据集序列化为 JSON 存入 SharedPreferences；`JsonStore` 与 Repository 隔离了存储细节，后续可无缝替换为 SQLite / Drift。

### 2. 本地追问规则引擎（question_engine）

- 纯业务规则，不依赖 UI，便于单元测试。
- 规则：按缺失字段确定追问方向（result → 结果/验证；context → 背景；action → 具体行动；blocker → 难点/取舍；个人贡献不清晰 → 个人贡献）。
- 每次保存后最多生成一个问题；同一条记录上被 `skip` 的问题不立即重复出现。

### 3. 可选 AI 与 BYOK + 出站披露

- AI 调用严格遵循**最小字段**原则：`OutboundPayload` 只封装用户选中的证据与产物类型。
- 每次真实调用前，UI 必须先用 `OutboundPayload.toDisclosure(...)` 展示出站披露，用户确认后才发送。
- API Key 由 `settings_repository` 写入**隔离存储**，页面不回显；日志不记录 API Key、记录正文、提示词全文。
- `llm_client` 具备 DNS 预检、有限重试与响应归一化（支持 OpenAI 多模态 content 数组与 responses 风格兜底）。

### 4. 全局状态（AppState）

- `AppState` 继承 `ChangeNotifier`，通过 `Provider` 注入到整棵树。
- 提供记录、追问、回答、产物、主题、BYOK 配置等统一入口；各页面通过 `context.read / watch` 访问。

## 数据模型概览

| 模型 | 说明 |
| --- | --- |
| `Entry` | 一条证据记录（task / context / action / result / blocker / tags 等） |
| `EvidenceQuestion` | 一条追问（kind、status：pending / answered / later / skip） |
| `EvidenceAnswer` | 对追问的回答 |
| `Artifact` / `ArtifactType` | 生成的产物（resume / weekly / interview） |

## 测试

- `test/llm_client_test.dart` — LLM 响应解析归一化测试。
- `test/widget_test.dart` — 数据序列化往返、本地追问引擎规则测试。

## 构建与质量

```bash
flutter analyze   # 0 issue
flutter test      # 全绿
flutter build apk --release
```