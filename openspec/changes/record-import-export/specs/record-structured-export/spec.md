## Purpose

把本机数据完整地导出成一个**可再导入**的结构化文件，作为「换机 / 备份 / 迁移」的正规通道；人工可读的 Markdown 导出保持原样，两者并存且用途分离。同时为导入操作提供落盘前的自动快照。

## ADDED Requirements

### Requirement: 结构化导出入口

设置页 SHALL 提供「导出数据（可再导入）」入口，与「导入记录」并列于同一「数据」分组；记录页既有的「导出全部 Markdown」SHALL 保持不变，两者不互相替代。

#### Scenario: 从设置页导出
- **WHEN** 用户在设置页点击「导出数据（可再导入）」
- **THEN** 应用 SHALL 生成包含本机全部记录及其追问与回答的 JSON 文件（超限时按以下修订分片），并调起系统分享面板
- **AND** SHALL NOT 改动或移除记录页的「导出全部 Markdown」入口

#### Scenario: 空库导出
- **WHEN** 本机没有任何记录时用户执行导出
- **THEN** 应用 SHALL 生成一份合法但条目为空的文件，或明确提示「暂无可导出的记录」，SHALL NOT 生成损坏文件

### Requirement: 交换格式契约

导出文件 SHALL 是一个 JSON 对象，顶层包含 `schema`、`schemaVersion`、`exportedAt`、`appVersion`、`entries`、`questions`、`answers` 七个键；`entries`、`questions`、`answers` 的元素字段名 SHALL 与本机存储层所用的字段名逐字一致（camelCase），日期时间 SHALL 为 ISO 8601 字符串。

#### Scenario: 字段与存储层一致
- **WHEN** 检查导出文件中任一 `entries` 元素
- **THEN** 它 SHALL 包含 `id/date/task/context/action/result/blocker/tags/createdAt/updatedAt`，与存储层 `Entry` 的字段名完全一致
- **AND** 追问与回答 SHALL 通过 `entryId` / `questionId` 维持引用关系

#### Scenario: 文件名可辨识
- **WHEN** 导出成功
- **THEN** 文件名 SHALL 形如 `daily-asking-export-<yyyyMMdd-HHmm>.json`，且 SHALL NOT 与既有的 Markdown 导出文件名规则冲突

### Requirement: 导出不含凭据

导出文件 SHALL NOT 包含 API Key 或任何 LLM 配置；导出内容 SHALL 仅为本机业务数据（记录、追问、回答）。

#### Scenario: 检查导出内容
- **WHEN** 用户在设置页配置过 API Key 后执行导出
- **THEN** 导出文件中 SHALL NOT 出现该 Key、其所在存储键或等价的配置字段

### Requirement: 导出后的隐私提示

导出成功后，应用 SHALL 提示文件包含本机全部记录及其条数，并提醒谨慎分享；文件 SHALL 保存在应用私有目录并通过系统分享面板交予用户处置，SHALL NOT 写入需要存储权限的公共目录。

#### Scenario: 导出成功提示
- **WHEN** 导出完成且文件写入成功
- **THEN** 界面 SHALL 显示「文件含你的全部记录（N 条），请谨慎分享」一类提示
- **AND** 应用 SHALL NOT 在本次导出中申请存储权限

### Requirement: 导入前自动快照

在导入真正写入本机数据之前，应用 SHALL 把当前全部业务数据按同一交换格式快照到应用私有目录，并 SHALL 只保留最近 3 个完整批次（单文件算一个批次）；设置页 SHALL 显示最近一次自动快照的时间。

#### Scenario: 快照先于写入
- **WHEN** 用户确认一次导入并开始写入
- **THEN** 快照 SHALL 在执行任何写操作之前完成
- **AND** 快照内容 SHALL 与导入前本机数据等价（同样可被导入解析器读取）

#### Scenario: 只保留最近 3 份
- **WHEN** 自动快照数量超过 3 份
- **THEN** 应用 SHALL 删除最旧的快照，使保留数不超过 3

#### Scenario: 取消导入不产生快照
- **WHEN** 用户在预览页取消导入
- **THEN** 应用 SHALL NOT 写入新快照，本机数据 SHALL NOT 被改动

#### Scenario: 本期无恢复入口
- **WHEN** 用户查看设置页的数据分组
- **THEN** 界面 SHALL 只展示上次自动快照时间，SHALL NOT 提供「从备份恢复」的交互入口

### Requirement: 超限分片（2026-09-17 用户批准修订）

正常容量 SHALL 保持单文件；超过 5000 条或 10 MB 时 SHALL 输出多份普通 v2 JSON，每份 SHALL 保持原有七个顶层键且可独立导入，不新增 schema。每片 SHALL 不超过 5000 条及 UTF-8 编码 10 MB，文件名 SHALL 带 `part-001-of-002` 序号。记录及其全部追问、回答 SHALL 同片，不得拆开关联组。

#### Scenario: 6000 条记录
- **WHEN** 全库包含 6000 条且未触及大小上限
- **THEN** SHALL 分成两份独立可导入的 v2 文件，并通过同一次系统分享交付

#### Scenario: 单组过大
- **WHEN** 单条记录及其追问回答连同必要文件开销超过 10 MB
- **THEN** SHALL 在分享或发布备份前明确拒绝，SHALL NOT 输出不完整迁移文件
- **AND** 自动快照无法安全生成时 SHALL NOT 执行本次导入写入

#### Scenario: 多片快照完整发布和整批保留
- **WHEN** 自动快照需要多片
- **THEN** SHALL 先写临时批次目录，全部分片完成后 rename 发布
- **AND** SHALL 保留最近三个完整批次，按整个批次清理；未完成 pending SHALL 不算有效快照
- **AND** 既有 `auto-<时间戳>.json` SHALL 按一个完整批次兼容，同秒批次 SHALL 不覆盖
