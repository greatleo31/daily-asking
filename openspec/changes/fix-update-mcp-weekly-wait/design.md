## Context

`UpdateService.check()` 目前只请求单源 `{kUpdateBaseUrl}/latest.json?...`、固定 10s 超时、无重试/镜像回退；`generate-latest-json.sh` 把 APK URL 固定写成本地 `http://127.0.0.1:8090/<apk>`；MCP `server.py` 握手前向 stdout 打印日志且 import 期实例化设备管理器；周报提示词要求段落式总结与「建议」字样；工作室生成共用 `_busy` 导致三按钮同时转圈。本 change 的目标与边界：先修 update / MCP / 周报 bug 并测试通过，再做工作室等待面；视觉资产由 Gemini 3.7 Flash 负责，DS Penguin 只做代码侧，缺合规 GIF 则以代码驱动静态 PNG 循环兜底。

## Goals / Non-Goals

- Goals：多镜像并发择优更新；MCP stdio 纯净 + 延迟设备初始化 + ADB 自愈；周报 markdown.v4（有序列表、第一人称计划）；工作室单卡陪伴等待；脚本发布安全；文档同步。
- Non-Goals：LLM 流式化/取消；Lottie/Rive/视频依赖；新建未经验证的 Gitee 镜像或硬编码 404 地址；改包名/applicationId/MethodChannel；改 `OutboundPayload.buildUserMessage`；改简历/面试提示词结构。

## Decisions

### 更新域

- `UpdateService` 构造签名扩展为 `UpdateService(prefs, {client, List<String>? baseUrls, String? baseUrl, Duration? requestTimeout})`；来源规范化顺序：`baseUrls` 参数 → `UPDATE_BASE_URLS` 环境/构建常量 → `baseUrl` 参数 → `kUpdateBaseUrl`。字符串源按 `,` `;` `\n` 拆分、trim、去空、去尾部 `/`。默认单源超时 6s。
- 保留 `latestJsonUrl`（首个源，兼容旧 UI/测试），新增 `latestJsonUrls`。
- 检查逻辑：并发发起全部源请求，各自独立 6s 超时；逐源解析合法清单；有合法清单者记录 `lastCheckedAt`；版本决策 = 所有合法清单中 versionCode 最大者，平局取配置序靠前源（需记录源顺序而非 Future 完成序）。全部失败 → `UpdateCheckFailed('所有更新源检查失败')`；未配置 → 失败「更新服务未配置」，不发请求。
- 生产发布：`UPDATE_BASE_URLS` 指向稳定 latest.json 基址目录（非版本化 release tag 目录），首源为大陆可达 HTTPS 镜像，GitHub 为后备；manifest `url` 指向同一镜像 APK。404 的 Gitee 候选不硬编码；无真实镜像凭据时完成代码/脚本/本地冒烟，不声称生产非 VPN 已解决。

### 脚本

- `generate-latest-json.sh` 参数：`<apk> [changelog] [--mandatory] [--out <path>] [--asset-url <url>]`。手工解析 `--out`/`--asset-url` 的 `--opt value` 与 `--opt=value` 两种写法（bash 兼容，避免依赖 getopt）。`--asset-url` 缺省本地地址不变。`--out` 缺省 `build/latest.json`；先 `mkdir -p` 父目录。Python 段接收 url 参数写入 JSON。版本提取若 `grep -oP` 不可用，在同一脚本内换 Python 正则回退。

### MCP

- `server.py`：配置加载/启动消息全部移 stderr 或删除；模块级 `_device_manager: AdbDeviceManager | None = None`；`_get_device_manager()` 首次调用构造 `AdbDeviceManager(device_name, exit_on_error=False)`；每工具内部 `try/except RuntimeError` 返回 `ADB device unavailable: ...` 字符串；`get_screenshot` 返回类型改 `Image | str`。
- `adbdevicemanager.py`：保留 `exit_on_error=True` 语义；`False` 路径抛 RuntimeError。新增静态/实例流程：`_start_adb_server()`（`adb start-server` 捕获输出）；device_name 含 `:` 时 `_connect_device(device_name)`（`adb connect` 捕获输出）。`get_available_devices()` 由静态方法改为先做上面两步再 `AdbClient().devices()`，异常转 RuntimeError（文案含 ADB server 127.0.0.1:5037 与配置设备）。`AdbClient().device()` 仍惰性选择。
- `run_server.py` 保持 OMP 入口与 LDPlayer PATH 注入不动。
- 更新 `tests/test_adb_device_manager.py`：为 start-server/connect 步骤加 mock 断言与异常路径测试；`test_exit_on_error_true` 保持。`tests/test_config.py` 纯逻辑复制不受影响。集成测试文件不在执行范围，若跑全量需同步（仅当其失败时）。

### 周报提示词

- `artifactPromptVersion = 'markdown.v4'`。
- 周报分支重写：保留 Role/Objectives/Background/`$_commonBoundary`；删除 `# Workflow & CoT` 段；新增 `# Rules`：四节有实质内容用有序列表、无支撑写 `无`；总结节 2–4 条编号结论；计划节第一人称（`下周我将…`/`继续…`/`完成…`/`验证…`），禁 `建议`/`可以考虑`/`你应该` 与顾问措辞；事实边界（仅未完成事项/阻塞/下一步）。
- 各节描述句重写为列表/无规则语义。长度 <1600 中文字符；不要求 CoT 输出。
- `prompts_test` 更新断言。不动 `buildUserMessage`。

### 工作室等待面

- `_busy: bool` → `_generatingType: ArtifactType?`。`_generate(type)`：设置 `_generatingType = type` 于 `OpenAiClient().complete()` 前，`try { … } finally { if (mounted) setState(() => _generatingType = null); }`，保证错误也清除。其余（落盘、延迟高亮、打开阅读页）保持。
- `_GenButton` 去 busy/spinner：加 `enabled`（或 onTap 由父级判空）。原图标常显。三按钮 `onTap: _generatingType == null ? () => _generate(t) : null`。
- 等待卡 `_GenerationWaitingCard(type, ...)` 插在「生成产物」标题与按钮之间：`正在生成「<label>」…` + `整理记录中，完成后会自动打开产物。`；内含共享 `CompanionAvatar` 循环模式。
- 测试 seam：StudioPage 加可选 `generate` 函数参数（类型 = 生产默认 `OpenAiClient().complete` 的同构签名），生产路径不绕过 BYOK 披露（披露确认仍在 `_generate` 内、seam 只替换网络调用本身）。

### 共享伙伴头像

- 新文件 `lib/companion/companion_avatar.dart`：`CompanionAvatar` 将今日 `_CompanionHero` 的图像部分（Image.asset + ScaleTransition + AnimatedSwitcher + errorBuilder）抽取；素材尺寸/布局保持 112×112 由调用方容器控制。
- API：`CompanionAvatar({stage, mode, stretchTrigger?, size?})`；`mode = oneShot | loop`。
  - oneShot：`stretchTrigger` 递增触发一次 1.0→1.04→1.0（520ms）；阶段切换 AnimatedSwitcher 淡入淡出；reduce-motion 直接静态当前图（`didUpdateWidget` 直接置 1.0）。
  - loop：`AnimationController.repeat` 周期 1400ms，Tween 1.00→1.03→1.00（`reverse:false` + 周期内往返 或 TweenSequence）；reduce-motion 静态。
- 今日页 `_CompanionHero` 内部替换为 `CompanionAvatar(stage: widget.stage, mode: oneShot, stretchTrigger: widget.stretchTrigger)` 于同一容器内；不改变外层布局/文案/成长卡。今日页测试（`today_page_companion_test.dart` 找首个 ScaleTransition）保持兼容：共享组件仍产出 ScaleTransition 于今日页子树。测试断言若因组件层级变化需微调（保证仍断言动画值变化）则可调。
- 若 Gemini 交付合规 `assets/companion/generating_loop.gif` → 注册 pubspec + loop 模式优先用 GIF（Image.asset 支持 gif 动画，reduce-motion 下仍静态当前 stage 图）；未交付 → 不注册资产，loop 用静态 PNG 缩放循环，逻辑不变。

## Risks / Trade-offs

- 多源并发 = 每源最多 6s、总时长受最长源限制（并发不叠加）；若 UI 需要更早反馈可后续加「任一成功即提前返回」优化——本 change 用全量并发+择优，保证平局顺序语义简单可测。
- versionCode 平局取首源：首源必须可靠（大陆镜像在前）；GitHub 兜底仅当首源不可达。
- `_generatingType` seam 只换网络函数：披露对话框在 seam 之外，BYOK 不被绕过。
- 抽取头像改变今日页内部层级，需回归今日页 companion 测试；测试断言尽量用「行为」（缩放值离开 1.0）而非组件内部类名。

## Migration Plan

- 无存储迁移。`artifactPromptVersion` 递增（markdown.v3→v4）；旧产物文件不迁移。
- `latest.json` 协议字段不变（只增不改删）；新增多源仅客户端侧。
- MCP 配置格式不变；stdout 消息迁移 stderr，客户端日志行为不变。

## Open Questions

- 真实大陆可达 HTTPS 镜像基址：执行期若没有现成 Gitee/静态托管凭据，则不阻塞代码，最终报告注明「生产非 VPN 验收待真实镜像」。
- Gemini GIF 资产：执行期可能未交付，已备代码驱动静态循环兜底路径。
