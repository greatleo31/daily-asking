## 1. 项目适配

- [x] 1.1 新增 `.sdd/project.yaml` 与公共协议快照，记录内核版本、预算和验证 profile。
- [x] 1.2 新增 Codex topic-open/topic-save 薄入口，并更新 AGENTS 与 OpenSpec config 的产品发现和 execution 约束。

## 2. 变更执行映射

- [x] 2.1 新增本 change 的 `execution.yaml`，记录已确认的 G0/G1 和任务上下文引用，G2/G3 保持 pending。
- [x] 2.2 运行 agent-sdd doctor、G1 gate 和 context，确认上下文低于默认预算且不加载无关文件。

## 3. 验证

- [x] 3.1 运行 `openspec validate adopt-portable-sdd-workflow --strict`、Flutter analyze 和现有测试。
- [x] 3.2 运行 `agent-sdd verify task` 生成紧凑证据，并确认缓存日志未进入 Git 状态。
