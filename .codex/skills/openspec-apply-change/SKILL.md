---
name: openspec-apply-change
description: 实施一个 OpenSpec 变更中的任务。用户要求开始实现、继续实现或按任务推进时使用。
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: 需要 openspec CLI。
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.7.0"
---

实施一个 OpenSpec 变更中的任务。

## 存储仓库选择

如果用户指定存储仓库，或当前工作位于已注册的独立 OpenSpec 存储仓库中，先运行：

```bash
openspec store list --json
```

随后在读取或写入规格/变更的命令中传入 `--store <id>`。未指定存储仓库时，命令作用于最近的本地 `openspec/` 根目录。

## 输入

用户可以指定变更名。若未指定，应先从上下文推断；若无法明确推断，必须列出可用变更并请用户选择。

## 步骤

1. 选择变更，并告知“使用变更：<name>”以及如何覆盖选择。
2. 运行：

   ```bash
   openspec status --change "<name>" --json
   ```

   读取流程模式、规划根目录、变更目录、编辑范围，以及任务所在规划产物。

3. 运行：

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   读取上下文文件列表、任务进度、任务状态、动态指令、项目上下文和操作建议。

4. 如果状态为 `blocked`，说明缺少规划产物，报告阻塞并提示继续创建缺失规划产物；如果状态为 `all_done`，说明全部任务完成；否则继续实施。
5. 读取 apply 指令返回的所有上下文文件。`spec-driven` 流程模式通常包含 proposal、specs、design、tasks。
6. 展示当前流程模式、任务完成进度、剩余任务和 CLI 动态指令。
7. 按未完成任务逐项实施：说明当前任务、做最小聚焦改动、运行匹配验证，并将 `tasks.md` 中对应任务从 `- [ ]` 改为 `- [x]`。
8. 遇到任务不清楚、设计问题、错误阻塞或用户中断时暂停并报告。
9. 完成或暂停时汇报本轮完成任务、总体进度和下一步。

## 约束

- 不跳过上下文文件；实施前必须读取。
- 不把上下文或操作建议当成任务完成证据。
- 不复制运行时上下文或操作建议到实现文件，除非用户明确要求。
- 使用 CLI 返回的路径和状态，不硬编码规划产物文件名。
- 保持改动最小、聚焦、可验证。
- 保留 CLI 控制的 blocked、ready、all_done 行为和完成标准。
