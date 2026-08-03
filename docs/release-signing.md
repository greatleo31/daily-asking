# Release Signing Posture

Daily Asking v0.1 的发布目标是 GitHub preview APK，不是应用商店级发布。

## Current State

当前 Android release build 仍使用 Gradle debug signing：

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

这意味着生成的 APK 只能作为 GitHub preview release 使用，不能宣称为 Play Store 或其他应用商店级生产包。

## Rules

- 不提交 keystore、签名密码、key alias 密码或 CI signing secret。
- 如果后续启用 release signing，凭据必须通过本机安全位置或 GitHub Actions secrets 注入。
- release notes 必须写明 APK 使用 debug signing、local release signing 或 CI-managed signing。
- debug-signed APK 必须标注为 GitHub preview release。

## Future Upgrade

应用商店预备级发布需要单独 OpenSpec change，至少覆盖：正式签名、隐私政策 URL、应用图标和截图、设备兼容矩阵、崩溃/日志策略和商店审核材料。
