# 发布签名（Android Release 签名）

> **当前状态（2026-09-11）**：Gradle 侧配置与本文档已就绪，但 **keystore 尚未生成**，
> `android/key.properties` 不存在 —— 因此 release 包仍走 debug 签名，现有构建流程不受影响。
> 把 keystore 建好、`android/key.properties` 填好之后，下一次 `sh scripts/build-release.sh`
> 会自动改用正式签名，无需再改代码。

关联：[`docs/02-版本与更新机制.md`](02-版本与更新机制.md) §6.4（发布步骤）、§7（已知限制）、
`android/key.properties.example`、`scripts/build-release.sh`、`scripts/generate-latest-json.sh`。

## 1. 这个密钥有什么用

Android 用「签名证书」来确定**一个安装包是不是某个已装应用的更新**，而不是用它做加密或授权。

| 作用 | 说明 |
| --- | --- |
| 应用身份证明 | 系统与各应用商店按 `applicationId` + 签名证书认定「同一个应用」。证书变了，系统就当成另一个应用。 |
| 覆盖安装的判定依据 | 同一 `applicationId` 的包，签名证书必须与已装版本一致，才能原地升级；不一致时安装器直接拒绝（`INSTALL_FAILED_UPDATE_INCOMPATIBLE`），**只能卸载后重装**。 |
| 分发/上架前提 | 应用商店一律要求稳定签名；Google Play 的 App Signing 是同一机制的托管形式。 |
| 升级链路的前提 | 本应用的「检查更新 → 下载 APK → 拉起安装页」最终也要过系统这一关，签名不一致时用户会在安装那一步失败。 |

它**不做**的事：不加密代码、不防反编译（那是 R8/混淆的事，本项目未启用）、不是 CA 身份证书、
不做运行时授权校验。它只是「包的身份」。

**为什么不能用 debug 签名发布**：debug keystore 在 `~/.android/debug.keystore`，
口令固定（`android`）、别名固定（`androiddebugkey`），**换机器/重装系统就换了身份**，
且任何拿到 Android SDK 的人都能伪造同身份的包。当前发布的 APK 就是这个状态（见 §2）。

## 2. 现状（可自查）

- `android/app/build.gradle.kts` 的 `release` buildType：
  - 存在 `android/key.properties` → 使用其中的 `release` 签名配置；
  - 不存在 → 退回 `signingConfigs.getByName("debug")`，保证 clone 后 `flutter build apk --release`
    与 `flutter run --release` 仍可直接跑通。
- 当前 `build/app/outputs/flutter-apk/app-release.apk` 的签名者实测为 `CN=Android Debug`：

  ```bash
  /d/developsoftware/android-sdk-daily-asking/build-tools/36.0.0/apksigner.bat \
      verify --print-certs build/app/outputs/flutter-apk/app-release.apk
  # Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
  # Signer #1 certificate SHA-256 digest: da1a9bd9ea0f458484e45c0415056a20a50c9441f806c73e2f7ed68416701f9b
  ```

- 不看 APK 也能查「当前 release 用哪套签名」（读的就是 `android/key.properties` 的生效结果）：

  ```bash
  cd android && cmd //c "gradlew.bat :app:signingReport --console=plain"
  # Variant: release / Config: debug   → 仍是 debug 签名（key.properties 不存在）
  # Variant: release / Config: release → 已用正式签名，Store/Alias/指纹应与你的一致
  ```

- 正式签名后这个 SHA-256 会变成你自己的证书指纹；**APK 的 sha256 也随之改变**，
  所以 `latest.json` 必须重新生成（§6）。

## 3. 生成 keystore（一次性，只做一次）

用 JDK 自带 keytool（本机：`D:\developsoftware\jdk17`，或 Android Studio 的
`C:\Program Files\Android\Android Studio\jbr`）：

```bash
# 交互式（口令不落进 shell 历史，推荐）
/d/developsoftware/jdk17/bin/keytool.exe -genkeypair -v \
    -keystore D:/keys/liuhen-release.jks \
    -alias liuhen \
    -keyalg RSA -keysize 2048 -validity 10000
```

- `-validity 10000`（约 27 年）：证书过期不影响已发布应用的升级判定，但省得以后处理。
- `-storetype` 不写即用 JDK 默认的 PKCS12；**PKCS12 下密钥口令与 keystore 口令必须是同一个**
  （keytool 会提示），所以 `key.properties` 里的 `keyPassword` 直接填 `storePassword` 的值。
- DN（姓名/组织/国家）随便填，只影响证书里的字符串，不影响功能；**但证书本身不要换**。
- 建议放在**仓库之外**的目录（示例用 `D:/keys/`），别和源码混在一起。

生成后立刻核对并记下指纹：

```bash
/d/developsoftware/jdk17/bin/keytool.exe -list -v -keystore D:/keys/liuhen-release.jks -alias liuhen
# 记下 "SHA256:" 那一行（= 将来 apksigner 打印的 Signer #1 certificate SHA-256 digest）
```

## 4. 配置 `android/key.properties`

复制模板再填：

```bash
cp android/key.properties.example android/key.properties
```

| 字段 | 含义 | 备注 |
| --- | --- | --- |
| `storeFile` | keystore 路径 | 相对路径按 **`android/app/`** 解析；Windows 下建议直接写绝对路径。`\` 在 `.properties` 里是转义符，用 `/` 或 `\\`。**路径避免非 ASCII 字符**：`.properties` 按 ISO-8859-1 解码，`C:\Users\胡衍科\…` 会变成乱码导致找不到文件；把 keystore 放纯 ASCII 目录，或用 `\uXXXX` 转义写中文（实测有效）。 |
| `storePassword` | keystore 口令 | |
| `keyAlias` | 密钥别名 | 例：`liuhen` |
| `keyPassword` | 密钥口令 | PKCS12 下与 `storePassword` 相同 |

`android/key.properties` 与 keystore 已被 `.gitignore` 排除（`key.properties`、`*.jks`、
`*.keystore`、`*.p12`），**不要为了图方便把它们加进仓库**。

填好后即可构建并验证：

```bash
sh scripts/build-release.sh                        # 构建（更新源固化注入）
/d/developsoftware/android-sdk-daily-asking/build-tools/36.0.0/apksigner.bat \
    verify --print-certs build/app/outputs/flutter-apk/app-release.apk
# Signer #1 certificate DN 应为你在 §3 填的 DN/别名，SHA-256 与 §3 记录的一致
```

配置写错时不会静默降级为 debug 签名，Gradle 会在**配置阶段**直接报错（实测）：

- 缺字段 → `android/key.properties 缺少字段: storePassword, keyPassword；…`；
- `storeFile` 指向的文件不存在 → 打印解析后的绝对路径后报错
  （中文路径被 ISO-8859-1 解码成 `C:\Users\è¡è¡ç§\…` 也是走这条）；
- 口令/别名错 → 构建不一定在配置期就停：`signingReport` 会把
  `Error: Failed to read key <alias> from store "…": keystore password was incorrect`
  打成一行 Error 输出**但仍报 BUILD SUCCESSFUL**，真正 `assembleRelease` 时才会失败。
  所以 §4 的验收要以 `apksigner verify --print-certs` 的指纹为准，别只看构建是否成功。

另外，未配置 `key.properties` 却执行含 `Release` 字样的任务时，
Gradle 会在日志里打印一条「release 包将使用 debug 签名」的警告（只提醒，不阻断构建）。

## 5. 首次切换签名的代价（重要，需要用户配合）

- **已安装 debug 签名版本的用户无法覆盖安装**：系统在安装那一步直接拒绝，
  必须先卸载旧版本，再装新签名的包。
- 本应用是 **local-first**：记录存在本机（`shared_preferences` + 本地文件），
  **卸载会一并删除**。发版前应在应用内先导出（`lib/core/export/markdown_exporter.dart` 的
  Markdown 导出），卸载前提醒用户导出。
- 建议把「本次更新需要卸载重装一次、请先导出记录」写进该版本的 changelog；
  是否把 `mandatory` 置 `true` 按当时情况决定（强制更新框本来就要求先卸载，观感上更直白）。
- 换签名本身**不需要**特殊跳版本号，但按流程仍要用 `sh scripts/bump-version.sh <新版本>` 正常递增
  （客户端只按 `versionCode` 判定更新）。
- 换签名只影响新包；老包（debug 签名）里的更新源是构建时注入的，仍会用旧地址检查更新，
  但它们下载到新包后安装会失败 —— 这正是上面第一条要提前告知用户的原因。

## 6. 换签名后必须同步的东西

1. 重新生成**每个镜像各自的** `latest.json`（`sha256` 一定变了）：

   ```bash
   sh scripts/generate-latest-json.sh build/app/outputs/flutter-apk/app-release.apk "发布说明" \
       --asset-url https://gitee.com/yankehu/daily_asking/releases/download/v<版本>/liuhen-<版本>.apk \
       --out update/latest.json
   ```

2. 提交并推送 `update/latest.json`；GitHub 回退镜像的 Release 附件里也要带上它自己的 `latest.json`。
3. 按 [`docs/02-版本与更新机制.md`](02-版本与更新机制.md) §6.4 走完发布步骤。

## 7. 备份与安全红线

- keystore 至少 **2 份异地备份**（U 盘 / 私有云 / 密码管理器附件），口令进密码管理器；
  不要只留在工作机上。
- **keystore 丢失 = 永远无法再对同一个 `applicationId` 原地发布更新**，只能换包名或让所有用户卸载重装。
- 绝不出现在：仓库、聊天记录、issue、截图、构建产物、日志。
- 万一误提交：按泄漏处理（换签名 + 接受 §5 的代价），并把该提交从历史里清掉。

## 8. 常见问题

| 现象 | 原因 / 处理 |
| --- | --- |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 设备上装的是另一种签名的同包名应用；卸载后重装（先导出记录）。 |
| 构建报「storeFile 指向的文件不存在」 | `key.properties` 里的路径相对 `android/app/`；确认文件真的在那个位置。 |
| 构建报「缺少字段」 | 四个字段都要有；对照 `android/key.properties.example`。 |
| 不知道手上的包是什么签名 | `apksigner.bat verify --print-certs <apk>`，看 `Signer #1 certificate DN`。 |
| 想临时用回 debug 签名 | 把 `android/key.properties` 移走/改名即可（构建退回 debug，不影响其他功能）。 |
