/// 更新检查与下载安装编排（Dart 侧）。
///
/// 检查：GET `{kUpdateBaseUrl}/latest.json?platform=android&channel=stable&vc=<当前>`，
///   解析并比对 versionCode；失败返回 [UpdateCheckFailed]（自动检查静默）。
/// 下载/安装：委托原生 MethodChannel（DownloadManager 通知栏进度 → FileProvider + ACTION_VIEW）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/version.dart';
import 'update_info.dart';
import 'update_prefs.dart';

/// 更新清单基址。
///
/// 默认不配置，避免正式构建误请求开发机 localhost。生产或演示构建必须通过
/// `--dart-define=UPDATE_BASE_URL=https://update.<domain>` 显式注入。
const kUpdateBaseUrl = String.fromEnvironment(
  'UPDATE_BASE_URL',
  defaultValue: '',
);

/// 更新服务。
class UpdateService {
  UpdateService(this._prefs, {http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? kUpdateBaseUrl).trim();

  final UpdatePrefs _prefs;
  final http.Client _client;
  final String _baseUrl;
  bool get isConfigured => _baseUrl.isNotEmpty;

  static const _channel = MethodChannel('com.dailyasking.daily_asking/update');

  static const _platform = 'android';
  static const _channelName = 'stable';

  String get latestJsonUrl =>
      '$_baseUrl/latest.json?platform=$_platform&channel=$_channelName&vc=$kAppVersionCode';

  /// 检查更新：未配置更新源时直接返回，不发起网络请求。
  Future<UpdateDecision> check() async {
    if (!isConfigured) return const UpdateCheckFailed('更新服务未配置');
    try {
      final resp = await _client
          .get(Uri.parse(latestJsonUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        return UpdateCheckFailed('HTTP ${resp.statusCode}');
      }
      final info = UpdateInfo.parse(utf8.decode(resp.bodyBytes));
      if (info == null) return const UpdateCheckFailed('清单解析失败');
      await _prefs.setLastCheckedAt(DateTime.now());
      if (info.versionCode <= kAppVersionCode) return const NoUpdate();
      return UpdateAvailable(info);
    } on Exception catch (e) {
      return UpdateCheckFailed(e.toString());
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
