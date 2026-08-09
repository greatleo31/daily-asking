---
name: topic-open
description: 在开始或恢复编码任务时，加载相关 Topic、OpenSpec 变更和最小源码上下文，避免上下文膨胀。只读，不修改文件。
---

# 打开最小任务上下文

## 目标

为下一项原子任务加载恰好足够的长期决策和规格，不做实现。

## 读取顺序

按顺序读取并在足够时停止：

1. `.sdd/project.yaml`。
2. `topics/index.yaml` 或兼容的 `topics/index.json`。
3. 匹配 Topic 的 `TOPIC.md` 与 `MEMORY.md`。
4. 当前 `openspec/changes/<change>/proposal.md`、相关增量规格、`design.md` 和目标 task。
5. `openspec/specs/` 下直接相关的长期规格。
6. execution 映射列出的源码或测试入口。
7. 只有用户要求历史或当前记忆不足时，才读取 `topics/<topic>/sessions/`。

## 输出

必须包含：Topic、选择原因、当前约束、相关决策、Requirement、设计决策、代码入口、风险、未决事项和下一步。路径和标识保持精确，不粘贴无关全文。

## 缺失行为

找不到 Topic 时明确输出“缺失 Topic”，列出尝试的路由键和最小修复动作。若 OpenSpec change 存在，可输出 SDD-only 上下文，不得编造记忆。

## 禁止

- 不编辑文件、不实现代码。
- 不加载全部 Topic、全部规格或全部 sessions。
- 不把聊天历史当作长期真相源。
