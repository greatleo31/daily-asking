# local-followup-questions Specification

## Purpose
定义本地追问如何按缺失字段选择下一问、在今日页串行连续追完，以及追问卡仅保留跳过与回答，避免「稍后」与跳过语义重合。
## Requirements
### Requirement: 缺字段才生成追问

系统 SHALL 仅在对应字段为空时，为该 Entry 生成对应种类的 EvidenceQuestion；已有内容的字段 SHALL NOT 再被追问。

#### Scenario: 背景已填则不再问背景
- **WHEN** Entry 的 `context` 非空，且引擎为该 Entry 选择下一问
- **THEN** 系统 SHALL NOT 生成 `context` 种类的 EvidenceQuestion

#### Scenario: 全字段已齐且贡献已处理则无问
- **WHEN** Entry 的 `context`、`action`、`result`、`blocker` 均非空，且该 Entry 已存在 `contribution` 种类且状态为 answered 或 skip 的 EvidenceQuestion
- **THEN** 系统 SHALL NOT 再为该 Entry 生成新的 EvidenceQuestion

### Requirement: 缺字段优先级顺序

当多个可追问种类同时缺失时，系统 SHALL 按以下固定优先级选择恰好一种：`context`（背景）→ `action`（行动）→ `result`（结果）→ `blocker`（难点）→ `contribution`（个人贡献）。

#### Scenario: 多字段皆空时先问背景
- **WHEN** Entry 的 `context`、`action`、`result`、`blocker` 均为空，且该 Entry 尚无 answered/skip 阻碍
- **THEN** 生成的 EvidenceQuestion 的 kind SHALL 为 `context`

#### Scenario: 背景已填、行动与结果皆空时问行动
- **WHEN** Entry 的 `context` 非空，且 `action` 与 `result` 均为空
- **THEN** 生成的 EvidenceQuestion 的 kind SHALL 为 `action`

### Requirement: 每次决策最多一问

一次追问生成决策 SHALL 最多产生一条新的 EvidenceQuestion；SHALL NOT 同时为同一 Entry 创建多张新追问卡。

#### Scenario: 单次生成至多一条
- **WHEN** 系统为某 Entry 执行一次下一问生成
- **THEN** 新增的 pending EvidenceQuestion 数量 SHALL 至多为 1

### Requirement: 今日页答完或跳过后连续出下一问

在今日页，当用户成功回答或跳过当前展示的 EvidenceQuestion 后，系统 SHALL 立即为同一 Entry 再执行一次下一问生成；若仍有可追问 kind，SHALL 在今日页立刻展示该下一问；若无剩余可追问，SHALL NOT 再展示追问卡。

#### Scenario: 跳过背景后今日立刻出行动问
- **WHEN** 用户在今日页跳过 kind=`context` 的追问，且 `action` 仍为空
- **THEN** 今日页 SHALL 立刻展示 kind=`action` 的追问卡
- **AND** SHALL NOT 要求用户离开今日页才能看到下一问

#### Scenario: 回答行动后继续下一缺字段
- **WHEN** 用户在今日页成功回答 kind=`action` 的追问，且仍存在更高优先级之外的空字段或未处理贡献
- **THEN** 今日页 SHALL 立刻展示按优先级选出的下一问

#### Scenario: 全部处理完后不再出卡
- **WHEN** 用户答完或跳过一问后，该 Entry 已无任何可生成的下一问
- **THEN** 今日页 SHALL NOT 再展示追问卡

### Requirement: 已答或跳过的种类不再纠缠

对同一 Entry，若某 `QuestionKind` 已存在状态为 answered 或 skip 的 EvidenceQuestion，系统 SHALL NOT 再为该 kind 生成新的追问。

#### Scenario: 跳过背景后不重问背景
- **WHEN** 已存在 kind=`context` 且 status=`skip` 的 EvidenceQuestion，且引擎再次选问
- **THEN** SHALL NOT 再次生成 `context` 追问

### Requirement: 个人贡献可追问且无独立字段

系统 SHALL 允许在其它结构化字段已补齐（或更高优先级种类均已 answered/skip）时追问 `contribution`；SHALL NOT 要求独立贡献字段。贡献一经 answered 或 skip，SHALL NOT 再问。

#### Scenario: 结构化字段已齐时出贡献问
- **WHEN** Entry 的 `context`、`action`、`result`、`blocker` 均非空，且尚无 answered/skip 的 `contribution`
- **THEN** 生成的 EvidenceQuestion 的 kind SHALL 为 `contribution`

### Requirement: 追问卡不提供稍后

今日页（及复用同一追问卡的界面）展示 pending EvidenceQuestion 时，SHALL 提供「跳过」与「回答」；SHALL NOT 提供「稍后」操作入口。

#### Scenario: 用户可见操作
- **WHEN** 今日页展示一张追问卡
- **THEN** 用户 SHALL 能选择跳过或回答
- **AND** 界面 SHALL NOT 展示「稍后」

#### Scenario: 跳过语义
- **WHEN** 用户选择跳过某一 kind
- **THEN** 该 Entry 上该 kind SHALL 视为不再追问（status=`skip`）
- **AND** 系统 SHALL 按连续追问规则尝试展示下一问

