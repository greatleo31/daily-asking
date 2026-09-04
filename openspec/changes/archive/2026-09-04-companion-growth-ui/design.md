## Context

本变更接入现有 Flutter 单页应用的“今日”页面。当前 `AppState` 是 Provider 注入的组合根和状态门面，证据写入通过 `saveQuickToday`、`updateEntry` 等方法完成，持久化通过 `StorageService`/`JsonStore` 写入 SharedPreferences JSON。伙伴是新的本地状态域，不能由 Widget 私自维护第二份数据真相。

设计稿和四张完整伙伴素材已确认：`assets/companion/day_01.png`、`day_07.png`、`day_14.png`、`day_30.png`。第一版采用整图状态切换，不要求拆分身体、植物和蜜蜂图层；第 1 天底部藤蔓是有意设计。

## Goals / Non-Goals

**Goals:**

- 为伙伴成长建立可持久化、可测试、可迁移的本地状态边界。
- 让有效记录成功后才更新伙伴，并保证同一自然日去重、删除不回退。
- 让今日页在首屏同时保留伙伴、记录输入框和保存操作。
- 用低频淡入淡出/轻微舒展表达反馈，支持减少动画偏好。
- 将四张 PNG 注册为 Flutter 资源，并在亮色、深色主题下可读。
- 保持语录离线、本地、可复现，不新增任何 AI 出站路径。

**Non-Goals:**

- 不建立独立伙伴中心、完整月度章节页面或素材分层编辑器。
- 不引入新依赖、联网服务、账号、遥测或 LLM 调用。
- 不修改证据、追问、产物和设置的既有业务语义。

## Decisions

### 1. 以累计日期集合保证单日去重和删除不回退

新增 `CompanionProfile`，持久化一个 `countedDates` 的本地日期字符串集合，而不是只保存一个计数器。日期统一使用设备本地日历的 `yyyy-MM-dd`，加入集合前去重。这样同日多 Entry 不会重复成长，删除 Entry 也不会使历史成长回退；旧数据没有该 key 时从空资料开始，不需要迁移既有 Entry 数据。

建议 JSON 形状：

```json
{
  "name": null,
  "countedDates": ["2026-08-26", "2026-08-27"],
  "celebratedMilestones": [1, 7],
  "lastQuoteDate": "2026-08-27",
  "quoteRerolls": {"2026-08-27": 1}
}
```

存储 key 固定为 `companion_v1`，读写沿用 `JsonStore.readMap/writeMap`。缺少字段按默认值兼容，未知字段忽略。

### 2. 将成长规则放在纯 Dart 领域服务

新增 `CompanionService` 或同等纯逻辑对象，负责：

- 规范化本地日期并向 `countedDates` 增加日期。
- 由累计日期数计算 `CompanionStage`：0–6 显示 day_01，7–13 显示 day_07，14–29 显示 day_14，30+ 显示 day_30。
- 判断节点首次达成、下一节点和月度章节编号。
- 选择本地固定语录，规则输入只包含阶段、日期、Entry 类型/标题等允许字段。

领域服务不依赖 Flutter UI、Provider、SharedPreferences 或网络客户端，直接用 Dart 测试。

### 3. Repository + AppState 单一状态门面

新增伙伴 Repository，封装 `companion_v1` 的读写。`AppState` 在 `create` 注入 Repository，在 `reload` 中加载伙伴资料并暴露只读快照。

证据写操作成功后再更新伙伴：

- `saveQuickToday`：Entry 和追问保存成功后，记录 `entry.date` 到伙伴资料，再刷新证据和伙伴域。
- `updateEntry`：更新成功后将 Entry 日期幂等加入伙伴资料，支持补写。
- `deleteEntry`：只刷新证据域，不从伙伴日期集合删除日期。
- `resetCompanion`：只清理伙伴资料并通知，不触碰证据、追问、回答和产物。

伙伴写入和证据写入的异常必须向 UI 传递；不能先播放成长动画再假设持久化成功。

### 4. 今日页使用最小订阅

`TodayPage` 只选择伙伴展示所需快照、今日记录和保存状态。伙伴展示组件接收不可变快照和当前素材路径，不直接读 Repository。点击伙伴展示成长卡；卡片关闭不重建或清空输入控制器。

首屏布局按设计文档执行：伙伴在顶部，输入区和保存按钮保持可见，今日列表在后。对于尚未记录的用户，使用 day_01 素材和待开始文案，不显示虚假的成长天数。

### 5. 整图资源和动画

在 `pubspec.yaml` 注册四张明确路径的 PNG。UI 使用统一的展示盒处理图片尺寸和基线，避免生图画布差异改变布局。

状态切换使用 AnimatedSwitcher 或等价的轻量淡入淡出，并叠加一次短时、低幅度的舒展缩放。动画只在 AppState 已确认保存成功后触发；`MediaQuery.disableAnimations` 或项目已有减少动画策略启用时直接展示最终图。

### 6. 分阶段验证与人工闸门

本次实现不连续自动推进。每一轮大循环固定为：

1. 人工验收当前设计/实现阶段结果。
2. Gemini-3.6 按本变更 tasks 实现一个完整切片。
3. Sol 审查代码和 spec 对齐情况，提出必须修复项。
4. DS/sol 通过本地 Android MCP 连接雷电，执行 UI smoke 并返回证据。
5. 主线程对照 spec、审查结果和 MCP 证据判断是否符合。
6. 不符合则建立下一轮修复清单并再次停在人工作用闸门前；符合才交付用户。

## Risks / Trade-offs

- 计数日期集合比单一整数占用更多本地空间，但首年只有几百个短日期字符串，换来的是真实的去重、删除不回退和可审计性。
- 当前素材原始来源为带棋盘格的 JPG，已在工作区生成 RGBA PNG；需要在 Android MCP 实机上同时检查浅色和深色背景，确认没有棋盘格残留或浅色花朵边缘损失。
- 伙伴资料与 Entry 分开存储，能保持删除不回退，但删除后伙伴阶段可能高于当前可见 Entry 数据，这是明确的历史成就语义。
- 语录固定规则比模型生成单调，但可以离线、可测试、可控隐私，符合第一版低打扰目标。
- 首次记录前使用 day_01 是产品起始状态；“尚未开始”文案需要在第一轮 UI 人工验收时确认语气和位置。
