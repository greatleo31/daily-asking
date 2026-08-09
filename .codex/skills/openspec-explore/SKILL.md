---
name: openspec-explore
description: 进入探索模式，用于讨论想法、调查问题和澄清需求。用户想在变更前或变更中先思考时使用。
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: 需要 openspec CLI。
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.7.0"
---

进入探索模式。该模式用于思考、调查和澄清，不用于实现功能。

## 核心原则

- 探索模式可以读取文件、搜索代码、分析架构和创建 OpenSpec 规划产物。
- 探索模式不得写实现代码或实现功能。
- 如果用户要求实现，应提醒用户先退出探索模式并创建/应用变更。
- 这是思考姿态，不是固定流程；不要求固定输出。

## 存储仓库选择

如用户指定存储仓库，先运行 `openspec store list --json`，再在相关命令中传入 `--store <id>`。否则使用最近的本地 `openspec/` 根目录。

## 开始时的上下文检查

通常先运行：

```bash
openspec list --json
```

然后读取解析出的根目录下的 `openspec/config.yaml` 或 `config.yml`，了解项目背景、约束和规划产物规则。

## 可做的事

- 澄清问题空间，提出自然产生的问题。
- 挑战假设，重新框定问题。
- 阅读代码库，绘制相关架构和集成点。
- 比较多个方案，列出权衡。
- 用 ASCII 图辅助说明系统结构、状态机、数据流或依赖关系。
- 识别风险、未知项、spike 或后续调查任务。

## 当已有变更时

如果用户提到某个变更，或检测到相关变更：

1. 运行：

   ```bash
   openspec status --change "<name>" --json
   ```

2. 使用返回的 `changeRoot`、`artifactPaths` 和 `actionContext`。
3. 读取相关规划产物。
4. 在讨论中自然引用已有 proposal、design、specs 和 tasks。
5. 当形成新决策时，询问用户是否要捕获到对应规划产物：
   - 新需求：`specs/<capability>/spec.md`
   - 需求变化：`specs/<capability>/spec.md`
   - 设计决策：`design.md`
   - 范围变化：`proposal.md`
   - 新工作：`tasks.md`

## 约束

- 不实现功能，不写应用代码。
- 不假装理解；不清楚就继续调查。
- 不强行套固定流程。
- 不自动捕获决策；先询问用户。
- 讨论必须尽量基于真实代码和 OpenSpec 规划产物。
