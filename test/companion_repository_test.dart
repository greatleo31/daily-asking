import 'dart:convert';

import 'package:daily_asking/companion/companion_profile.dart';
import 'package:daily_asking/companion/companion_repository.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalCompanionRepository', () {
    test('无数据时加载为空资料', () async {
      final repo = LocalCompanionRepository(JsonStore(_MapStorage({})));
      final p = await repo.load();
      expect(p.growthDays, 0);
      expect(p.name, isNull);
      expect(p.celebratedMilestones, isEmpty);
    });

    test('保存后可加载回同一资料（companion_v1 读写）', () async {
      final storage = _MapStorage({});
      final repo = LocalCompanionRepository(JsonStore(storage));
      final p = CompanionProfile.sealed(
        name: '小芽',
        countedDates: {'2026-08-26', '2026-08-27'},
        lastQuoteDate: '2026-08-27',
        quoteRerolls: {'2026-08-27': 1},
        milestoneDates: {1: '2026-08-26', 7: '2026-08-27'},
      );
      await repo.save(p);
      expect(storage.values, contains('companion_v1'));

      final back = await repo.load();
      expect(back.name, '小芽');
      expect(back.countedDates, {'2026-08-26', '2026-08-27'});
      expect(back.celebratedMilestones, [1, 7]);
      expect(back.milestoneDates, {1: '2026-08-26', 7: '2026-08-27'});
      expect(back.lastQuoteDate, '2026-08-27');
      expect(back.quoteRerolls, {'2026-08-27': 1});
    });

    test('未知字段忽略、缺失字段按默认值兼容', () async {
      final storage = _MapStorage({
        'companion_v1': jsonEncode({
          'name': '芽',
          'unknownField': 'ignored',
          'countedDates': ['2026-08-01', 'bad-date'],
          'milestoneDates': {'1': '2026-08-01', '99': '2026-08-02', '7': 'bad'},
        }),
      });
      final repo = LocalCompanionRepository(JsonStore(storage));
      final p = await repo.load();
      expect(p.name, '芽');
      expect(p.countedDates, {'2026-08-01'});
      expect(p.milestoneDates, {1: '2026-08-01'}); // 99 非节点、7 非法日期被过滤
      expect(p.celebratedMilestones, [1]);
      expect(p.lastQuoteDate, isNull);
      expect(p.quoteRerolls, isEmpty);
    });

    test('旧版本 celebratedMilestones 字段迁移加载', () async {
      final storage = _MapStorage({
        'companion_v1': jsonEncode({
          'celebratedMilestones': [1, 7],
        }),
      });
      final repo = LocalCompanionRepository(JsonStore(storage));
      final p = await repo.load();
      expect(p.celebratedMilestones, [1, 7]); // 保持"已展示"标记，不重复提示
      expect(p.milestoneDates, {1: null, 7: null}); // 无触发日期
    });

    test('保存的 JSON 双写节点字段（旧版本降级仍可读）', () async {
      final storage = _MapStorage({});
      final repo = LocalCompanionRepository(JsonStore(storage));
      await repo.save(CompanionProfile.sealed(
        countedDates: {'2026-08-01'},
        milestoneDates: {1: '2026-08-01'},
      ));
      final raw =
          jsonDecode(storage.values['companion_v1']!) as Map<String, dynamic>;
      expect(raw['celebratedMilestones'], [1]);
      expect(raw['milestoneDates'], {'1': '2026-08-01'});
    });

    test('存储值非对象（如 JSON 数组）时回退空资料', () async {
      final storage = _MapStorage({'companion_v1': '[]'});
      final repo = LocalCompanionRepository(JsonStore(storage));
      final p = await repo.load();
      expect(p.growthDays, 0);
      expect(p.name, isNull);
    });

    test('reset 移除存储键，加载回到空资料', () async {
      final storage = _MapStorage({
        'companion_v1': jsonEncode({'name': '芽', 'countedDates': ['2026-08-01']}),
      });
      final repo = LocalCompanionRepository(JsonStore(storage));
      expect((await repo.load()).growthDays, 1);
      await repo.reset();
      expect(storage.values, isNot(contains('companion_v1')));
      expect((await repo.load()).growthDays, 0);
    });
  });
}

class _MapStorage implements StorageService {
  _MapStorage(this.values);

  final Map<String, String> values;

  @override
  Future<String?> readString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }
}
