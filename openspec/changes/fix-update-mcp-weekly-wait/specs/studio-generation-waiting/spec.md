## Purpose

工作室生成期间以一张伙伴陪伴等待卡替代三个按钮各自转圈；共享伙伴头像组件尊重减少动态，行为与今日页一致。

## ADDED Requirements

### Requirement: 工作室单卡等待陪伴

工作室生成期间 SHALL 显示恰好一张生成等待卡，位于三个生成按钮上方；卡片主文案 SHALL 为 `正在生成「<类型>」…`、次文案 SHALL 为 `整理记录中，完成后会自动打开产物。`。生成期间三个生成按钮 SHALL 全部禁用（不可点），但 SHALL 保留各自原始图标（不替换为 CircularProgressIndicator），生成区 SHALL NOT 出现 CircularProgressIndicator。生成状态 SHALL 记录当前类型（而非笼统 busy），真实 LLM 请求前设置、`finally` 中清除，错误不残留卡死 UI。生成 SHALL 保持非流式：单次缓冲请求完成并落盘后才打开阅读页。

#### Scenario: 生成中 UI 状态
- **WHEN** 工作室发起一次生成且请求 pending
- **THEN** 恰好一张等待卡可见，三个按钮禁用且原图标仍可见，生成区无转圈指示

#### Scenario: 错误后恢复
- **WHEN** 一次生成以错误结束
- **THEN** 等待卡消失、按钮恢复可点，页面不残留生成中状态

### Requirement: 伙伴等待动画可复用且尊重减少动态

伙伴头像 SHALL 由共享组件提供，今日页与工作室等待卡复用同一素材与外观。今日页行为 SHALL 保持不变：成功保存触发一次低幅度舒展（约 1.00→1.04→1.00）；阶段切换为轻量淡入淡出。工作室等待模式 SHALL：动画启用时循环播放低幅度缩放 1.00→1.03→1.00（周期约 1400ms、无缝）；`MediaQuery.disableAnimations` 为真时展示当前阶段静态素材、不播放动画。等待卡读取 `AppState.companionStage`（`context.select`），显示当前本地伙伴阶段且保持离线。本能力 SHALL NOT 引入 Lottie/Rive/视频依赖；仅在存在合规 GIF（512×512、透明底、约 3.2s、12fps、无缝、无文字、≤1.5MB）时于 `pubspec.yaml` 注册该资产，否则不注册任何新资产。

#### Scenario: 抽取后今日页回归
- **WHEN** 今日页保存成功触发舒展
- **THEN** 头像区出现一次低幅度缩放动画（与抽取前行为一致）

#### Scenario: 减少动态静态展示
- **WHEN** `MediaQuery.disableAnimations` 为真且工作室生成中
- **THEN** 等待卡显示当前 `CompanionStage.assetPath` 静态图、无动画循环
