// UpdateService.check 单元测试：
// 注入 mock http.Client 覆盖请求参数、NoUpdate / UpdateAvailable / UpdateCheckFailed 三态，
// 以及成功检查后记录 lastCheckedAt、失败不记录。
import 'dart:convert';

import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/core/version.dart';
import 'package:daily_asking/updater/update_info.dart';
import 'package:daily_asking/updater/update_prefs.dart';
import 'package:daily_asking/updater/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 内存版 StorageService，用于 UpdatePrefs。
class _MemoryStorage implements StorageService {
  final Map<String, String> _map = {};

  @override
  Future<String?> readString(String key) async => _map[key];

  @override
  Future<void> writeString(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _map.remove(key);
  }
}

UpdateService _serviceWith({
  required Future<http.Response> Function(http.Request) handler,
  _MemoryStorage? storage,
  String baseUrl = 'http://127.0.0.1:8090',
}) {
  return UpdateService(
    UpdatePrefs(storage ?? _MemoryStorage()),
    client: MockClient(handler),
    baseUrl: baseUrl,
  );
}

http.Response _jsonResponse(String body, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

String _manifest(
  int versionCode, {
  String versionName = '9.9.9',
  bool mandatory = false,
}) => jsonEncode({
  'versionCode': versionCode,
  'versionName': versionName,
  'url': 'https://example.com/app.apk',
  'changelog': '更新说明',
  'mandatory': mandatory,
  'sha256': 'abc',
});

void main() {
  group('UpdateService.check', () {
    test('未配置更新源时不发起网络请求', () async {
      var requested = false;
      final svc = _serviceWith(
        baseUrl: '',
        handler: (req) async {
          requested = true;
          return _jsonResponse('{}');
        },
      );

      final decision = await svc.check();

      expect(decision, isA<UpdateCheckFailed>());
      expect((decision as UpdateCheckFailed).reason, '更新服务未配置');
      expect(requested, isFalse);
    });
    test('未注入构建参数时更新源默认未配置', () {
      expect(kUpdateBaseUrl, isEmpty);
    });

    test('更新服务暴露是否已配置，不依赖试探网络', () {
      final unconfigured = _serviceWith(
        baseUrl: '',
        handler: (req) async => _jsonResponse('{}'),
      );
      final configured = _serviceWith(
        handler: (req) async => _jsonResponse('{}'),
      );

      expect(unconfigured.isConfigured, isFalse);
      expect(configured.isConfigured, isTrue);
    });

    test('请求清单路径携带 platform/channel/vc 参数', () async {
      Uri? seen;
      final svc = _serviceWith(
        handler: (req) async {
          seen = req.url;
          return _jsonResponse(_manifest(kAppVersionCode));
        },
      );
      await svc.check();
      expect(seen, isNotNull);
      expect(seen!.path, '/latest.json');
      expect(seen!.queryParameters['platform'], 'android');
      expect(seen!.queryParameters['channel'], 'stable');
      expect(seen!.queryParameters['vc'], '$kAppVersionCode');
    });

    test('服务端 versionCode <= 当前 → NoUpdate，且记录检查时间', () async {
      final store = _MemoryStorage();
      final svc = _serviceWith(
        storage: store,
        handler: (req) async => _jsonResponse(_manifest(kAppVersionCode)),
      );
      final d = await svc.check();
      expect(d, isA<NoUpdate>());
      expect(await svc.lastCheckedAt, isNotNull);
    });

    test('服务端 versionCode 更大 → UpdateAvailable（含强制标记）', () async {
      final svc = _serviceWith(
        handler: (req) async =>
            _jsonResponse(_manifest(kAppVersionCode + 1, mandatory: true)),
      );
      final d = await svc.check();
      expect(d, isA<UpdateAvailable>());
      final info = (d as UpdateAvailable).info;
      expect(info.versionCode, kAppVersionCode + 1);
      expect(info.mandatory, isTrue);
      expect(info.changelog, '更新说明');
      expect(await svc.lastCheckedAt, isNotNull);
    });

    test('HTTP 非 200 → UpdateCheckFailed，且不记录检查时间', () async {
      final store = _MemoryStorage();
      final svc = _serviceWith(
        storage: store,
        handler: (req) async => http.Response('Internal Server Error', 500),
      );
      final d = await svc.check();
      expect(d, isA<UpdateCheckFailed>());
      expect(await svc.lastCheckedAt, isNull);
    });

    test('清单非法 → UpdateCheckFailed（不崩溃）', () async {
      final svc = _serviceWith(
        handler: (req) async => _jsonResponse('not-json'),
      );
      final d = await svc.check();
      expect(d, isA<UpdateCheckFailed>());
    });

    test('网络异常 → UpdateCheckFailed（不崩溃）', () async {
      final svc = _serviceWith(
        handler: (req) async =>
            throw http.ClientException('connection refused'),
      );
      final d = await svc.check();
      expect(d, isA<UpdateCheckFailed>());
      expect((d as UpdateCheckFailed).reason, contains('connection refused'));
    });
  });
}
