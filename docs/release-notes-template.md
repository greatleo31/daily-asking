# 发布说明模板

## Daily Asking vX.Y.Z

### 用户可见变更

- 

### 验证证据

- `openspec validate production-v1-prd --strict`: 
- `flutter analyze`: 
- `flutter test`: 
- `flutter build apk --release`: 
- APK 产物路径或 GitHub Actions 产物名称：

### 隐私模型

- 记录本地优先存储。
- 用户自带密钥，配置兼容 OpenAI 接口的大模型服务商。
- 真实 AI 调用必须先披露出站内容并由用户确认。
- API Key 不得进入日志、记录、导出包、迁移包或仓库文件。

### 签名姿态

- APK 签名类型：调试签名 / 本地发布签名 / CI 托管签名。
- 如果使用调试签名：必须标记为 GitHub 预览发布，不是应用商店级生产包。

### 已知限制

- 无云同步账号体系。
- 无应用商店发布包。
- 无生产级官方 Worker 网关路径。

### 升级说明

- 
