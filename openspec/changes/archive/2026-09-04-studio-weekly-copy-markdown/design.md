## Context

工作室产物已是 Markdown-first：`prompts.dart` 系统提示 + `OutboundPayload.buildUserMessage` 出站字段；阅读页 `artifact_view_page.dart` 按 `markdown_document.dart` 分块渲染，每块带复制。用户要：去证据名标签、周报改公司七段结构、复制不含标题、Markdown 贴主题（样式后选）。

## Goals / Non-Goals

- Goals：① 出站/提示去「证据名」；② 阅读页标题不可拷、只拷正文；④ 周报提示词结构对齐公司格式（含图片/附件空段）；③ MarkdownStyleSheet 主题化（[待用户选择]）。
- Non-Goals：多模态素材中心、每日任务/推送、换色板/伙伴、新页面、改追问引擎。

## Decisions

### 分层

- UI：`artifact_view_page`（复制入口、Markdown 样式）→ AppState/工作室生成门面（既有）→ `OpenAiClient` + `OutboundPayload` / `prompts` → 无存储格式变更。
- 复用：单一 AppState；不新增全局状态；提示词纯函数可测（`prompts_test`）。

### ① 去证据名

- 改 `OutboundPayload.buildUserMessage`：去掉或改写易被理解为「证据名」的标签行；保留稳定 `id`（回溯需要）时用中性前缀（如 `记录 id=` 或仅 `id=`），字段行保持 任务/背景/行动/结果/难点。
- `prompts.dart` 边界句与周报/简历/面试提示中，避免「证据名」；对模型指称来源用「记录/字段」中性表述。用户可见 App 文案若仍写「证据」且在工作室路径，能改则随本 change 最小改，不扩到无关页。
- 单测：`prompts_test` / OutboundPayload 断言不含「证据名」。

### ② 只复制正文

- `MarkdownBlockType.heading`：阅读页不渲染 `_CopyBlockButton`（或按钮 disabled 且无拷贝）。
- 非标题块：`copyText` 保持块原文或可读正文；整篇「复制可读文本」时，标题可保留为结构纯文本或按用户已选「不要标题」——**本 change 默认：块级复制去标题入口；整篇可读复制仍含标题层级纯文本以便粘贴周报结构**（若用户要整篇也去标题，切片②闸门可再收窄）。
- 测：widget/单元测标题块无复制按钮。

### ④ 周报结构

- 仅改 `systemPromptFor(ArtifactType.weekly)` 输出结构为：
  `# 周报` → `## 本周完成工作` → `## 本周工作总结` → `## 下周工作计划` → `## 需协调与帮助` → `## 备注` → `## 图片` → `## 附件`
- 空章写「无」或占位；图片/附件注明无需编造媒体，仅空段。
- 更新 `prompts_test` 旧章节断言。
- 简历/面试结构本 change **不改**（Non-goals 外扩）。

### ③ Markdown 主题风

- 样式只动 `artifact_view_page` 内 `_markdownStyleSheet`（及必要间距/卡片容器），颜色取 `ThemeData`/`ColorScheme`，**禁止新 Palette**。
- 用户改口：不要分块卡片/开片布局。阅读页 **直接 Markdown 渲染**（连续正文）；颜色仅用 Theme/ColorScheme；可轻调 StyleSheet 字号行距；禁止新 Palette、禁止块级卡片壳。
- 亮色+深色均验收。

### BYOK / 隐私

- 出站披露、最小字段、日志三不记录不变；不新增网络面。

## Risks / Trade-offs

- 旧周报产物仍是旧结构：只影响新生成；不强制迁移历史 Artifact。
- 整篇复制仍含标题 vs 块级去标题：可能两套行为，需在验收文案写清。
- 去「证据」措辞若与面试提示「逐条证据」语义冲突：面试提示可保留「逐条记录/材料」中性词，避免「证据名」专名。

## Migration Plan

- 无存储迁移。提示词版本常量 `artifactPromptVersion` 可递增（如 `markdown.v2`）便于缓存/新鲜度判断（若有依赖该常量）。

## Open Questions

- ③ Markdown：直接渲染（无卡片分块）；原选项 B 已作废
- 整篇「复制可读」是否去标题：默认不去；用户若要可在 0.5/切片②确认。


## Acceptance note

- 用户确认：切片②（若未完）及④③本轮 **留白不验收**；工笔/用户过目与最终 0.7 即可。
