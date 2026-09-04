## 0. 人工闸门

- [x] 0.1 人工验收 PR base、伙伴素材、pubspec 资源注册、proposal/spec/design 与第一轮路线
- [x] 0.2 每轮 Gemini 实现、Sol 审查和 DS MCP 结果完成后，由用户验收阶段性效果，再允许下一轮修复

## 1. 伙伴领域规则与本地状态

- [x] 1.1 为 CompanionProfile、阶段映射、自然日去重、补写、删除不回退、重置和语录选择编写失败测试
- [x] 1.2 实现纯 Dart CompanionProfile、CompanionStage 与 CompanionService，覆盖 0/1/7/14/30+ 天边界
- [x] 1.3 为 companion_v1 编写 Repository 读写、缺省字段兼容和未知字段忽略测试
- [x] 1.4 实现 CompanionRepository，沿用 JsonStore，不引入新依赖或第二套存储机制

## 2. AppState 组合根接入

- [x] 2.1 为 AppState bootstrap、有效保存、同日重复保存、历史补写、删除和独立重置编写状态边界测试
- [x] 2.2 将 CompanionRepository 注入 AppState，加载并暴露伙伴只读快照
- [x] 2.3 将 saveQuickToday 和 updateEntry 的成功路径接入伙伴日期记录，保证失败路径不改变伙伴状态
- [x] 2.4 增加命名、重置、成长节点已展示状态和普通语录换句的 AppState 门面操作

## 3. 今日页伙伴体验

- [x] 3.1 为首次记录前、四阶段素材、成长卡、节点提示、保存失败和减少动画行为编写 Widget/行为测试
- [x] 3.2 在 TodayPage 顶部增加伙伴主视觉，确保输入框和保存按钮仍保持首屏可用
- [x] 3.3 使用 assets/companion/day_01.png、day_07.png、day_14.png、day_30.png 实现整图状态切换、底部基线统一和轻量动画
- [x] 3.4 实现点击伙伴展开成长卡、首条记录后命名、普通日换句和节点语录不可替换
- [x] 3.5 实现保存成功后的舒展回应、失败等待重试、昼夜低频状态和无记录引导文案

## 4. Gemini 实现与 Sol 审查

- [x] 4.1 将第 1–3 组任务交给 Gemini-3.6 子线程实现，严格限定在本变更 spec 和 design 的范围内
- [x] 4.2 由 Sol 子线程审查 Gemini diff，逐项对照 companion-growth spec，重点检查状态一致性、持久化、隐私、首屏布局和动画边界
- [x] 4.3 修复 Sol 标记的 Critical/Important 问题，禁止通过放宽断言或删除需求来消除问题

## 5. 验证与循环交付

- [x] 5.1 运行伙伴定向测试、flutter analyze 和 flutter test，记录完整输出
- [x] 5.2 通过本地 android-mcp-server 连接 127.0.0.1:5555，执行今日页首屏、保存成功、四阶段展示、成长卡、主题切换和保存失败路径 smoke
- [x] 5.3 由主线程汇总 Gemini 实现、Sol 审查、Flutter 验证和 DS MCP 证据，对照 spec 生成符合/不符合清单
- [x] 5.4 若存在不符合项，形成下一轮修复任务并回到人工闸门 0.2；若全部符合，更新 Draft PR、OpenSpec 任务状态并交付
  验证说明：APK 构建于 `D:/new-daily-asking/daily_asking/build/app/outputs/flutter-apk/app-debug.apk`；DS 通过本地 Android MCP 完成真实设备 smoke。阶段 7/14/30 未伪造数据，由自动化边界测试覆盖。详见 `docs/verification/companion-growth-ui-smoke.md`。
