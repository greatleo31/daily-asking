/// 版本号单一来源（与 pubspec.yaml 的 `version:` 同步）。
///
/// 由 `scripts/bump-version.sh` 自动维护，禁止手改。
/// 映射规则（docs/02-版本与更新机制.md §2.1.1）：
///   versionCode = major * 10000 + minor * 100 + patch
library;

/// 展示用语义化版本名（versionName）。
const kAppVersionName = '1.2.0';

/// 更新判定唯一依据（versionCode），必须单调递增。
const kAppVersionCode = 10200;

/// 按 SemVer 三段计算 versionCode（与 bump 脚本保持一致）。
int versionCodeOf(int major, int minor, int patch) =>
    major * 10000 + minor * 100 + patch;

/// 把 `major.minor.patch` 文本解析为三段；非法返回 null。
List<int>? parseSemVer(String name) {
  final parts = name.split('.');
  if (parts.length != 3) return null;
  final major = int.tryParse(parts[0]);
  final minor = int.tryParse(parts[1]);
  final patch = int.tryParse(parts[2]);
  if (major == null || minor == null || patch == null) return null;
  return [major, minor, patch];
}