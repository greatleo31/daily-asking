---
name: openspec-propose
description: 一步创建新的 OpenSpec 变更及其 proposal、design、specs、tasks。用户快速描述要构建的能力并希望进入可实现状态时使用。
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: 需要 openspec CLI。
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.7.0"
---

创建新的 OpenSpec 变更，并按流程模式生成所有必要规划产物。

默认 `spec-driven` 流程模式通常包含：

- `proposal.md`：说明做什么和为什么做。
- `specs/<capability>/spec.md`：说明系统必须满足的行为，是增量规格，不是主规格。
- `design.md`：说明如何实现。
- `tasks.md`：说明实施步骤。

准备实现时，运行 `$openspec-apply-change`。

## 存储仓库选择

如果用户指定存储仓库，先运行 `openspec store list --json` 找到 id，并在相关 OpenSpec 命令中传入 `--store <id>`。否则使用最近的本地 `openspec/` 根目录。

## 输入

用户应提供 kebab-case 变更名，或描述想构建/修复的内容。若输入不清楚，必须先问清楚要做什么，不要直接创建变更。

## 步骤

1. 如果没有清晰输入，询问用户要构建或修复什么，并根据描述派生 kebab-case 名称。
2. 创建变更：

   ```bash
   openspec new change "<name>"
   ```

3. 查询规划产物构建顺序：

   ```bash
   openspec status --change "<name>" --json
   ```

   使用返回的 applyRequires、artifacts、planningHome、changeRoot、artifactPaths 和 actionContext，不要假设路径。

4. 按依赖顺序创建 apply 阶段传递依赖的所有规划产物。对每个 ready 规划产物：
   - 运行 `openspec instructions <artifact-id> --change "<name>" --json`。
   - 读取已完成依赖文件。
   - 按 template 和 instruction 写入 resolvedOutputPath。
   - 将 context 和 rules 作为约束，不要原样复制进规划产物。
   - 每创建一个规划产物后重新运行 status。

5. 若规划产物被流程模式标记为 skipped，视为满足；不要强行创建。
6. 若规划产物需要澄清，先问用户；否则优先做合理决策保持推进。
7. 最后运行 `openspec status --change "<name>"` 并汇报变更位置、创建的规划产物和下一步。

## 约束

- 创建 apply 阶段传递依赖的全部规划产物，而不只是 applyRequires 中列出的 id。
- 写新规划产物前必须重读依赖文件。
- 如果变更名已存在，询问用户是继续现有变更还是新建。
- 不把 context、rules 或 project_context 原样写进规划产物。
- 每个规划产物写完后确认文件存在。
