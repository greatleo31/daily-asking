## Why

Daily Asking 当前已经有 Flutter MVP、基础记录流、prompt 模板、BYOK 设置雏形和 Fake LLM 生成演示，但仍停留在原型阶段：记录管理不完整，真实模型链路未接入，发布门禁、隐私披露、导出和 CI 尚未形成可验证闭环。

本变更将第一版产品从“能演示”收束为“可安装、可验证、可开源发布”的 Android APK，并用 OpenSpec 承载生产级 PRD、设计和任务边界，防止后续实现偏离本地优先与诚实生成原则。

## Change Type

feature

## Full-Stack Mode

单机全栈。Android APK 是主要发布物；应用可本地闭环运行，真实 AI 调用由用户 BYOK 直连第三方 OpenAI-compatible 服务。Cloudflare Worker gateway 当前不进入 v0.1 主发布路径，仅作为后续可选能力保留。

## Scope

- 将 v0.1 产品目标定义为 Android APK GitHub Release。
- 补齐本地记录池的 CRUD、搜索、筛选和导出需求。
- 补齐 BYOK 直连模型调用、出站披露、错误处理和 AI 输出约束。
- 补齐 AI 追问、简历 bullet、周报、面试追问卡四类用户闭环。
- 补齐本地数据、安全存储、日志脱敏、导出不含敏感配置的要求。
- 补齐 GitHub Release 级发布门禁：CI、APK 构建、README、隐私说明、release notes 和验证证据。

## Non-Goals

- 不做云同步账号体系。
- 不做应用商店发布和商店审核材料。
- 不在客户端内置模型服务商 API Key。
- 不默认走官方 Worker gateway 或邀请码体系。
- 不默认上传整个记录池。
- 不做团队协作、多端同步、订阅付费或后台管理系统。
- 不把 AI 产物包装为已证实成果；缺少事实时必须提示补充。

## Success Criteria

- 用户可以安装 GitHub Release 附带的 Android APK，并完成首次隐私边界确认。
- 用户在无 AI 配置时仍可新增、查看、编辑、删除、搜索、筛选和导出本地记录。
- 用户配置 BYOK 后，可以在确认出站内容后生成追问、简历 bullet、周报和面试追问卡。
- 每次 AI 请求只发送用户当前选择任务所需的记录字段，并在发送前展示 provider、字段范围和调用方式。
- 生成结果明确区分可用内容、缺失信息、面试追问或风险提示，不编造数字、公司名、项目名、职责范围或影响。
- API Key 不进入日志、本地记录、导出包、迁移包或提交文件；清除配置会删除安全存储中的 Key。
- Release 前 CI 至少执行 Flutter analyze、Flutter test 和 release APK build，并在 release notes 中记录验证结果。
- README 说明安装、BYOK 配置、离线能力、隐私边界、已知限制和本地验证命令。

## What Changes

- 新增生产级 PRD 与 OpenSpec change，作为 v0.1 实现的唯一需求真相源。
- 将现有“今日记录”和“记录池”扩展为完整本地记录管理能力。
- 将产物页从 Fake LLM 演示升级为 BYOK 直连主路径，同时保留 Fake client 作为测试/演示 fallback。
- 将 prompt 模板输出约束升级为可校验的产物契约，避免非法 JSON 或幻想内容被静默保存。
- 将隐私披露、安全存储、日志脱敏和导出限制纳入明确验收标准。
- 将 GitHub Release 发布流程纳入产品需求，而不是事后手工补充。

## Capabilities

### New Capabilities

- `journal-management`: 本地记录 CRUD、搜索、筛选、导出和记录字段语义。
- `ai-generation`: BYOK 模型配置、出站确认、AI 追问和三类产物生成。
- `privacy-security`: 本地优先、最小出站、Key 安全存储、日志脱敏和敏感信息排除。
- `release-readiness`: GitHub Release 级构建、CI、发布资产、README 和验证证据。

### Modified Capabilities

- None.

## Impact

- Frontend: 影响 onboarding、今日记录、记录池、产物页、设置页、错误态和导出交互。
- Data: 影响 Entry、Artifact、本地持久化、导出格式和未来迁移兼容。
- API: 影响 OpenAI-compatible chat completions 请求/响应契约；Worker gateway 不在本次主路径内。
- Backend: 本次无自有生产后端；仅保留 gateway 占位，不作为 v0.1 成功条件。
- Testing: 需要补齐单元测试、widget 测试、LLM 错误映射测试和发布构建验证。
- Operations: 需要 GitHub Actions、release APK 构建、版本说明、签名策略说明和安全扫描。
