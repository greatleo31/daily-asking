# 伙伴养成 UI 实机验证报告

## 构建与设备

- APK 类型：Flutter debug APK
- APK 路径：`D:/new-daily-asking/daily_asking/build/app/outputs/flutter-apk/app-debug.apk`
- 构建输出位于 D 盘项目目录，未使用 C 盘作为 APK 输出目录。
- 设备：LDPlayer，ADB/MCP 目标 `127.0.0.1:5555`
- Android：9
- 屏幕：720 × 1280，rotation 0
- 应用：`com.dailyasking.daily_asking/.MainActivity`
- MCP：本地 `D:/new-daily-asking/tools/android-mcp-server/run_server.py`

## MCP 证据

DS 通过本地 Android MCP stdio 完成握手，并实际调用：

- `get_packages`
- `get_package_action_intents`
- `execute_adb_shell_command`
- `get_uilayout`
- `get_screenshot`

设备操作没有使用桌面 Chrome DevTools MCP，也没有用纯 ADB 替代 MCP。

## 场景结果

| 场景 | 结果 | 证据 |
|---|---|---|
| 启动应用 | PASS | `am start -W` 成功，前台保持 `MainActivity`，无崩溃/ANR |
| 今日页初始首屏 | PASS | 伙伴、小芽引导语、输入框、保存按钮均在首屏；输入框可聚焦 |
| 保存一条记录 | PASS | 保存后显示第 1 天伙伴、今日证据数量；既有本地追问弹层仍出现，跳过后记录保留 |
| 成长卡 | PASS | 显示伙伴、阶段、天数、节点语录、下一节点和命名入口；关闭后今日页状态保留 |
| 四 Tab | PASS | 今日、证据、工作室、设置均可切换，内容和底部导航保持可用 |
| 亮色主题 | PASS | 伙伴、文字、按钮和导航可辨识 |
| 深色主题 | PASS | 伙伴、文字、按钮和导航可辨识；切换后恢复亮色 |
| 安全保存校验 | PASS | 空输入提示清晰，证据数量不增加，应用无崩溃 |
| 第 7/14/30 天素材 | 自动化覆盖 | 未伪造成长数据；设备只验证当前第 1 天素材，边界由定向测试覆盖 |

## 截图

DS 通过 MCP 保存了以下截图：

```text
D:/new-daily-asking/tools/android-mcp-server/smoke_evidence/scenario2_initial.png
D:/new-daily-asking/tools/android-mcp-server/smoke_evidence/scenario3_question_sheet.png
D:/new-daily-asking/tools/android-mcp-server/smoke_evidence/scenario3_after_save.png
D:/new-daily-asking/tools/android-mcp-server/smoke_evidence/scenario4_growth_card.png
D:/new-daily-asking/tools/android-mcp-server/smoke_evidence/scenario6_settings_light.png
D:/new-daily-asking/tools/android-mcp-server/smoke_evidence/scenario6_settings_dark.png
D:/new-daily-asking/tools/android-mcp-server/smoke_evidence/scenario6_today_dark.png
D:/new-daily-asking/tools/android-mcp-server/smoke_evidence/scenario7_empty_save_validation.png
D:/new-daily-asking/tools/android-mcp-server/smoke_evidence/day_01_asset.png
```

## 限制与备注

- DS 输入英文句子时，ADB 文本注入吞掉了一个 `s`，确认是测试工具的 `%s` 转义问题，不是 App 文本处理问题。
- 第 7、14、30 天没有伪造伙伴累计天数，因此真实设备只覆盖第 1 天；阶段边界由 `CompanionService` 定向测试覆盖。
- 没有执行伙伴重置，避免破坏设备中已有的本地数据；设置页入口和二次确认已通过 UI 检查及测试覆盖。
- 没有完整填写追问回答路径，已确认追问弹层出现且跳过后记录保留。
- 最终设备状态：亮色主题、今日 Tab、第 1 天伙伴、1 条新增证据。

## 对照结论

在已执行的设备场景中，伙伴功能符合当前 OpenSpec。尚未声称未执行的阶段边界、完整回答流程和重启持久化场景通过。用户已人工验收当前截图和阶段性效果，允许收尾。
