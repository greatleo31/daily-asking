---
name: openspec-sync-specs
description: 将某个变更中的增量规格同步到主规格，不归档该变更。
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: 需要 openspec CLI。
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.7.0"
---

将变更中的增量规格合并到主规格。这是智能体驱动操作：需要读取增量规格和主规格，并智能合并，而不是机械复制。

## 存储仓库选择

如用户指定存储仓库，先运行 `openspec store list --json`，再在相关命令中传入 `--store <id>`。否则使用最近的本地 `openspec/` 根目录。

## 输入

用户可以指定变更名。若未指定，从上下文推断；若不明确，运行 `openspec list --json` 并请用户选择。

## 步骤

1. 选择变更，并告知“使用变更：<name>”以及如何覆盖。
2. 读取变更上下文：

   ```bash
   openspec status --change "<name>" --json
   ```

   主规格位于 `<planningHome.root>/openspec/specs/`。

3. 只使用 `artifactPaths.specs.existingOutputPaths` 作为增量规格来源。若为空，报告没有可同步的增量规格并停止。
4. 若调用方只指定部分增量规格，只同步这些路径；不要扩大到全部列表。
5. 首次写主规格前读取 specs 指令：

   ```bash
   openspec instructions specs --change "<name>" --json
   ```

   若命令失败或返回非法 JSON，停止，不写主规格。

6. 对每个选中的增量规格：
   - 读取增量规格。
   - 读取对应主规格：`<planningHome.root>/openspec/specs/<capability>/spec.md`。
   - 按 delta 中的 ADDED、MODIFIED、REMOVED、RENAMED 语义智能合并。
   - 如果主规格不存在，创建主规格，并写入 Purpose 与 Requirements。

7. 汇报更新了哪些能力、添加/修改/删除/重命名了哪些需求。

## 合并原则

- ADDED：主规格不存在则新增，已存在则按隐式修改处理。
- MODIFIED：只应用增量中提到的变更，保留未提到的既有场景。
- REMOVED：移除整段需求。
- RENAMED：把旧需求名称改为新名称。
- 增量规格的 `## Purpose` 只在创建全新主规格时用于初始化。

## 约束

- 写入前必须读取增量规格和主规格。
- 不把增量规格文件原样复制成主规格。
- 主规格不应包含增量操作标题。
- 操作应具备幂等性，重复运行得到同样结果。
- 规划产物规则只约束写入的规格内容，不改变 CLI 行为。
