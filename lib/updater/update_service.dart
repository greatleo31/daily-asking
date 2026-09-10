/// 更新检查与下载安装编排（Dart 侧）。
///
/// 检查：并发 GET 每个已配置源的 `{base}/latest.json?platform=android&channel=stable&vc=<当前>`，
///   每源独立超时（默认 6s）；存在任一合法清单即视为检查成功，取所有合法清单中
///   versionCode 最高者（平局按配置顺序取靠前源）。全部源失败/超时/非 200/解析失败
///   才返回 [UpdateCheckFailed]（自动检查静默）。
/// 下载/安装：委托原生 MethodChannel（DownloadManager 通知栏进度 → FileProvider + ACTION_VIEW）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/version.dart';
import 'update_info.dart';
import 'update_prefs.dart';

/// 更新清单基址（兼容单源注入）。
///
/// 默认不配置，避免正式构建误请求开发机 localhost。生产或演示构建必须通过
/// `--dart-define=UPDATE_BASE_URL=https://update.<domain>` 显式注入。
const kUpdateBaseUrl = String.fromEnvironment(
  'UPDATE_BASE_URL',
  defaultValue: '',
);

/// 多更新源基址（推荐）。多个源以逗号/分号/换行分隔；首个源为主镜像，
/// 其余为回退镜像。构建注入示例：
/// `--dart-define=UPDATE_BASE_URLS=https://mirror.example.com/update,https://github.com/.../releases/latest/download`
const kUpdateBaseUrls = String.fromEnvironment(
  'UPDATE_BASE_URLS',
  defaultValue: '',
);

/// 更新服务。
class UpdateService {
  UpdateService(
    this._prefs, {
    http.Client? client,
    List<String>? baseUrls,
    String? baseUrl,
    Duration? requestTimeout,
  }) : _client = client ?? http.Client(),
       _requestTimeout = requestTimeout ?? const Duration(seconds: 6),
       _baseUrls = _normalizeSources([
         ...?baseUrls,
         kUpdateBaseUrls,
         baseUrl ?? kUpdateBaseUrl,
       ]);

  final UpdatePrefs _prefs;
  final http.Client _client;
  final Duration _requestTimeout;
  final List<String> _baseUrls;

  /// 把多来源文本统一成规范基址列表：逗号/分号/换行拆分、去空白、去空、去尾部 `/`。
  static List<String> _normalizeSources(Iterable<String> sources) {
    final result = <String>[];
    for (final raw in sources) {
      for (final part in raw.split(RegExp(r'[,;\n]'))) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final normalized = trimmed.endsWith('/')
            ? trimmed.substring(0, trimmed.length - 1)
            : trimmed;
        if (normalized.isEmpty || result.contains(normalized)) continue;
        result.add(normalized);
      }
    }
    return result;
  }

  bool get isConfigured => _baseUrls.isNotEmpty;

  static const _channel = MethodChannel('com.dailyasking.daily_asking/update');

  static const _platform = 'android';
  static const _channelName = 'stable';

  /// 每个已配置源各生成一条最新清单 URL。
  List<String> get latestJsonUrls => [
    for (final base in _baseUrls)
      '$base/latest.json?platform=$_platform&channel=$_channelName&vc=$kAppVersionCode',
  ];

  /// 第一个（主）源的清单 URL；未配置时为空字符串。
  String get latestJsonUrl => latestJsonUrls.isEmpty ? '' : latestJsonUrls.first;

  /// 检查更新：未配置更新源时直接返回，不发起网络请求。
  ///
  /// 并发请求全部源；每源独立 [Duration]（默认 6s）超时。解析全部返回的合法清单，
  /// 选择 versionCode 最高者；平局取配置顺序靠前源。存在至少一个合法清单即记录
  /// `lastCheckedAt` 并据此决策；全部源失败才返回 [UpdateCheckFailed]。
  Future<UpdateDecision> check() async {
    if (!isConfigured) return const UpdateCheckFailed('更新服务未配置');

    final urls = latestJsonUrls;
    final results = await Future.wait<({int order, UpdateInfo? info})>([
      for (final (order, url) in urls.indexed) _fetchSource(order, url),
    ]);

    final valid = results.where((r) => r.info != null).toList()
      ..sort((a, b) {
        final vc = b.info!.versionCode.compareTo(a.info!.versionCode);
        if (vc != 0) return vc;
        return a.order.compareTo(b.order);
      });

    if (valid.isEmpty) {
      return const UpdateCheckFailed('所有更新源检查失败');
    }

    await _prefs.setLastCheckedAt(DateTime.now());
    final best = valid.first.info!;
    if (best.versionCode <= kAppVersionCode) return const NoUpdate();
    return UpdateAvailable(best);
  }

  Future<({int order, UpdateInfo? info})> _fetchSource(int order, String url) async {
    try {
      final resp = await _client.get(Uri.parse(url)).timeout(_requestTimeout);
      if (resp.statusCode != 200) return (order: order, info: null);
      final info = UpdateInfo.parse(utf8.decode(resp.bodyBytes));
      return (order: order, info: info);
    } on Exception {
      return (order: order, info: null);
    }
  }

  /// 「关于」页展示的上次检查时间（缺失显示「从未检查」）。
  Future<DateTime?> get lastCheckedAt => _prefs.lastCheckedAt();

  /// 自动更新开关（默认关）。
  Future<bool> isAutoUpdateEnabled() => _prefs.isAutoUpdateEnabled();

  Future<void> setAutoUpdateEnabled(bool enabled) =>
      _prefs.setAutoUpdateEnabled(enabled);

  /// 触发原生下载并安装。
  ///
  /// 返回 true 表示已成功入队（进度由系统通知栏展示）；false 表示入队失败。
  Future<bool> downloadAndInstall(UpdateInfo info) async {
    try {
      await _channel.invokeMethod<void>('downloadAndInstall', <String, Object?>{
        'url': info.url,
        'fileName': 'liuhen-${info.versionName}.apk',
        'sha256': info.sha256,
        'title': '留痕 ${info.versionName}',
      });
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
