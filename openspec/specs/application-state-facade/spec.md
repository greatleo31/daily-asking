# application-state-facade Specification

## Purpose

建立稳定的应用状态门面，使 UI 通过单一边界执行跨实体操作，并在操作完成后只刷新受影响的状态快照，同时保持数据一致性。

## Requirements

### Requirement: 单一应用操作边界

UI SHALL 通过应用状态门面执行记录、追问、产物和设置操作，而不是直接操作持久化 Repository。

#### Scenario: 页面保存今日记录
- **WHEN** 今日页面提交一条记录
- **THEN** 应用状态门面 SHALL 完成保存、追问生成和状态更新
- **AND** 页面 SHALL 收到一致的今日记录与开放问题快照

### Requirement: 定向状态刷新

业务操作完成后，系统 SHALL 刷新该操作影响的状态领域，并避免重新读取与该操作无关的设置或产物数据。

#### Scenario: 修改主题
- **WHEN** 用户切换主题
- **THEN** 主题状态 SHALL 立即更新
- **AND** Entry、Question、Answer 与 Artifact 集合 SHALL NOT 被重新读取

#### Scenario: 更新产物
- **WHEN** 用户保存一份 Artifact
- **THEN** Artifact 列表 SHALL 更新
- **AND** LLM 设置和主题 SHALL NOT 被重新读取

#### Scenario: 回答追问
- **WHEN** 用户成功回答 EvidenceQuestion
- **THEN** 相关 Entry、开放问题和图谱指标 SHALL 更新
- **AND** Artifact、主题及 LLM 配置 SHALL 保持原快照

### Requirement: 完整启动加载

应用首次启动 SHALL 加载所有页面需要的初始状态，并在完成后统一标记为 loaded。

#### Scenario: 应用启动
- **WHEN** AppState 执行 bootstrap
- **THEN** 今日记录、全部证据、图谱指标、产物、LLM 配置、API Key 状态和主题 SHALL 可供页面读取
