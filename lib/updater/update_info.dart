/// 更新机制：`latest.json` 解析模型与检查决策。
///
/// 字段规则（docs/02 §2.3.3）：只增不改删；客户端容忍缺字段；
/// `versionCode` / `versionName` / `url` 缺失或类型错误 → 解析失败（按检查失败处理）。
library;

import 'dart:convert';

/// 服务端 `latest.json` 的解析结果。
class UpdateInfo {
  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.url,
    this.changelog = '',
    this.mandatory = false,
    this.releaseDate = '',
    this.sha256 = '',
    this.minVersionCode,
  });

  /// 单调递增；更新判定唯一依据。
  final int versionCode;

  /// 展示用版本名。
  final String versionName;

  /// APK 直链（生产必须 HTTPS）。
  final String url;

  /// 更新日志（Markdown 文本），空则显示默认文案。
  final String changelog;

  /// 是否强制更新，默认 false。
  final bool mandatory;

  /// 发布日期 `YYYY-MM-DD`。
  final String releaseDate;

  /// APK SHA-256，下载完成后校验（可选）。
  final String sha256;

  /// 最低可升级版本；低于它提示先装中间版本（可选）。
  final int? minVersionCode;

  /// 解析 `latest.json`；关键字段不合法返回 null（视为检查失败，不崩溃）。
  static UpdateInfo? parse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final vc = decoded['versionCode'];
      final vn = decoded['versionName'];
      final url = decoded['url'];
      if (vc is! int || vn is! String || vn.isEmpty || url is! String || url.isEmpty) {
        return null;
      }
      return UpdateInfo(
        versionCode: vc,
        versionName: vn,
        url: url,
        changelog: decoded['changelog'] is String
            ? decoded['changelog'] as String
            : '',
        mandatory: decoded['mandatory'] is bool
            ? decoded['mandatory'] as bool
            : false,
        releaseDate: decoded['releaseDate'] is String
            ? decoded['releaseDate'] as String
            : '',
        sha256: decoded['sha256'] is String ? decoded['sha256'] as String : '',
        minVersionCode: decoded['minVersionCode'] is int
            ? decoded['minVersionCode'] as int
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 一次检查更新的决策结果。
sealed class UpdateDecision {
  const UpdateDecision();
}

/// 无更新（服务端 versionCode <= 客户端；不允许降级）。
class NoUpdate extends UpdateDecision {
  const NoUpdate();
}

/// 有新版本。
class UpdateAvailable extends UpdateDecision {
  const UpdateAvailable(this.info);

  final UpdateInfo info;
}

/// 检查失败（网络、解析等）。
class UpdateCheckFailed extends UpdateDecision {
  const UpdateCheckFailed([this.reason = '']);

  final String reason;
}