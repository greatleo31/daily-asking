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
  List<String>? baseUrls,
  Duration? requestTimeout,
}) {
  return UpdateService(
    UpdatePrefs(storage ?? _MemoryStorage()),
    client: MockClient(handler),
    baseUrls: baseUrls,
    baseUrl: baseUrl,
    requestTimeout: requestTimeout,
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
  String url = 'https://example.com/app.apk',
}) => jsonEncode({
  'versionCode': versionCode,
  'versionName': versionName,
  'url': url,
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
      expect((d as UpdateCheckFailed).reason, '所有更新源检查失败');
      expect(await svc.lastCheckedAt, isNull);
    });

    test('清单非法 → UpdateCheckFailed（不崩溃）', () async {
      final svc = _serviceWith(
        handler: (req) async => _jsonResponse('not-json'),
      );
      final d = await svc.check();
      expect(d, isA<UpdateCheckFailed>());
      expect((d as UpdateCheckFailed).reason, '所有更新源检查失败');
    });

    test('网络异常 → UpdateCheckFailed（不崩溃）', () async {
      final svc = _serviceWith(
        handler: (req) async =>
            throw http.ClientException('connection refused'),
      );
      final d = await svc.check();
      expect(d, isA<UpdateCheckFailed>());
      expect((d as UpdateCheckFailed).reason, '所有更新源检查失败');
    });
  });

  group('多更新源', () {
    test('latestJsonUrls 每源一条、latestJsonUrl 取首源', () {
      final svc = _serviceWith(
        baseUrl: '',
        baseUrls: const [
          'http://a.example.com/',
          'http://b.example.com',
          ' http://c.example.com ',
        ],
        handler: (req) async => _jsonResponse(_manifest(kAppVersionCode)),
      );
      expect(svc.latestJsonUrl, startsWith('http://a.example.com/latest.json'));
      expect(svc.latestJsonUrls, hasLength(3));
      for (final url in svc.latestJsonUrls) {
        expect(url, contains('/latest.json'));
        expect(url, contains('platform=android'));
        expect(url, contains('channel=stable'));
        expect(url, contains('vc=$kAppVersionCode'));
      }
    });

    test('多源文本按逗号/分号/换行规范化、去尾斜杠', () {
      final svc = _serviceWith(
        baseUrl: '',
        baseUrls: const [
          'http://a.example.com/,http://b.example.com;',
          'http://c.example.com\n http://d.example.com/ ',
        ],
        handler: (req) async => _jsonResponse(_manifest(kAppVersionCode)),
      );
      expect(svc.isConfigured, isTrue);
      expect(svc.latestJsonUrls, hasLength(4));
      expect(svc.latestJsonUrls[0], startsWith('http://a.example.com/latest.json'));
      expect(svc.latestJsonUrls[1], startsWith('http://b.example.com/latest.json'));
      expect(svc.latestJsonUrls[2], startsWith('http://c.example.com/latest.json'));
      expect(svc.latestJsonUrls[3], startsWith('http://d.example.com/latest.json'));
    });

    test('首源超时、次源合法且更高 → UpdateAvailable 并记录时间', () async {
      final store = _MemoryStorage();
      final svc = _serviceWith(
        storage: store,
        baseUrl: '',
        baseUrls: const ['http://slow.example.com', 'http://fast.example.com'],
        requestTimeout: const Duration(milliseconds: 150),
        handler: (req) async {
          if (req.url.host == 'slow.example.com') {
            await Future<void>.delayed(const Duration(seconds: 3));
            return _jsonResponse(_manifest(kAppVersionCode + 1));
          }
          return _jsonResponse(_manifest(kAppVersionCode + 2));
        },
      );
      final d = await svc.check();
      expect(d, isA<UpdateAvailable>());
      expect((d as UpdateAvailable).info.versionCode, kAppVersionCode + 2);
      expect(await svc.lastCheckedAt, isNotNull);
    });

    test('一个源 HTTP 500、另一个源合法 → 仍成功', () async {
      final svc = _serviceWith(
        baseUrl: '',
        baseUrls: const ['http://broken.example.com', 'http://ok.example.com'],
        handler: (req) async {
          if (req.url.host == 'broken.example.com') {
            return http.Response('boom', 500);
          }
          return _jsonResponse(_manifest(kAppVersionCode + 1));
        },
      );
      final d = await svc.check();
      expect(d, isA<UpdateAvailable>());
      expect((d as UpdateAvailable).info.versionCode, kAppVersionCode + 1);
    });

    test('一个源坏 JSON、另一个源合法 → 仍成功', () async {
      final svc = _serviceWith(
        baseUrl: '',
        baseUrls: const ['http://bad.example.com', 'http://ok.example.com'],
        handler: (req) async {
          if (req.url.host == 'bad.example.com') {
            return _jsonResponse('not-json');
          }
          return _jsonResponse(_manifest(kAppVersionCode + 1));
        },
      );
      final d = await svc.check();
      expect(d, isA<UpdateAvailable>());
      expect((d as UpdateAvailable).info.versionCode, kAppVersionCode + 1);
    });

    test('两个合法清单选 versionCode 最高者', () async {
      final svc = _serviceWith(
        baseUrl: '',
        baseUrls: const ['http://low.example.com', 'http://high.example.com'],
        handler: (req) async {
          if (req.url.host == 'low.example.com') {
            return _jsonResponse(_manifest(kAppVersionCode + 1));
          }
          return _jsonResponse(_manifest(kAppVersionCode + 9));
        },
      );
      final d = await svc.check();
      expect(d, isA<UpdateAvailable>());
      expect((d as UpdateAvailable).info.versionCode, kAppVersionCode + 9);
    });

    test('同版本平局取配置顺序靠前源的清单 URL', () async {
      final svc = _serviceWith(
        baseUrl: '',
        baseUrls: const ['http://first.example.com', 'http://second.example.com'],
        handler: (req) async {
          final host = req.url.host;
          return _jsonResponse(_manifest(
            kAppVersionCode + 5,
            url: 'https://$host/app-release.apk',
          ));
        },
      );
      final d = await svc.check();
      expect(d, isA<UpdateAvailable>());
      expect(
        (d as UpdateAvailable).info.url,
        'https://first.example.com/app-release.apk',
        reason: '平局时应取配置顺序靠前源的清单（含其 APK url）',
      );
    });

    test('全部源失败 → 所有更新源检查失败且不记录时间', () async {
      final store = _MemoryStorage();
      var calls = 0;
      final svc = _serviceWith(
        storage: store,
        baseUrl: '',
        baseUrls: const ['http://x.example.com', 'http://y.example.com'],
        requestTimeout: const Duration(milliseconds: 150),
        handler: (req) async {
          calls++;
          throw http.ClientException('refused');
        },
      );
      final d = await svc.check();
      expect(d, isA<UpdateCheckFailed>());
      expect((d as UpdateCheckFailed).reason, '所有更新源检查失败');
      expect(calls, 2, reason: '两个源都应当被并发尝试');
      expect(await svc.lastCheckedAt, isNull);
    });
  });
}
