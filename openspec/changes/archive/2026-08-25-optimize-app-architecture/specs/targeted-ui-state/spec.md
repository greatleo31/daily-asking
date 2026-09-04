## Purpose

保证今日、证据、工作室和设置页面只响应其实际依赖的数据变化，减少无关页面重建，同时保持现有视觉和交互行为。

## ADDED Requirements

### Requirement: 页面最小状态订阅

每个主页面 SHALL 仅订阅其渲染与交互实际使用的状态字段。

#### Scenario: 主题设置变化
- **WHEN** 用户修改主题偏好
- **THEN** 主题相关 UI SHALL 更新
- **AND** 未依赖主题偏好值的证据和工作室内容 SHALL NOT 因完整 AppState 对象变化而重新订阅数据

#### Scenario: 产物列表变化
- **WHEN** Artifact 被创建、编辑或删除
- **THEN** 工作室页面 SHALL 更新产物列表
- **AND** 今日记录和证据图谱页面 SHALL 保持其现有状态快照

#### Scenario: 今日记录变化
- **WHEN** 今日 Entry 被新增或修改
- **THEN** 今日页和依赖该证据数据的证据页 SHALL 更新
- **AND** 设置页 SHALL NOT 因该变化重新计算其业务内容

### Requirement: 保持界面行为兼容

状态订阅优化 SHALL NOT 改变现有四 Tab 导航、页面视觉结构、空状态、主题切换和业务操作结果。

#### Scenario: 优化后导航
- **WHEN** 用户在今日、证据、工作室和设置四个 Tab 间切换
- **THEN** 页面内容和交互 SHALL 与变更前一致
- **AND** IndexedStack SHALL 继续保存各 Tab 的页面状态
