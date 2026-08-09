## Why

Daily Asking 已有 OpenSpec 和项目级 Agent 规则，但人工批准、原子任务上下文和验证证据仍依赖会话约定，容易在长任务中重复加载整份规格或越过产品决策。需要接入已验证的 Agent SDD Kit，让项目只保存自身配置和差异。

## What Changes

- 新增 `.sdd/project.yaml`，固定内核版本、项目 profile、中文文档、上下文预算和验证白名单。
- 引入公共 Agent 协议快照，并让 `AGENTS.md` 指向协议、项目配置和 OpenSpec 真相源。
- 增加 Codex 的 topic-open/topic-save 薄入口，默认不读取历史 sessions。
- 为后续 OpenSpec change 规定 `execution.yaml`、G0-G3 人工门禁和 task 显式上下文映射。
- 更新 `openspec/config.yaml`，要求大功能在 Specify 前通过产品发现门禁。

## Non-Goals

- 不修改 Flutter 应用、数据模型、AI 调用、Worker 网关或发布产物。
- 不把通用 SDD Kit 源码复制进本仓库。
- 不自动批准任何人工门禁，不自动创建或推送 GitHub 资源。

## Success Criteria

- `agent-sdd doctor` 能通过 Daily Asking 的项目配置与入口检查。
- 当前 change 能生成低于默认预算的原子任务上下文包。
- 项目文档明确区分全局内核、项目配置、OpenSpec 需求和 Topic 记忆。
- OpenSpec 严格校验、Flutter analyze 和现有测试继续通过。

## Change Type

tooling / docs

## Fullstack Mode

单机全栈；本变更只影响 testing 与 operations 开发流程，不影响产品运行时。

## Capabilities

### New Capabilities

- 无。本变更通过 `skip_specs: true` 明确不改变产品行为。

### Modified Capabilities

- 无。

## Impact

- testing：新增命名验证 profile 与紧凑证据约定。
- operations：新增人工门禁、最小上下文和跨 Agent 执行协议。
- frontend、data、api、backend：无运行时影响。
