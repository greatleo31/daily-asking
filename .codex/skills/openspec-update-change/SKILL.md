---
name: openspec-update-change
description: 更新一个现有 OpenSpec 变更的规划产物，并保持 proposal、design、specs、tasks 之间一致。只改规划文档，不改代码。
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: 需要 openspec CLI。
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.7.0"
---

修订一个现有 OpenSpec 变更的规划产物，并保持它们彼此一致。此技能绝不编辑实现代码。

## 存储仓库选择

如用户指定存储仓库，先运行 `openspec store list --json`，再在相关命令中传入 `--store <id>`。否则使用最近的本地 `openspec/` 根目录。

## 输入

用户可以指定变更名。若未指定，从上下文推断；若不明确，运行 `openspec list --json`，展示最近修改的 3-4 个变更供用户选择。

## 步骤

1. 选择变更，并告知“使用变更：<name>”以及如何覆盖。
2. 读取变更状态：

   ```bash
   openspec status --change "<name>" --json
   ```

   使用返回的 schemaName、artifacts、planningHome、changeRoot、artifactPaths 和 actionContext。不要硬编码规划产物名称或路径。

3. 理解用户请求：
   - 若用户要求具体修订，以该修订为起点。
   - 若用户只说“更新”或“保持一致”，按一致性审查处理。

4. 读取被请求影响的规划产物以及其他已存在规划产物。
5. 应用请求变更，并检查其他规划产物是否因此出现矛盾、缺口或重复。
6. 只修改 `existingOutputPaths` 中已经存在的具体文件，不创建缺失规划产物，也不向 glob 规划产物下发明新文件。
7. 重大重写前先读取对应规划产物的 instructions。
8. 输出修订了哪些规划产物、哪些内容被延后，以及推荐的下一步。

## 约束

- 只改规划产物，绝不改实现代码。
- 如果规划变化意味着代码也要变，停止并提示使用 `$openspec-apply-change`。
- 使用 `openspec status` 返回的规划产物 id 和具体路径。
- 不写入 glob resolvedOutputPath。
- 不推进构建边界；缺失规划产物交给继续创建流程。
- 如果请求改变变更意图而不是细化现有变更，建议新建变更。
