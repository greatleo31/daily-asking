# 贡献指南（Contributing Guide）

感谢你对晨昏证据图谱（Daily Asking）感兴趣！欢迎提交 Issue、改进文档、修复 Bug 或添加新功能。

[English version below](#english)

## 开发流程

1. **Fork 本仓库**并克隆到本地。
2. 基于 `main` 创建功能分支：`git checkout -b feat/your-feature` 或 `fix/your-fix`。
3. 做出修改，并确保：
   - `flutter analyze` 无 error；
   - `flutter test` 全部通过；
   - 提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/)（如 `feat:`, `fix:`, `docs:`, `refactor:`）。
4. Push 分支并创建 Pull Request，描述你的改动与验证结果。

## 代码规范

- 保持**本地优先**原则：不引入强制联网、账号体系或遥测。
- AI 调用必须遵循 BYOK 与出站披露：只发送选中的最小字段，日志不记录 API Key / 正文 / 提示词全文。
- 新增功能请附带测试（`test/`）。
- 遵循 `analysis_options.yaml` 中的 lint 规则。

## 提交信息示例

```
feat(evidence): 支持按标签筛选证据
fix(llm): 处理 OpenAI 多模态 content 响应
docs: 补充安全说明
```

## 行为准则

- 友善、尊重、建设性。
- 讨论代码与方案，而非人身。
- 维护者有权关闭与项目无关或不合规的 Issue / PR。

---

<a id="english"></a>

# Contributing Guide

Thanks for your interest in Daily Asking! Issues, documentation improvements, bug fixes, and new features are all welcome.

## Workflow

1. **Fork** this repository and clone it locally.
2. Create a feature branch from `main`: `git checkout -b feat/your-feature` or `fix/your-fix`.
3. Make your changes and ensure:
   - `flutter analyze` reports no errors;
   - `flutter test` passes;
   - commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (e.g. `feat:`, `fix:`, `docs:`, `refactor:`).
4. Push the branch and open a Pull Request describing your changes and verification.

## Code guidelines

- Keep the **local-first** principle: no mandatory network, accounts, or telemetry.
- AI calls must follow BYOK and outbound disclosure: send only the minimal selected fields; never log API keys, entry content, or full prompts.
- Add tests for new features (`test/`).
- Follow the lint rules in `analysis_options.yaml`.

## Commit message examples

```
feat(evidence): filter evidence by tag
fix(llm): handle OpenAI multimodal content responses
docs: add security notes
```

## Code of conduct

- Be kind, respectful, and constructive.
- Discuss code and ideas, not people.
- Maintainers may close off-topic or non-compliant issues/PRs.