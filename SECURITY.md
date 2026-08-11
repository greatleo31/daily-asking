# 安全政策（Security Policy）

## 支持的版本（Supported Versions）

| 版本 | 支持状态 |
| --- | --- |
| main 分支（最新） | ✅ 支持 |
| 旧版本 | ❌ 不支持，请升级到最新版 |

## 报告安全漏洞（Reporting a Vulnerability）

请**不要**在公开 Issue 中提交安全漏洞。

请通过以下方式私下报告：

- 在 GitHub 仓库创建 **Private vulnerability report**（仓库主页 → Security → Report a vulnerability）
- 或发送邮件至维护者（见仓库主页联系方式）

我们会在收到报告后尽快确认，通常会：

1. 72 小时内确认并回复
2. 评估影响范围与严重程度
3. 修复后发布公告，并在致谢中列出报告者（如你愿意署名）

## 本项目的安全承诺

- **本地优先**：所有记录默认保存在本机，无账号、无登录、无云同步、无遥测。
- **API Key 隔离**：BYOK 的 API Key 只保存在本机隔离存储，页面不回显，日志不记录。
- **出站披露**：真实 AI 调用前必须展示出站披露，确认后才发送，且只发送选中的最小字段。
- **最小权限**：应用仅申请运行所需的最小权限（如网络权限，仅当使用 AI 时）。

---

# Security Policy

## Supported Versions

| Version | Supported |
| --- | --- |
| main branch (latest) | ✅ Yes |
| Older releases | ❌ No — please upgrade |

## Reporting a Vulnerability

Please **do not** report security issues in public issues.

Report privately instead:

- Create a **Private vulnerability report** on the GitHub repository (repo home → Security → Report a vulnerability)
- Or email the maintainer (see contact info on the repo home page)

We will confirm as soon as possible, usually:

1. Acknowledge and reply within 72 hours
2. Assess scope and severity
3. Fix and publish an advisory, crediting the reporter (if you want to be credited)

## Security commitments

- **Local-first**: all records stay on your device. No accounts, no cloud sync, no telemetry.
- **API key isolation**: BYOK keys are stored only in isolated local storage, never echoed in the UI or logged.
- **Outbound disclosure**: real AI calls require an outbound disclosure and confirmation before sending, and only send the minimal fields you selected.
- **Least privilege**: the app requests only the permissions it needs (e.g. network, only when using AI).