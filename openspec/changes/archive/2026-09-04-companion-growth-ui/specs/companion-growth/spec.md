## Purpose

为今日页提供一个安静、可持续、完全本地的成长伙伴，使每次有效记录都产生可理解的陪伴反馈，同时不以连续打卡惩罚用户、不阻塞记录流程，并保持伙伴状态与本地记录操作的一致性。

## ADDED Requirements

### Requirement: 有效记录驱动伙伴成长

系统 SHALL 以累计有效记录的自然日作为伙伴成长依据，每个自然日最多计入一次成长。

#### Scenario: 首次有效记录
- **WHEN** 用户成功保存一条事件描述非空的 Entry
- **THEN** 伙伴累计成长日 SHALL 增加一个该 Entry 日期对应的自然日
- **AND** 伙伴 SHALL 显示第 1 天阶段状态

#### Scenario: 同日多次记录
- **WHEN** 用户在同一自然日成功保存多条有效 Entry
- **THEN** 该自然日 SHALL 只计入一次伙伴成长
- **AND** 后续保存 SHALL NOT 重复增加累计成长日

#### Scenario: 补写历史日期
- **WHEN** 用户成功保存或补充一条尚未计入的历史日期 Entry
- **THEN** 该自然日 SHALL 按一个普通成长日计入
- **AND** 同一历史日期 SHALL NOT 被重复计入

#### Scenario: 删除已计入记录
- **WHEN** 用户删除曾经计入伙伴成长的 Entry
- **THEN** 伙伴累计成长日和已达到阶段 SHALL 保持不变
- **AND** 其他证据数据 SHALL 按既有删除规则处理

### Requirement: 阶段状态与节点

伙伴 SHALL 按累计成长日展示四个固定视觉阶段：第 1、7、14、30 天；达到更高节点后 SHALL 保持最高阶段并继续累计月度章节所需的成长信息。

#### Scenario: 四阶段切换
- **WHEN** 累计成长日分别达到 1、7、14、30
- **THEN** 伙伴 SHALL 分别展示小芽、花苞、白花、粉花加蜜蜂素材
- **AND** 第 1 天素材底部藤蔓 SHALL 保留

#### Scenario: 首次记录前
- **WHEN** 用户尚未完成任何有效记录并打开今日页
- **THEN** 系统 SHALL 展示第 1 天伙伴素材作为起始状态
- **AND** SHALL 以非惩罚性的引导文案表达等待第一条记录

#### Scenario: 成长节点提示
- **WHEN** 一次成功保存使累计成长日首次达到 1、7、14 或 30
- **THEN** 今日页 SHALL 展示一次阶段变化提示和对应语录
- **AND** 同一节点后续打开或保存 SHALL NOT 重复展示该节点提示

### Requirement: 今日页伙伴交互

今日页 SHALL 在不挤出记录输入框和保存按钮的前提下展示伙伴，并提供可关闭的轻量成长卡。

#### Scenario: 今日页首屏
- **WHEN** 用户打开今日页
- **THEN** 伙伴 SHALL 位于顶部主视觉区域
- **AND** 记录输入框与保存并沉淀操作 SHALL 仍可在首屏完成
- **AND** 页面 SHALL 显示“一起留下了 N 天”或首次记录引导

#### Scenario: 展开成长卡
- **WHEN** 用户点击伙伴
- **THEN** 系统 SHALL 展示当前阶段、累计成长日、当前语录和下一成长节点
- **AND** 关闭成长卡后用户输入内容 SHALL 保持不变

#### Scenario: 保存成功反馈
- **WHEN** Entry 已成功保存并完成状态刷新
- **THEN** 伙伴 SHALL 播放一次短暂、克制的舒展回应
- **AND** 动画完成后 SHALL 停留在持久化后的阶段状态

#### Scenario: 保存失败反馈
- **WHEN** Entry 保存失败
- **THEN** 伙伴 SHALL 保持原阶段和累计成长日
- **AND** SHALL 展示等待重试反馈
- **AND** SHALL NOT 播放成长或节点达成动画

### Requirement: 本地语录与隐私边界

伙伴语录 SHALL 使用本地固定内容和可复现规则选择，允许有限参考记录类型和标题，但 SHALL NOT 调用 LLM 或发送网络请求。

#### Scenario: 普通日语录
- **WHEN** 当日首次有效保存完成
- **THEN** 系统 SHALL 最多展示一条克制诗性语录
- **AND** 用户 SHALL 可在普通日有限换句

#### Scenario: 节点语录
- **WHEN** 用户首次达到成长节点
- **THEN** 系统 SHALL 展示节点语录
- **AND** 节点语录 SHALL NOT 提供替换操作

#### Scenario: 敏感内容隔离
- **WHEN** 系统选择伙伴语录
- **THEN** 伙伴 SHALL NOT 在语录或日志中复述人名、公司、金额、项目细节、API Key 或提示词全文

### Requirement: 伙伴资料管理

系统 SHALL 支持本地伙伴命名和独立重置，且重置 SHALL NOT 删除证据记录。

#### Scenario: 首条记录后命名
- **WHEN** 用户完成第一条有效记录
- **THEN** 系统 SHALL 提供伙伴命名入口
- **AND** 名称 SHALL 限制为 1–8 个中文或英文字符

#### Scenario: 修改名称
- **WHEN** 用户主动修改伙伴名称
- **THEN** 系统 SHALL 要求明确确认后才保存新名称

#### Scenario: 独立重置
- **WHEN** 用户在设置中确认重置伙伴
- **THEN** 伙伴名称、累计成长日、节点展示状态和章节状态 SHALL 被重置
- **AND** Entry、EvidenceQuestion、EvidenceAnswer 与 Artifact 数据 SHALL 保持不变
