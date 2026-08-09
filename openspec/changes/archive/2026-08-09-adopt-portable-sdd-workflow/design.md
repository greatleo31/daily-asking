## Context

Daily Asking 已有中文 `AGENTS.md`、OpenSpec config、六个本地 OpenSpec Skills 和四项长期产品规格。全局 Agent SDD Kit 位于 `D:\projectCollection\open-spec`，其 `main` 当前内核版本为 `0.1.0`，已通过两条 Node 端到端测试和 27 项 topic eval。

## Goals / Non-Goals

**Goals:**

- 本仓库保存固定版本的协议快照和项目差异，不复制 CLI 源码。
- 让 Agent 可以确定性检查项目结构、人工门禁和任务上下文预算。
- 保持现有 Flutter/OpenSpec 开发命令与 CI 行为不变。

**Non-Goals:**

- 不为当前已归档 v0.1 规格补造 execution 记录。
- 不自动编辑已有人工规则之外的业务文档。
- 不要求 GitHub Actions 安装 agent-sdd；CI 仍直接运行 Flutter 命令。

## Decisions

### 1. 固定内核版本并保存协议快照

`.sdd/project.yaml` 记录 `kernel_version: 0.1.0`。公共协议复制到 `docs/sdd/AGENT_PROTOCOL.md`，并在文件头记录全局源目录和版本；项目规则只写 Daily Asking 差异。

备选方案是直接引用绝对路径，但 GitHub、CI 和其他开发机无法读取；复制整个工具包则会造成双重维护。

### 2. 项目配置使用 JSON 兼容 YAML

配置沿用工具包 schema 1，profile 为 `local-fullstack-flutter`，Agent 为 Codex，默认预算 2500、硬上限 4000。验证 profile 保存受审查的固定 PowerShell 参数数组，通过 PATH 或 `C:\src\flutter\bin\flutter.bat` 定位 Flutter。

### 3. 新变更必须携带 execution 映射

从本变更开始，复杂 feature/refactor 的 change 目录增加 `execution.yaml`。G0/G1 由本轮已确认产品方案作为证据；G2、G3 按视觉和发布阶段保持 pending，不能由自动检查改变。

### 4. Topic 记忆只作为可选索引

新增 Codex topic-open/topic-save skill，但本轮不预先创建大量 Topic。只有出现跨会话复用价值时才创建 `topics/index.yaml` 和对应 MEMORY，避免把规格复制成第二份记忆。

### 5. 项目验证与 CI 分层

`agent-sdd verify task` 运行 OpenSpec 严格校验与 Flutter analyze；`release` 额外运行现有 Flutter 测试和发布 APK 构建。完整日志进入 `.sdd/cache/`，紧凑摘要进入 `docs/verification/`。

## Failure Modes

- 全局工具包路径不存在：项目文档仍可独立阅读，CLI 命令报告前置条件。
- Flutter 不在 PATH 且常用路径不存在：验证失败并记录明确日志，不声明通过。
- 协议快照与内核版本漂移：升级必须通过新的 tooling change，不静默覆盖。
- 人工批准字段不完整：doctor/gate 失败，自动测试不能放行。

## Security And Privacy

- 配置不包含 API Key、签名密码或 GitHub token。
- 验证命令不拼接用户运行时输入；日志路径默认被 Git 忽略。
- 任务上下文不得默认读取记录内容、AI 响应、完整日志或历史 sessions。

## Migration And Rollback

接入仅新增 `.sdd`、协议快照、Skills 和文档引用。回滚时删除这些新增文件并还原 AGENTS/config 的入口段即可，不影响 Flutter 数据和用户记录。
