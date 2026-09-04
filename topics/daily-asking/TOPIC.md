# Topic: daily-asking

> 晨昏证据图谱（Daily Asking）—— 本地优先的职场证据成长助手。

## Scope

- 单页 Flutter 应用：记录职场小事 -> 本地追问引擎补充证据 -> 证据图谱检索 -> 工作室生成产物。
- 模块：core（模型/存储/LLM）、journal（今日）、evidence（记录+追问引擎）、artifacts（工作室）、settings（BYOK）、updater（更新）、app（壳）。
- 非范围：云同步、账号系统、多人协作、遥测。

## Working Agreements

- 开发流程：OpenSpec（openspec/changes + openspec/specs）管理变更与长期规范；本 topic 记忆跨会话决策。
- 新变更从 `/opsx-propose` 开始，实施用 `/opsx-apply`，完成后 `/opsx-archive` 并更新本记忆。
- 质量门槛：flutter analyze 0 issue、flutter test 全绿。

## Key Files

- docs/architecture.md — 架构总览（分层图、模块职责、关键设计）
- lib/core/models.dart — 领域模型（Entry/EvidenceQuestion/EvidenceAnswer/Artifact）
- lib/evidence/question_engine* — 本地追问规则引擎（纯逻辑，可单测）
- lib/core/llm/llm_client.dart — BYOK OpenAI 兼容客户端（最小字段 + 出站披露）
- lib/settings/secure_key_store.dart — API Key 加密存储（flutter_secure_storage）
- lib/core/version.dart — 版本单一来源
