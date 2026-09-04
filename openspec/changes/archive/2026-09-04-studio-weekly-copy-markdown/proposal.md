## Why

工作室产物提示词仍带「证据名/证据 id」式标签，周报章节也不对齐公司常用结构；阅读页按块复制时标题与 Markdown 语法一并被拷走，渲染观感偏默认组件，扫读与粘贴进周报都费事。需要在现有工作室闭环内一次打磨生成、复制与展示，不扩新入口。

## What Changes

- 出站用户消息 / 提示词中去掉「证据名…」这类名称标签（保留最小必要字段与可回溯 id 策略按 design 收束；用户可见与模型侧均不再强调证据名文案）。
- 产物阅读页：块级复制只复制内容，不复制标题块；标题保留展示但不提供「可复制标题」体验（或标题块不出现复制入口）。
- Markdown 渲染样式贴合现有主题画风（色板/伙伴不变）；具体样式方案标 [待用户选择]，切片③单独闸门。
- 周报系统提示词输出结构改为公司格式（严格顺序）：
  - 周报
  - 本周完成工作
  - 本周工作总结
  - 下周工作计划
  - 需协调与帮助
  - 备注
  - 图片（仅空段标题占位）
  - 附件（仅空段标题占位）
- 切片 Loop：①提示词去证据名 → ②只复制正文 → ④周报结构 → ③ Markdown 主题风（样式后选）。
- 继续遵守 BYOK：真实 AI 调用前出站披露；最小字段；日志不记录 API Key、记录正文、提示词全文。

## Non-goals

- 不做多模态素材中心，不做图片/文件本地素材库（图片/附件仅周报模板空段）。
- 不做每日任务 / delay / 打卡 / 系统推送。
- 不换配色体系、不换伙伴物种/画风、不加新底栏入口、不加新页面。
- 不改今日追问引擎；不把存储换成 SQLite/FTS5。
- 不默认引入 shadcn_flutter / forui / lucide 等整套 UI 栈。

## Capabilities

### New Capabilities

- `studio-weekly-copy-markdown`: 工作室周报提示词结构、出站文案去证据名、产物阅读复制与 Markdown 主题化展示的可观察行为。

### Modified Capabilities

- （无；现有 `openspec/specs/` 无工作室产物专用能力，本 change 以 New 收录。）

## Impact

- 页面：工作室（生成/库）、产物阅读页；不改今日/记录列表主路径（用语「记录」若提示词边界句仍写「证据」则随①一并改为对模型中性表述，避免回灌「证据名」）。
- 模块：`lib/core/llm/prompts.dart`、`lib/core/llm/llm_client.dart`（OutboundPayload）、`lib/artifacts/artifact_view_page.dart`、`lib/artifacts/markdown_document.dart`（若复制语义调整）、相关 `test/prompts_test.dart` / widget 测。
- 测试：提示词章节断言更新；复制行为单测/组件测；analyze 0 + test 绿；亮深色截屏验收阅读页与周报样例。
- 隐私：仍 BYOK + 出站披露 + 最小字段；不新增云同步/遥测；日志三不记录不变。

## 人工闸门清单

- [x] 0.1 用户确认本 change 范围与 Non-goals（①–④；⑤⑥不做；图片附件仅模板空段）
- [x] 0.2 用户确认 Markdown：直接渲染（取消卡片分块）
- [x] 0.3 用户确认前端功能规划（做/不做/以后做）
- [x] 0.4 用户确认 proposal + specs
- [x] 0.5 用户确认 design
- [x] 0.6 用户确认 tasks，并点名「允许墨工 apply」
- [ ] 0.7 用户按切片看截屏/真机通过后才允许下一切片与最终 archive
