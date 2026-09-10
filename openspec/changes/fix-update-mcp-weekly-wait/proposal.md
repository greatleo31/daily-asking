# fix-update-mcp-weekly-wait

## Why

四个相互独立的体验问题在真实使用中集中暴露：

1. **更新检查/下载在大陆网络下超时或失败**：`UpdateService.check()` 只请求单一 `UPDATE_BASE_URL` 源、固定 10s 超时、无重试也无镜像回退；GitHub Release 源在无 VPN 时大概率超时。1.2.2 正式构建已注入 GitHub Releases 更新源，大陆用户会看到「检查更新失败」。候选 Gitee 仓库 `https://gitee.com/greatleo31/daily-asking` 当前为 404，不能当作已存在镜像硬编码。
2. **雷电 Android MCP 不生效**：`server.py` 在 stdio MCP 握手前向 stdout 打印配置日志（污染 JSON-RPC 帧流），且 import 阶段实例化 `AdbDeviceManager`，设备/ADB 异常会让服务在握手前退出。MCP 工具层与模拟器健康是两件独立的事，需要分开验证与修复。
3. **周报提示词与输出不符合期望**：当前提示词要求「本周工作总结」用普通段落、并在「下周工作计划」强制包含「建议」字样；产物也不是可粘贴的列表化 Markdown，缺少专家/执行者口吻。
4. **工作室生成等待体验差**：生成是非流式单次请求，Flash 模型耗时长，三个入口按钮同时转圈且无陪伴感。

## What Changes

- **更新源多镜像化**：`UpdateService` 支持配置多个更新源，并发请求全部源、逐个源 6s 超时，取「合法清单中 versionCode 最高者」；versionCode 相同时按配置顺序取第一个源（Gitee 在前则从 Gitee 下载）。任一源返回合法清单即视为检查成功并记录 `lastCheckedAt`；全部失败才返回「所有更新源检查失败」。保留 `latestJsonUrl`（首个源）并新增 `latestJsonUrls`（每源一条）。
- **清单生成脚本发布安全化**：`generate-latest-json.sh` 支持 `--asset-url <https-url>` 显式写入 APK 直链（缺省仍为本地演示地址 `http://127.0.0.1:8090/<apk>`）与 `--out <path>`（缺省 `build/latest.json`）。发布文档补「每次发版刷新 stable 清单基址 + 关 VPN 验收」步骤。
- **Android MCP 修复**：stdout 只输出 MCP JSON-RPC 帧；设备管理器延迟到首次工具调用时构造且 `exit_on_error=False`（异常转 RuntimeError）；工具调用包 try/except，设备不可用返回可操作字符串；`get_screenshot` 失败返回字符串而非崩溃。`adbdevicemanager` 先 `adb start-server`、配置含 `:` 时先 `adb connect`、套接字失败信息包含 ADB server 与配置设备。
- **周报提示词 markdown.v4**：删除 `# Workflow & CoT` 段，改为 `# Rules` 紧凑规则；指定章节（本周完成工作/本周工作总结/下周工作计划/需协调与帮助）有实质内容时用有序列表，无内容才写「无」；「下周工作计划」改为第一人称专家/执行者口吻（`下周我将…`/`继续…`/`完成…`/`验证…`），禁止 `建议`/`可以考虑`/`你应该` 与外部顾问措辞；事实边界不变。
- **工作室等待陪伴面**：`_busy` 改为 `_generatingType`；三个按钮生成期间禁用但保留原图标、去掉按钮内 spinner；生成区上方插入一个 `_GenerationWaitingCard`（伙伴头像 + 「正在生成「<类型>」…」+ 次要文案），动画由共享 `CompanionAvatar` 提供，跟随 `AppState.companionStage`，reduce-motion 时静态展示。
- **执行顺序**：先完成并验证 update / MCP / 周报提示词三组 bug 修复与测试，再实现工作室等待面（其视觉素材若 Gemini 未能交付合规 GIF，则以代码驱动静态 PNG 循环兜底，不阻塞）。

## Non-goals

- 不把 LLM 调用改为流式（本 change 保持单次缓冲请求）；不做取消/中断生成。
- 不新增 Lottie/Rive/视频运行时依赖；不改包名/applicationId/Dart 应用名/MethodChannel 标识。
- 不创建/承诺未经验证的 Gitee 镜像本身；`https://gitee.com/greatleo31/daily-asking`（404）不得硬编码。
- 不改 `OutboundPayload.buildUserMessage`（已用中性「记录 id=」，本轮不重命名证据语义）。
- 不改简历/面试提示词结构；不做每日任务/推送/新页面/换色板。
- 不改 MCP 入口文件 `run_server.py` 及其 LDPlayer PATH 注入行为。

## Capabilities

### New Capabilities

- `update-mirror-reliability`: 多更新源并发检查、择优决策与发布安全清单生成的可观察行为。
- `android-mcp-reliability`: MCP stdio 帧纯净、设备管理器延迟初始化与设备不可用可操作反馈。
- `studio-weekly-copy-markdown`:（修改既有能力）周报提示词 markdown.v4 的列表排版与第一人称计划口吻。
- `studio-generation-waiting`: 生成期间单张陪伴等待卡与按钮禁用但图标常显的行为。

### Modified Capabilities

- （周报章节结构能力在 `studio-weekly-copy-markdown` 既有 spec 内；本 change 在其上叠加 markdown.v4 文案/排版规则并同步增量。）

## Impact

- 页面：工作室（生成区）、今日页（伙伴头像组件抽取后行为不变）、关于页（更新源多源化后 UI 无感）。
- 模块：`lib/updater/update_service.dart`、`scripts/generate-latest-json.sh`、`docs/02-版本与更新机制.md`、`lib/core/llm/prompts.dart`、`lib/artifacts/studio_page.dart`、`lib/journal/today_page.dart`、新 `lib/companion/companion_avatar.dart`、`pubspec.yaml`（仅当存在合规 GIF 素材时）、`D:/new-daily-asking/tools/android-mcp-server/{server.py,adbdevicemanager.py}`。
- 测试：`update_service_test`（多源）、`update_info_test`/`version_mapping_test`（去硬编码版本）、`prompts_test`（markdown.v4）、`today_page_companion_test`/`artifact_view_copy_test`（抽取后回归）、新增工作室等待 widget 测；MCP `tests/test_adb_device_manager.py`、`tests/test_config.py`。
- 隐私：仍 BYOK + 出站披露 + 最小字段；不新增遥测；日志三不记录不变。

## 人工闸门清单

- [x] 0.1 用户确认范围与 Non-goals（四组修复 + 顺序：update/MCP/周报 bug 先，等待面后）
- [x] 0.2 用户确认执行代理分工（DS Penguin 实现；Gemini 3.7 Flash 仅视觉资产；视觉缺失不阻塞）
- [x] 0.3 用户确认 proposal + 四个 delta specs
- [ ] 0.4 用户确认 design
- [ ] 0.5 用户确认 tasks，并点名「允许 DS Penguin apply」
- [ ] 0.6 目标测试/analyze/全量 test 绿（父会话统一验收）
- [ ] 0.7 真机/MCP 冒烟按外部前提（真实 Gitee 镜像、LDPlayer 在线、OMP 新会话）完成
