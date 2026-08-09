## Purpose

定义 Daily Asking GitHub Release 标准，确保应用可安装、有文档，并有可重复的验证证据支撑。

## Requirements

### Requirement: 发布构建必须可通过文档命令复现
系统 SHALL 文档化并支持可重复的依赖安装、静态检查、测试和 Android 发布 APK 构建命令。

#### Scenario: 开发者按照 README 操作
- **WHEN** 开发者在已准备 Flutter 环境的机器上执行文档化的本地验证命令
- **THEN** 命令完成，或报告可操作的环境前置条件

#### Scenario: 缺少 Flutter 环境
- **WHEN** Flutter 或 Dart CLI 不可用
- **THEN** 发布文档将 Flutter SDK 安装标识为前置条件，而不是把应用视为已验证

### Requirement: CI 必须验证发布关键检查
仓库 SHALL 在声称 GitHub Release 生产就绪前运行自动检查，覆盖静态检查、测试和 Android 发布构建。

#### Scenario: 拉取请求检查
- **WHEN** 拉取请求目标分支是生产发布分支或 main 分支
- **THEN** CI 运行 Flutter 静态检查和测试

#### Scenario: 发布构建检查
- **WHEN** 准备发布产物
- **THEN** CI 或文档化本地运行产出发布 APK 构建结果，并附到发布证据中

### Requirement: GitHub Release 必须包含必要产物和说明
系统 SHALL 在每次生产 GitHub Release 中发布 APK、版本、发布说明、验证摘要、隐私说明和已知限制。

#### Scenario: 发布说明完整
- **WHEN** 发布一个版本
- **THEN** 发布说明包含用户可见变更、验证命令/结果、隐私模型、已知限制和升级说明

#### Scenario: APK 已附加
- **WHEN** 为 Android 用户发布版本
- **THEN** 附加 Android APK 产物，或在发布说明中明确说明为什么没有 APK

### Requirement: 发布签名姿态必须明确
系统 SHALL 说明发布 APK 使用调试签名、本地发布签名还是 CI 托管签名，并 SHALL NOT 提交签名密钥。

#### Scenario: 保留调试签名
- **WHEN** 候选发布版本仍使用调试签名
- **THEN** 发布说明和 README 将其标记为 GitHub 预览发布，而不是应用商店级生产构建

#### Scenario: 需要签名密钥
- **WHEN** 发布签名使用私有凭据
- **THEN** 凭据在仓库外提供，且不提交到源码控制

### Requirement: 仓库文档必须支持开源审查
仓库 SHALL 包含足够文档，让用户和审查者理解使用方式、隐私边界、设置、验证和贡献约束。

#### Scenario: README 审查
- **WHEN** 审查者打开仓库
- **THEN** README 说明产品目的、安装、BYOK 设置、离线行为、AI 披露、验证命令和已知限制

#### Scenario: 安全审查
- **WHEN** 审查者检查安全姿态
- **THEN** 仓库文档说明密钥如何处理，以及如何报告敏感问题
