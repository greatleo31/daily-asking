# fix-update-mcp-weekly-wait — 任务清单

## 0. 人工闸门 / 执行顺序

- [x] 0.1 范围与顺序确认（update / MCP / 周报 bug 先，等待面后）
- [x] 0.2 分工确认（DS Penguin 实现；Gemini 仅视觉资产；缺 GIF 用代码驱动兜底）
- [x] 0.3 `openspec validate fix-update-mcp-weekly-wait --strict` 通过后进入代码
- [ ] 0.4 design + tasks 确认
- [ ] 0.5 目标测试/analyze/全量 test 绿
- [ ] 0.6 MCP pytest 与协议冒烟（LDPlayer/新 OMP 会话就绪时）

## 1. 更新源多镜像（bug 组 1）

- [ ] 1.1 `lib/updater/update_service.dart`：新增 `kUpdateBaseUrls` 常量；构造参数 `baseUrls` / `baseUrl` / `requestTimeout`；源规范化（`baseUrls`→`UPDATE_BASE_URLS`→`baseUrl`/`kUpdateBaseUrl`，按 `,` `;` `\n` 拆分、trim、去尾 `/`）；`isConfigured` 基于源非空
- [ ] 1.2 并发检查：每源独立请求带默认 6s 超时；解析全部合法清单；选最高 versionCode、平局取配置序靠前源；任一合法即记录 `lastCheckedAt`；全败 → `UpdateCheckFailed('所有更新源检查失败')`
- [ ] 1.3 保留 `latestJsonUrl`（首源）并新增 `latestJsonUrls`（每源一条）
- [ ] 1.4 `scripts/generate-latest-json.sh`：`--out` / `--asset-url` 支持与 `--opt value`、`--opt=value` 两种写法；`--asset-url` 缺省本地 8090 地址；`--out` 缺省 `build/latest.json` 且先 `mkdir -p`；Python 段写 URL；`grep -oP` 不可用则 Python 正则回退
- [ ] 1.5 `docs/02-版本与更新机制.md`：多源配置、`UPDATE_BASE_URLS`、发版刷新 stable 清单基址 + 关 VPN 验收步骤
- [ ] 1.6 测试：`test/update_service_test.dart` 扩展（多源规范化、首源超时次源成功、500/坏 JSON + 好源、最高 versionCode 择优、平局取首源、全败不记录、任一合法记录）；`update_info_test`/`version_mapping_test` 去 1.1.1/10101 硬编码改为公式断言
- [ ] 1.7 脚本冒烟：`--asset-url` 与不带 `--asset-url` 各跑一次并核对 JSON

## 2. Android MCP 修复（bug 组 2）

- [ ] 2.1 `server.py`：启动/配置消息移 stderr 或删除（stdout 仅 JSON-RPC）；模块级 `_device_manager=None` + `_get_device_manager()` 首次构造（`exit_on_error=False`）；各工具 try/except RuntimeError 返回 `ADB device unavailable:` 字符串；`get_screenshot` 返回 `Image | str`
- [ ] 2.2 `adbdevicemanager.py`：`exit_on_error=False` 抛 RuntimeError；枚举前 `adb start-server`；device_name 含 `:` 先 `adb connect`；套接字异常转 RuntimeError（文案含 `127.0.0.1:5037` 与配置设备）；`exit_on_error=True` 保持
- [ ] 2.3 `run_server.py` 不动；`tests/test_adb_device_manager.py` 更新（start-server/connect 断言、异常文案、RuntimeError 不退出）；`tests/test_config.py` 无改动预期
- [ ] 2.4 pytest：`.venv/Scripts/python.exe -m pytest tests/test_adb_device_manager.py tests/test_config.py` 绿
- [ ] 2.5 协议冒烟：短子进程启动 `run_server.py`，握手前 stdout 为空、人类可读信息在 stderr
- [ ] 2.6 LDPlayer 健康检查：`D:/leidian/LDPlayer9/adb.exe connect 127.0.0.1:5555`；失败则读 `ldconsole.exe` help 并重启实例后重连。仅报告，不声称 MCP 工具级通过（需新 OMP 会话）

## 3. 周报提示词 markdown.v4（bug 组 3）

- [ ] 3.1 `lib/core/llm/prompts.dart`：`artifactPromptVersion = 'markdown.v4'`；仅重写 weekly 分支：去 `# Workflow & CoT`、加 `# Rules`；四节有实质内容用有序列表（`1.`）、无支撑写 `无`；总结节 2–4 条编号结论；计划节第一人称专家口吻、禁 `建议`/`可以考虑`/`你应该`；总长 <1600 中文字符；不要求 CoT
- [ ] 3.2 `test/prompts_test.dart`：断言七标题、`有序列表`/`1.`、第一人称计划规则、`markdown.v4`；不含 `Workflow & CoT`/`必须明确包含「建议」字样`/`可以考虑`/`你应该`
- [ ] 3.3 周报提示词长度校验（<1600）在本任务内自测

## 4. 工作室等待陪伴面（功能组，2/3 组测试绿后）

- [ ] 4.1 共享组件 `lib/companion/companion_avatar.dart`（oneShot/loop 两模式、reduce-motion 静态、errorBuilder）；今日页 `_CompanionHero` 内部替换为共享组件（外观/文案/成长卡不变）
- [ ] 4.2 `lib/artifacts/studio_page.dart`：`_busy` → `_generatingType`；生成前设置、`finally` 清除；三按钮禁用但原图标常显、去 spinner；`_GenerationWaitingCard` 插入按钮上方（`正在生成「<类型>」…` / `整理记录中，完成后会自动打开产物。`）；`context.select` 读 `companionStage`；保持非流式 await/落盘/打开
- [ ] 4.3 测试 seam：StudioPage 可选生成函数参数，生产默认 `OpenAiClient().complete`；BYOK 披露流程不绕过
- [ ] 4.4 `pubspec.yaml`：仅当存在合规 `assets/companion/generating_loop.gif` 才注册；否则不改
- [ ] 4.5 widget 测：生成 pending 时恰好一张等待卡、三按钮禁用且图标仍在、无 CircularProgressIndicator（用 `AppState.debug` + `_MapStorage` 模式）；错误后恢复

## 5. 验证与收口

- [ ] 5.1 目标测试集全绿（update/update_info/version_mapping/prompts/markdown_document/artifact_view_copy/today_page_companion/llm_client）
- [ ] 5.2 `flutter analyze` 0 issue；`flutter test` 全绿
- [ ] 5.3 父会话统一验收；真实镜像/LDPlayer/新 OMP 会话等外部前提就绪前不声称生产非 VPN 与 MCP 工具级通过
