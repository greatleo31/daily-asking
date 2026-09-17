## Purpose

让用户能把**本机之外**的记录（上一版导出的结构化文件、旧版导出的结构化文件、以及历史的人工可读 Markdown）安全地合并进本机数据：可预览、可判重、可解释失败，且不惊扰伙伴成长与既有统计。

## ADDED Requirements

### Requirement: 导入入口与文件来源

设置页 SHALL 提供「导入记录」入口，通过系统文件选择器选取文件，SHALL 允许一次选择多个文件；本期 SHALL NOT 提供从其它应用「用留痕打开」的 intent 入口。

#### Scenario: 从设置页导入
- **WHEN** 用户在设置页点击「导入记录」
- **THEN** 应用 SHALL 打开系统文件选择器，且不需要任何存储权限
- **AND** 选择完成后 SHALL 进入预览，SHALL NOT 直接写入数据

### Requirement: 支持的文件形态与拒绝条件

应用 SHALL 只接受扩展名为 `.json` 与 `.md` 的文件；SHALL 拒绝超过 10 MB、包含超过 5000 条记录、或不是合法 UTF-8 编码的文件，并在拒绝时说明具体原因。应用 SHALL NOT 尝试猜测其它编码，SHALL NOT 支持 zip 或目录导入。

#### Scenario: 编码非法
- **WHEN** 所选文件的字节序列不是合法 UTF-8
- **THEN** 应用 SHALL 整文件拒绝并提示「文件编码不是 UTF-8」

#### Scenario: 超过上限
- **WHEN** 所选文件超过 10 MB 或解析出的记录数超过 5000 条
- **THEN** 应用 SHALL 拒绝该文件并说明是体积还是条数超限

#### Scenario: 不支持的扩展名
- **WHEN** 用户选中 `.zip` 或其它扩展名的文件
- **THEN** 应用 SHALL 提示无法识别的文件格式，SHALL NOT 尝试解析

### Requirement: 三种格式的分派与解析契约

应用 SHALL 按文件内容分派解析：结构化 v2（`daily_asking.export.v2`）、旧版结构化 v1（`daily_asking.entries.export.v1`）、以及 Markdown 兜底。未知 `schema` 或高于本版支持的 `schemaVersion` SHALL 整文件拒绝。

#### Scenario: v2 完整导入
- **WHEN** 文件为 v2 格式
- **THEN** 记录、追问与回答 SHALL 按原 id 与引用关系导入

#### Scenario: 旧版 v1 兜底
- **WHEN** 文件为 v1 格式（无 `questions`/`answers`，且记录可能缺 `createdAt/updatedAt`）
- **THEN** 应用 SHALL 导入其 `entries`，并在缺时间戳时以该记录的 `date` 回落补齐，SHALL NOT 因缺字段而整条失败
- **AND** 结果报告 SHALL 体现这是旧格式导入

#### Scenario: 未来版本拒绝
- **WHEN** 文件的 `schemaVersion` 高于本版支持
- **THEN** 应用 SHALL 拒绝整个文件并提示需先升级应用

#### Scenario: 单条字段非法不影响其它条
- **WHEN** 结构化文件中某条记录缺少必填字段，或某枚举字段值未知
- **THEN** 应用 SHALL 判定该条失败并记录原因，其余合法条 SHALL 正常导入，SHALL NOT 让解析异常中断整个导入

### Requirement: Markdown 兜底解析口径

对 Markdown 文件，应用 SHALL 采用严格解析：只有行首形如 `## <日期>` 的标题才开启一条新记录，只识别已知的字段标签行，未识别的行 SHALL 被忽略并计数；记录完整度 SHALL 由解析出的字段重新计算，SHALL NOT 采信文件里的数值。解析出的记录 SHALL 获得新生成的 id，日期取标题中的日期，`createdAt/updatedAt` 取该日期。

#### Scenario: 正文伪造字段不被采信
- **WHEN** 某条记录正文中出现形如 `**完整度**：100%` 或 `**任务**：` 的行，但它不是该记录的结构性字段行
- **THEN** 该内容 SHALL 作为正文字句保留，SHALL NOT 被当作字段值
- **AND** 记录的完整度 SHALL 仍由实际字段计算

#### Scenario: 分节标题不误开新记录
- **WHEN** 解析「导出全部」产生的 Markdown（同一记录前有 `## 证据 N · <日期>`）
- **THEN** 该分节标题 SHALL NOT 被当作一条新记录，记录的日期 SHALL 取其后的日期标题

#### Scenario: 有损信息被明确交代
- **WHEN** 一条记录的日期或关键字段无法从 Markdown 还原（例如追问的回答与状态在导出时已被合并或丢失）
- **THEN** 应用 SHALL 导入该记录并用默认值补齐缺失字段，SHALL 在结果中把它计入「不完整解析」
- **AND** 应用 SHALL NOT 谎称无损迁移

### Requirement: 判重与冲突处理

应用 SHALL 依据 id 判重：已存在同 id 的记录 SHALL 被跳过，其关联的追问与回答 SHALL 连带跳过。对没有 id 的数据，应用 SHALL 使用「日期 + 规范化任务文本」指纹判重。本期 SHALL NOT 覆盖已存在的记录。

#### Scenario: 重复导入同一文件
- **WHEN** 用户把同一份导出文件导入两次
- **THEN** 第二次 SHALL 全部被判为已存在而跳过，本机数据 SHALL NOT 发生变化

#### Scenario: 跳过时不产生孤儿
- **WHEN** 某条记录因 id 已存在被跳过
- **THEN** 属于它的追问与回答 SHALL 一并跳过，SHALL NOT 被写入本机

### Requirement: 导入时间线与伙伴成长

导入记录的 `createdAt` SHALL 取该记录自身日期，使其按真实时间线出现在记录列表中，而不是堆积为「最新」；导入 SHALL NOT 触发伙伴成长记账（不得因导入历史日期而改变伙伴成长状态）。

#### Scenario: 导入历史记录不改变成长
- **WHEN** 用户导入一批日期在很久以前的记录
- **THEN** 伙伴成长阶段 SHALL 与导入前一致
- **AND** 记录列表 SHALL 依 `createdAt` 把它们排在该在的位置

#### Scenario: 导入记录可被识别来源
- **WHEN** 一条记录由导入产生
- **THEN** 其标签中 SHALL 含形如 `#导入-YYYYMMDD` 的批次标记（YYYYMMDD 为导入当日）

### Requirement: 导入前预览

在写入之前，应用 SHALL 展示预览：将新增、已存在跳过、无法导入的条数，并 SHALL 允许查看明细；明细超过 50 条时 SHALL 只渲染前 50 条并注明总数。用户 SHALL 能取消导入，取消后本机数据不发生变化。

#### Scenario: 预览后取消
- **WHEN** 用户在预览页取消
- **THEN** 本机数据 SHALL NOT 被写入，SHALL 不产生新的自动快照

#### Scenario: 大批量预览
- **WHEN** 待导入记录超过 50 条
- **THEN** 明细 SHALL 只渲染前 50 条，并显示总条数

#### Scenario: Markdown 导入的损失告知
- **WHEN** 待导入文件是 Markdown
- **THEN** 预览页 SHALL 显著提示 Markdown 导入存在信息损失，并指引需要完整迁移时使用结构化导出

### Requirement: 导入执行与部分失败

用户确认后，应用 SHALL 逐条独立校验并在内存中合并，合法的记录 SHALL 全部写入，非法的 SHALL 被收集为带原因的清单；应用 SHALL NOT 因部分失败而整体回滚，SHALL NOT 逐条单独保存。

#### Scenario: 部分失败仍然入库
- **WHEN** 一个文件中有 20 条记录、其中 3 条字段非法
- **THEN** 其余 17 条 SHALL 被写入，3 条 SHALL 出现在失败清单中，并说明条序与原因

#### Scenario: 导入进行中不可打断
- **WHEN** 导入正在执行
- **THEN** 界面 SHALL 显示导入中的等待状态并拦截系统返回，完成后 SHALL 进入结果页

### Requirement: 导入结果与后续动作

导入完成后，应用 SHALL 展示结果：成功条数（含其中不完整解析的条数）、跳过条数、失败条数及失败原因，并提供「查看导入的记录」以跳转到记录列表；应用 SHALL NOT 自动跳转。

#### Scenario: 结果页信息完整
- **WHEN** 一次导入完成
- **THEN** 结果页 SHALL 同时给出成功/跳过/失败三个数字与失败原因清单
- **AND** 点击「查看导入的记录」SHALL 关闭结果页并切到记录列表

### Requirement: 导入不影响产物选材范围之外的行为

导入 SHALL NOT 改变记录列表、证据图谱、标签统计以外任何能力的语义；工作室的产物选材 SHALL 仍包含导入的记录（不自动排除），但出站确认 SHALL 显示「将发送 N 条记录」，使一次生成将发送的记录规模可见。

#### Scenario: 出站条数可见
- **WHEN** 用户选择若干记录发起产物生成
- **THEN** 出站确认 SHALL 显示将要发送的记录条数，条数随选择变化

#### Scenario: 导入记录可参与生成
- **WHEN** 用户选择一条由导入产生的记录发起生成
- **THEN** 应用 SHALL 正常生成，SHALL NOT 因该记录的来源而排除它

### Requirement: 分片输入与安全快照（2026-09-17 用户批准修订）

导出的每个分片 SHALL 作为普通 v2 文件独立解析，用户 SHALL 可通过现有多选入口选择全部分片；原每文件 5000 条/10 MB/UTF-8 限制保持不变。导入前本机数据超限时 SHALL 生成完整的多片快照批次；若单条记录及关联追问回答无法安全装入一片，SHALL 明确报告并阻止本次导入写入。
