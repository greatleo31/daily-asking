# Daily Asking SDD 使用说明

本项目使用 Agent SDD Kit `0.1.0`。全局内核源为 `D:\projectCollection\open-spec`，项目固定来源提交记录在 `.sdd/project.yaml`。

## 真相源边界

- 公共执行原则：`docs/sdd/AGENT_PROTOCOL.md`。
- 项目差异与验证命令：`.sdd/project.yaml`。
- 长期产品行为：`openspec/specs/**/spec.md`。
- 当前变更：`openspec/changes/<change>/`。
- 跨会话高价值记忆：`topics/*/MEMORY.md`，仅在确有复用价值时创建。
- 代码、测试、APK 和日志：验证证据，不是需求真相源。

## 原子任务命令

```powershell
node D:\projectCollection\open-spec\bin\agent-sdd.mjs doctor --target .
node D:\projectCollection\open-spec\bin\agent-sdd.mjs gate --target . --change <change> --gate G1
node D:\projectCollection\open-spec\bin\agent-sdd.mjs context --target . --change <change> --task <task>
node D:\projectCollection\open-spec\bin\agent-sdd.mjs verify --target . --change <change> --profile task
```

复杂 feature/refactor 的每个 change 都必须包含 `execution.yaml`。G0-G3 只能在用户明确批准后更新；自动化验证通过不能替代人工批准。

## 升级内核

升级 `kernel_version` 时单独创建 tooling change，比较公共协议、schema 和 CLI 行为，再更新协议快照。不得直接从全局目录覆盖项目规则。
