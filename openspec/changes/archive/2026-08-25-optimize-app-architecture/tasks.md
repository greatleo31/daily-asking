## 1. DeepSeek 后端与应用状态实现

- [x] 1.1 为 EvidenceRepository 增加 Question/Answer 全量读取与按 Entry/Question 批量分组能力，保持现有存储 key 和 JSON 兼容
- [x] 1.2 重构 EvidenceService 的开放问题与 metrics 聚合，保证每次刷新每类集合有界读取，消除按 Entry 重复扫描
- [x] 1.3 固定 answerQuestion 的 Question/Answer/Entry 回填行为与 deleteEntryCascade 的关联清理边界
- [x] 1.4 将 AppState 的 Repository 依赖收紧为私有实现细节，保留 AppState 作为组合根和应用门面
- [x] 1.5 将 AppState 写操作改为证据域、产物域、设置域的定向刷新组合，bootstrap 继续使用完整 reload

## 2. Gemini 前端状态与界面性能优化

- [x] 2.1 将 TodayPage 改为最小状态订阅，保持今日记录、反馈、提交和追问交互不变
- [x] 2.2 将 EvidencePage 及其主要子视图改为最小状态订阅，保持筛选、搜索、详情和图谱行为不变
- [x] 2.3 将 StudioPage 改为仅订阅产物、AI 就绪状态及实际使用字段，保持生成与编辑流程不变
- [x] 2.4 将 SettingsPage/AppShell 的状态订阅收紧到主题、设置和更新所需字段，保持四 Tab IndexedStack、主题切换和更新交互不变
- [x] 2.5 检查 selector 值的引用稳定性，不在 selector 中构造每次均不相等的临时可变集合

## 3. GPT-5.5 测试与模拟器验证

- [x] 3.1 增加 EvidenceRepository 批量读取和调用次数测试，证明读取次数不随 Entry 数量线性放大
- [x] 3.2 增加 EvidenceService 回答回填、级联删除、多 Entry 隔离和 metrics 行为测试
- [x] 3.3 增加 AppState 定向刷新测试，证明主题、产物和证据操作不读取无关领域
- [x] 3.4 运行 flutter analyze 与 flutter test，并修复测试代码中的真实问题，不修改生产契约或放宽断言
- [x] 3.5 使用已运行的雷电模拟器和现有本地 MCP 安装/启动应用，验证今日记录、Tab 切换、证据查看、工作室和设置主题五条真实 UI 路径；不得新建模拟器或用纯 mock 替代界面验证
  验证证据：已通过 `D:/new-daily-asking/tools/android-mcp-server/run_server.py` 启动本地 `android` MCP，`config.yaml` 锁定 `127.0.0.1:5555`；MCP 握手暴露 `get_packages`、`execute_adb_shell_command`、`get_uilayout`、`get_screenshot`、`get_package_action_intents`。前台应用为 `com.dailyasking.daily_asking/.MainActivity`，真实调用 `get_uilayout`、`get_screenshot` 并通过 ADB shell 完成今日、证据、工作室、设置 Tab 切换；设置主题由“切换深色”切换为“切换亮色”后恢复为“切换深色”。

## 4. 主模型集成审查与返工

- [x] 4.1 审查后端是否真正消除查询放大、保持数据兼容且没有引入第二套状态架构
- [x] 4.2 审查前端是否保持现有视觉与交互，并验证状态选择没有陈旧数据或过度重建
- [x] 4.3 审查测试与雷电模拟器证据；不合格项按文件归属重新分派给 DeepSeek、Gemini 或 GPT-5.5 修复
- [x] 4.4 完成所有返工后重新运行 analyze、test、雷电模拟器 UI smoke，并更新 OpenSpec 任务状态
  验证证据：`C:\src\flutter\bin\flutter.bat analyze` 输出 `No issues found!`；`flutter test` 输出 `All tests passed!`（69 项）。雷电 UI smoke 已通过本地 `android` MCP 完成，详见 3.5。
