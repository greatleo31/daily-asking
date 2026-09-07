## Purpose

Android MCP 服务 stdio 帧纯净、设备管理器延迟初始化与 ADB 自愈的可观察契约：服务与模拟器健康独立，互不拖垮。

## ADDED Requirements

### Requirement: MCP stdout 纯净与延迟设备初始化

MCP 服务启动（stdio 传输）在收到任何 JSON-RPC 请求前 SHALL NOT 向 stdout 写入非 JSON-RPC 帧内容；启动/配置/设备类人类可读消息 SHALL 只出现在 stderr 或被移除。设备管理器 SHALL 延迟到首个工具调用时才构造，导入 `server.py` SHALL NOT 因设备/ADB 异常而失败或退出进程。工具调用发生设备错误时，返回文本类工具 SHALL 返回以 `ADB device unavailable:` 开头、含可操作指引的字符串；`get_screenshot` 设备错误时 SHALL 返回同义错误字符串而不崩溃。MCP 工具函数 SHALL 逐调用以 try/except 包裹设备访问。

#### Scenario: 无设备在线仍可完成握手
- **WHEN** 模拟器未在线、以 stdio 方式启动 `run_server.py`
- **THEN** 服务 SHALL 正常启动并等待 JSON-RPC 输入，stdout 无任何配置/设备日志污染
- **AND** 首个工具调用返回以 `ADB device unavailable:` 开头的可操作错误字符串（或截图工具返回字符串而非异常终止）

#### Scenario: 设备在线时工具可用
- **WHEN** 模拟器在线且已连接，MCP 工具被调用
- **THEN** 各工具 SHALL 经延迟构造的设备管理器正常执行并返回结果

### Requirement: ADB 服务器与远程设备连接自愈

设备管理器 SHALL 在枚举设备前先启动 ADB server（`adb start-server`，捕获 stdout/stderr）；当配置的 `device_name` 含 `:`（远程 `host:port`）时 SHALL 先执行 `adb connect <device_name>`（捕获 stdout/stderr）再枚举设备。枚举/连接中的套接字类异常 SHALL 被转换为 RuntimeError，其文案 SHALL 提及 ADB server `127.0.0.1:5037` 与所配置设备。`exit_on_error=False` 路径 SHALL 抛 RuntimeError 而非 `sys.exit`；`exit_on_error=True` 既有行为保持不变（供既有测试/脚本使用）。

#### Scenario: 配置远程设备先连接
- **WHEN** `device_name = "127.0.0.1:5555"` 且设备管理器初始化
- **THEN** SHALL 先运行 `adb connect 127.0.0.1:5555` 再枚举设备
- **AND** 失败时 RuntimeError 文案包含 ADB server 与配置设备

#### Scenario: exit_on_error=False 不退出
- **WHEN** 设备/ADB 错误发生且 `exit_on_error=False`
- **THEN** SHALL 抛 RuntimeError（进程不退出）
