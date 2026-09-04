// 版本号映射测试：versionCode 公式与 SemVer 解析（与 scripts/bump-version.sh 保持一致）。
import 'package:daily_asking/core/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('versionCodeOf', () {
    test('三段映射公式 major*10000 + minor*100 + patch', () {
      expect(versionCodeOf(1, 0, 0), 10000);
      expect(versionCodeOf(1, 1, 0), 10100);
      expect(versionCodeOf(1, 2, 3), 10203);
      expect(versionCodeOf(2, 0, 0), 20000);
    });

    test('当前版本与 pubspec 同步（1.1.1+10101）', () {
      expect(kAppVersionName, '1.1.1');
      expect(kAppVersionCode, 10101);
      expect(versionCodeOf(1, 1, 1), kAppVersionCode);
    });

    test('单调递增：patch/minor/major 提升都会增大 versionCode', () {
      expect(versionCodeOf(1, 1, 1), greaterThan(versionCodeOf(1, 1, 0)));
      expect(versionCodeOf(1, 2, 0), greaterThan(versionCodeOf(1, 1, 9)));
      expect(versionCodeOf(2, 0, 0), greaterThan(versionCodeOf(1, 99, 99)));
    });
  });

  group('parseSemVer', () {
    test('合法三段', () {
      expect(parseSemVer('1.2.3'), [1, 2, 3]);
      expect(parseSemVer('0.0.1'), [0, 0, 1]);
    });

    test('非法返回 null', () {
      expect(parseSemVer('1.2'), isNull);
      expect(parseSemVer('1.2.3.4'), isNull);
      expect(parseSemVer('a.b.c'), isNull);
      expect(parseSemVer('1.x.3'), isNull);
      expect(parseSemVer(''), isNull);
    });
  });
}