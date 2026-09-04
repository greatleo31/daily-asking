# evidence-query-efficiency Specification

## Purpose

保证证据、追问、回答和图谱指标在数据规模增长时仍能以有界的持久化读取次数加载，同时维持现有回答回填、开放问题和级联删除行为。

## Requirements

### Requirement: 批量证据数据加载

一次应用刷新 SHALL 对每类持久化集合执行有界次数的读取，而不是按每条 Entry 重复读取完整 Question 或 Answer 集合。

#### Scenario: 加载多条证据的开放问题
- **WHEN** 应用刷新包含多条 Entry 的证据状态
- **THEN** Question 集合 SHALL 被批量读取并按 Entry 分组
- **AND** 每条 Entry 展示的开放问题 SHALL 与现有业务规则一致

#### Scenario: 计算图谱指标
- **WHEN** 应用计算完整度、开放问题数和贡献问题数
- **THEN** 指标 SHALL 基于批量读取的数据计算
- **AND** Entry 数量增加 SHALL NOT 导致每条 Entry 再次读取完整 Question 集合

### Requirement: 回答追问保持跨实体一致性

成功回答 EvidenceQuestion 后，系统 SHALL 保存 EvidenceAnswer、更新 Question 状态，并回填对应 Entry 字段。

#### Scenario: 回答结果类追问
- **WHEN** 用户回答一条 `result` 类型的待处理问题
- **THEN** Question 状态 SHALL 为 answered
- **AND** EvidenceAnswer SHALL 保存回答内容
- **AND** 对应 Entry.result SHALL 更新为该内容

### Requirement: 删除证据级联清理

删除 Entry SHALL 同时删除其 EvidenceQuestion 以及这些问题关联的 EvidenceAnswer。

#### Scenario: 删除包含回答的证据
- **WHEN** 用户删除一条已有问题和回答的 Entry
- **THEN** Entry、关联 Question 和关联 Answer SHALL 均不可再查询
- **AND** 其他 Entry 的问题和回答 SHALL 保持不变

### Requirement: 持久化兼容

本变更 SHALL 保持现有数据集合标识及 JSON 序列化兼容。

#### Scenario: 读取变更前数据
- **WHEN** 应用启动并读取现有 `entries_v1`、`questions_v1`、`answers_v1` 和 `artifacts_v1` 数据
- **THEN** 数据 SHALL 无需迁移即可正常加载
