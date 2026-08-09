# Agent SDD 公共执行协议

Daily Asking 固定快照版本：`0.1.0`。来源：`D:/projectCollection/open-spec@eeefcfc755e2e8a82b4b1941c30feeea11192a27`。

本协议是不同编码智能体共享的稳定内核。项目自身约束写入 `.sdd/project.yaml`，业务需求写入 OpenSpec，不得把业务规则复制回本协议。

## 阶段

1. 产品发现：明确目标用户、问题、价值、非目标和成功指标。
2. Specify：用 proposal 与 specs 定义可观察行为。
3. Plan：用 design 与 tasks 定义边界、接口、失败模式和原子任务。
4. Implement：一次只执行一个 task，先读取该 task 的最小上下文包。
5. Validate：每个 task 运行对应检查，保存紧凑证据。
6. Sync / Archive：规格与代码一致后同步长期规格并归档变更。

## 人工门禁

- G0：产品定位。
- G1：PRD、流程与技术方案。
- G2：视觉原型，仅 UI 变更要求。
- G3：发布候选与人工验收。

Agent 不得根据测试、构建或自身判断写入人工批准。只有用户明确表达批准后，才可把批准人、时间和证据写入 `execution.yaml`。

## 原子任务流程

1. 运行 `agent-sdd doctor --target <project>`。
2. 运行 `agent-sdd gate --target <project> --change <change> --gate <gate>`。
3. 运行 `agent-sdd context --target <project> --change <change> --task <task>`。
4. 只读取上下文包列出的文件与直接依赖。
5. 实施一个 task，并运行 `agent-sdd verify` 的对应 profile。
6. 将完成证据写入 tasks 和验证摘要；不保存聊天流水。

## 上下文纪律

- 默认只包含项目约束、当前 task、关联 Requirement、设计决策、代码引用、风险和下一步。
- 不默认读取 README、全部 specs、全部源码、完整日志或 `topics/*/sessions/`。
- 缺少显式任务映射时停止，不通过整库搜索猜测。
- 超过硬预算时必须先缩小上下文；确有必要时提供可审计的超限原因。

## 安全边界

- 不记录或提交密钥、令牌、密码和签名凭据。
- 不运行 `.sdd/project.yaml` 白名单之外的验证命令。
- 不把代码、测试、构建结果当作规格替代品。
- 不在没有证据时宣称完成、生产就绪或人工验收通过。

## 记忆边界

- 长期产品和技术规则进入 OpenSpec 主规格或 ADR。
- Topic MEMORY 只保存跨会话仍会改变后续动作的决策、代码入口、已纠正错误和未决事项。
- session 只用于追溯，默认不进入任务上下文。
