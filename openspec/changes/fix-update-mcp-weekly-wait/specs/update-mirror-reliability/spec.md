## Purpose

更新检查支持多镜像并发检查与择优、发布清单可写外部 HTTPS 直链的可观察契约，替代单一源固定 10s 超时行为。

## ADDED Requirements

### Requirement: 多更新源并发检查与择优

更新检查 SHALL 支持配置一个或多个更新基址（构造参数 `baseUrls` / `baseUrl` 与 `String.fromEnvironment('UPDATE_BASE_URLS')` / `UPDATE_BASE_URL` 均可提供来源，多来源以逗号/分号/换行分隔，逐项去空白并去尾部 `/`）。每次检查 SHALL 并发请求全部已配置源，单源超时默认 6 秒。收集全部源的清单结果后 SHALL 选择 versionCode 最高者作为本次检查结论；多个源返回相同最高 versionCode 时 SHALL 取配置顺序更靠前者（保证「Gitee 在前则从 Gitee 下载」）。存在至少一个合法清单时 SHALL 视为检查成功并记录 `lastCheckedAt`，且 SHALL NOT 因其余源失败/超时/HTTP 非 200/解析失败而改变结论。仅当全部源均失败、超时、非 200 或解析失败时 SHALL 返回失败，reason 为「所有更新源检查失败」。检查未配置任何源时 SHALL 不发起网络请求并返回失败。

#### Scenario: 首源超时次源正常
- **WHEN** 配置了两个更新源且第一个源请求超时、第二个源返回合法且更高的 versionCode
- **THEN** 检查结果 SHALL 为 `UpdateAvailable`（使用第二个源的清单信息）
- **AND** `lastCheckedAt` SHALL 被记录

#### Scenario: 同版本平局按配置顺序
- **WHEN** 两个源都返回合法清单且 versionCode 相同（且高于当前）
- **THEN** 结论 SHALL 使用配置顺序靠前源返回的清单（其 APK `url` 为下载地址）

#### Scenario: 全部源失败
- **WHEN** 所有已配置源均失败（超时/非 200/非法清单）
- **THEN** 检查结果 SHALL 为 `UpdateCheckFailed` 且 reason 为「所有更新源检查失败」
- **AND** `lastCheckedAt` SHALL NOT 被记录

#### Scenario: URL 列表访问器
- **WHEN** 已配置多个源
- **THEN** `latestJsonUrls` SHALL 每源返回一条 `latest.json` URL（带 platform/channel/vc 参数）
- **AND** `latestJsonUrl` SHALL 返回第一条（兼容旧 UI/测试）

### Requirement: 发布清单可写外部 HTTPS 直链

清单生成脚本 `scripts/generate-latest-json.sh` SHALL 接受 `<apk路径> [changelog] [--mandatory] [--out <path>] [--asset-url <https-url>]`。`--asset-url` 提供时，生成的 `latest.json` 中 `url` SHALL 精确等于该值；未提供时 SHALL 保持本地演示地址 `http://127.0.0.1:8090/<apk文件名>`。`--out` 缺省为 `build/latest.json`，输出前 SHALL 创建父目录。脚本 SHALL 继续从 `lib/core/version.dart`（单一来源）读取 `kAppVersionName` / `kAppVersionCode` 并写出 `versionCode` / `versionName` / `url` / `changelog` / `mandatory` / `releaseDate` / `sha256`。版本号提取若因执行机缺少 `grep -oP` 失败，SHALL 在同一脚本内改用短 Python 正则，不改变单一来源语义。

#### Scenario: 带 asset-url 发布
- **WHEN** 以 `--asset-url https://<镜像>/<版本>/app-release.apk --out build/update-gitee/latest.json` 运行脚本
- **THEN** 输出文件存在、`versionCode` 等于当前 `kAppVersionCode`、`url` 精确等于所给 HTTPS 地址

#### Scenario: 不带 asset-url 本地演示
- **WHEN** 不带 `--asset-url` 运行脚本
- **THEN** 生成清单的 `url` 以 `http://127.0.0.1:8090/` 开头
