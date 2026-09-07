## Purpose

周报提示词升级到 `markdown.v4`：删除思维链段落、改为 `# Rules` 紧凑规则，指定章节输出有序列表、无支撑才写「无」，「下周工作计划」采用第一人称专家/执行者口吻且不再强制「建议」。

## ADDED Requirements

### Requirement: 周报提示词 markdown.v4

周报类型系统提示 SHALL 使用 `artifactPromptVersion = 'markdown.v4'`。提示词 SHALL NOT 包含 `# Workflow & CoT` 段，改为 `# Rules` 下紧凑规则。以下章节在有实质内容时 SHALL 输出有序列表（`1. ...`）：`本周完成工作`、`本周工作总结`、`下周工作计划`、`需协调与帮助`；仅当记录中无任何支撑内容时 SHALL 输出普通文本 `无`（且不加列表符号）。`本周工作总结` 在记录可支撑多条结论时 SHALL 输出 2–4 条编号总结结论，聚焦整体进展、突破与阶段性结论。`下周工作计划` SHALL 采用第一人称专家/执行者口吻（如 `下周我将...`/`继续...`/`完成...`/`验证...`），SHALL NOT 强制包含「建议」字样，SHALL NOT 出现 `可以考虑`、`你应该` 或外部顾问式措辞；计划内容 SHALL 仅由记录中明确的未完成事项、阻塞或下一步推导。周报提示词总长 SHALL 保持在 1600 个中文字符/码元以内，SHALL NOT 要求模型暴露思维链。

#### Scenario: 提示词含新规则无旧措辞
- **WHEN** 组装 `systemPromptFor(ArtifactType.weekly)`
- **THEN** 提示词 SHALL 含七段公司结构标题、有序列表规则（含 `1.`）、第一人称计划规则
- **AND** SHALL NOT 含 `Workflow & CoT`、`必须明确包含「建议」字样`、`可以考虑`、`你应该`

#### Scenario: 版本常量递增
- **WHEN** 读取 `artifactPromptVersion`
- **THEN** SHALL 等于 `markdown.v4`
