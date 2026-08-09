# 发布签名姿态

Daily Asking v0.1 的发布目标是 GitHub 预览 APK，不是应用商店级发布。

## 当前状态

当前 Android 发布构建仍使用 Gradle 调试签名：

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

这意味着生成的 APK 只能作为 GitHub 预览发布使用，不能宣称为 Play Store 或其他应用商店级生产包。

## 规则

- 不提交 keystore、签名密码、key alias 密码或 CI 签名密钥。
- 如果后续启用发布签名，凭据必须通过本机安全位置或 GitHub Actions secrets 注入。
- 发布说明必须写明 APK 使用调试签名、本地发布签名或 CI 托管签名。
- 调试签名 APK 必须标注为 GitHub 预览发布。

## 后续升级

应用商店预备级发布需要单独 OpenSpec 变更，至少覆盖：正式签名、隐私政策 URL、应用图标和截图、设备兼容矩阵、崩溃/日志策略和商店审核材料。
