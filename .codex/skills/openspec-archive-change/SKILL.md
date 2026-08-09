---
name: openspec-archive-change
description: 在实现完成后归档一个 OpenSpec 变更。
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: 需要 openspec CLI。
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.7.0"
---

归档一个已完成的 OpenSpec 变更。

## 存储仓库选择

如用户指定存储仓库，先运行 `openspec store list --json`，再在相关命令中传入 `--store <id>`。否则使用最近的本地 `openspec/` 根目录。

## 输入

用户可以指定变更名。若未指定，从上下文推断；若不明确，运行 `openspec list --json` 并请用户选择。

## 步骤

1. 选择变更，并告知“使用变更：<name>”以及如何覆盖。
2. 可选读取归档指令：

   ```bash
   openspec instructions archive --change "<name>" --json
   ```

   该查询仅提供上下文和建议；失败时继续归档流程，不应阻塞。

3. 检查规划产物完成状态：

   ```bash
   openspec status --change "<name>" --json
   ```

   如果存在既非 `done` 也非 `skipped` 的规划产物，列出警告并请用户确认。

4. 检查 tasks 文件中是否还有 `- [ ]` 未完成任务。若有，列出数量并请用户确认。
5. 评估增量规格是否需要同步到主规格：
   - 只使用 `artifactPaths.specs.existingOutputPaths`。
   - 比较每个增量规格与对应主规格。
   - 若需要同步，先展示摘要并询问用户是否同步。
   - 若用户选择同步，运行内联规格同步，验证同步后再继续归档。

6. 执行归档：
   - 在 `planningHome.changesDir` 下创建 `archive` 目录。
   - 如果变更名没有 `YYYY-MM-DD-` 前缀，目标名使用当前日期前缀。
   - 如果目标目录已存在，失败并提示用户处理。
   - 将 `changeRoot` 移动到 archive 目录。

7. 汇报变更名、流程模式、归档路径、规格同步状态、规划产物和任务完成情况。

## 约束

- 若变更选择不明确，必须先让用户选择。
- 使用 `openspec status --json` 的规划产物图判断完成状态。
- 警告不自动阻塞归档，但必须让用户确认。
- 同步必须同步执行并验证；不能后台进行。
- 不复制运行时上下文、操作建议或规划产物规则到输出文件。
