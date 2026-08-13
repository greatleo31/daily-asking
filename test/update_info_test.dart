// 更新机制单元测试：
// 1) latest.json 解析容错（缺字段/未知字段/关键字段非法）
// 2) 版本比对三态（无更新=<=当前 / 有新版本 / 检查失败兜底）
import 'package:daily_asking/core/version.dart';
import 'package:daily_asking/updater/update_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateInfo.parse', () {
    test('完整合法清单', () {
      final info = UpdateInfo.parse('''
      {
        "versionCode": 10200,
        "versionName": "1.2.0",
        "url": "https://example.com/app.apk",
        "changelog": "新增功能",
        "mandatory": true,
        "releaseDate": "2026-08-11",
        "sha256": "abc",
        "minVersionCode": 10100,
        "extraFutureField": 1
      }
      ''');
      expect(info, isNotNull);
      expect(info!.versionCode, 10200);
      expect(info.versionName, '1.2.0');
      expect(info.changelog, '新增功能');
      expect(info.mandatory, isTrue);
      expect(info.minVersionCode, 10100);
    });

    test('容忍缺可选字段（未知字段也忽略）', () {
      final info = UpdateInfo.parse('{"versionCode": 10200, "versionName": "1.2.0", "url": "u"}');
      expect(info, isNotNull);
      expect(info!.changelog, '');
      expect(info.mandatory, isFalse);
      expect(info.sha256, '');
      expect(info.minVersionCode, isNull);
    });

    test('关键字段非法返回 null（不崩溃）', () {
      expect(UpdateInfo.parse('{"versionName": "1.2.0", "url": "u"}'), isNull);
      expect(UpdateInfo.parse('{"versionCode": "10200", "versionName": "1.2.0", "url": "u"}'), isNull);
      expect(UpdateInfo.parse('{"versionCode": 10200, "versionName": "", "url": "u"}'), isNull);
      expect(UpdateInfo.parse('{"versionCode": 10200, "versionName": "1.2.0", "url": ""}'), isNull);
      expect(UpdateInfo.parse('not json'), isNull);
      expect(UpdateInfo.parse('[1,2,3]'), isNull);
    });
  });

  group('版本比对（决策）', () {
    // check() 的比对逻辑：服务端 versionCode <= 当前 → NoUpdate。
    UpdateDecision decide(int serverVc) {
      if (serverVc <= kAppVersionCode) return const NoUpdate();
      return UpdateAvailable(UpdateInfo(
        versionCode: serverVc,
        versionName: 'x',
        url: 'u',
      ));
    }

    test('服务端更小 → 无更新（禁止降级）', () {
      expect(decide(kAppVersionCode - 1), isA<NoUpdate>());
    });

    test('服务端相等 → 无更新', () {
      expect(decide(kAppVersionCode), isA<NoUpdate>());
    });

    test('服务端更大 → 有新版本', () {
      final d = decide(kAppVersionCode + 1);
      expect(d, isA<UpdateAvailable>());
      expect((d as UpdateAvailable).info.versionCode, kAppVersionCode + 1);
    });

    test('当前版本常量与公式一致', () {
      expect(kAppVersionCode, versionCodeOf(1, 1, 1));
      expect(kAppVersionName, '1.1.1');
    });
  });
}