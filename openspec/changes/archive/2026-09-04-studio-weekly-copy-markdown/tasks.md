## 0. 人工闸门

- [x] 0.1 范围确认（①–④；⑤⑥不做；图片附件仅模板空段）
- [x] 0.2 Markdown：直接渲染（用户改口取消卡片分块/开片；ColorScheme；无留白）
- [x] 0.3 前端功能规划确认
- [x] 0.4 proposal + specs
- [x] 0.5 design（块级复制去标题；整篇可读复制仍含标题结构）
- [x] 0.6 tasks + 允许墨工按切片 apply
- [x] 0.7 用户总验收通过，允许 archive

## 1. 切片① 提示词去证据名

- [x] 1.1 调整 `OutboundPayload.buildUserMessage`：去除「证据名」类标签；字段+中性 id 表述；单测断言不含「证据名」
- [x] 1.2 更新 `prompts.dart` 边界/角色文案：避免「证据名」；来源称「记录/字段」中性词（简历/面试不改章节结构）
- [x] 1.3 `prompts_test` / 相关测绿；本切片可不截屏或仅抓生成前披露无关的文案抽查

## 2. 切片② 只复制正文（去标题复制）

- [x] 2.1 阅读页标题块不提供复制按钮（或等价不可拷标题）
- [x] 2.2 非标题块复制仍可用；整篇「复制可读」保留标题纯文本结构（design 已定）
- [x] 2.3 Widget/单元测 + 亮深色阅读页截屏（含标题无拷贝入口）

## 3. 切片④ 周报七段结构

- [x] 3.1 `systemPromptFor(weekly)` 改为：周报 / 本周完成工作 / 本周工作总结 / 下周工作计划 / 需协调与帮助 / 备注 / 图片 / 附件；空段规则保留；图片附件仅占位
- [x] 3.2 更新 `prompts_test` 周报章节断言；废弃旧「进行中/风险与阻塞/…」唯一结构断言
- [x] 3.3 可选：递增 `artifactPromptVersion`；analyze + test 绿

## 4. 切片③ Markdown 主题风

- [x] 4.1 样式改为直接 Markdown 渲染（取消卡片 B）
- [x] 4.2 仅用 Theme/ColorScheme 调整 `_markdownStyleSheet`（及必要间距）；不改 Palette/伙伴
- [x] 4.3 亮+深色产物阅读页截屏对照 specs

## 5. 验证与收口

- [x] 5.1 全量 `flutter analyze` 0 + test 绿
- [x] 5.2 本轮留白不验收；用户总 0.7 通过
- [x] 5.3 合入勿夹无关 dirty；发版/bump 另闸门
