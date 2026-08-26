import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/companion/companion_profile.dart';
import 'package:daily_asking/companion/companion_service.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = CompanionService();
  final todayKey = service.normalizeDate(DateTime.now());

  group('AppState 伙伴域边界', () {
    test('bootstrap 加载已持久化的伙伴资料', () async {
      final state = await _debugState({
        'companion_v1': jsonEncode({
          'name': '小芽',
          'countedDates': ['2026-08-01'],
          'celebratedMilestones': [1],
        }),
      });
      await state.bootstrap();
      expect(state.companion.name, '小芽');
      expect(state.companion.growthDays, 1);
      expect(state.companionStage, CompanionStage.sprout);
    });

    test('saveQuickToday 成功：成长 +1、触发节点 1、资料持久化', () async {
      final store = _MapStorage({});
      final state = await _debugStateWith(store);
      await state.bootstrap();

      await state.saveQuickToday('今天给同事做了 SQL 培训');

      expect(state.companion.growthDays, 1);
      expect(state.lastCompanionEvent?.counted, isTrue);
      expect(state.lastCompanionEvent?.milestone, 1);
      expect(state.lastCompanionEvent?.quoteIsNode, isTrue);
      expect(state.allEntries.length, 1);

      // 重新构造 AppState 后仍能读到同一伙伴资料（持久化生效）。
      final reloaded = await _debugStateWith(store);
      await reloaded.bootstrap();
      expect(reloaded.companion.growthDays, 1);
      expect(reloaded.companion.celebratedMilestones, contains(1));
      expect(reloaded.companion.milestoneDates[1], todayKey);
    });

    test('同一天多次保存不重复成长', () async {
      final state = await _debugState({});
      await state.bootstrap();
      await state.saveQuickToday('第一件事');
      await state.saveQuickToday('第二件事');
      await state.saveQuickToday('第三件事');
      expect(state.companion.growthDays, 1);
    });

    test('updateEntry 补写历史日期计入一次且不重复', () async {
      final state = await _debugState({});
      await state.bootstrap();
      await state.saveQuickToday('今天的记录');

      final backfill = Entry(
        id: 'e_backfill',
        date: DateTime(2026, 8, 1),
        task: '补写的历史小事',
        createdAt: DateTime(2026, 8, 1, 9),
        updatedAt: DateTime(2026, 8, 1, 9),
      );
      await state.updateEntry(backfill);
      expect(state.companion.growthDays, 2);

      // 同一历史日期再次更新（编辑字段）不重复计入。
      final again = backfill.copy()..action = '补充细节';
      await state.updateEntry(again);
      expect(state.companion.growthDays, 2);
    });

    test('updateEntry 空任务不计成长（无效记录）', () async {
      final state = await _debugState({});
      await state.bootstrap();
      await state.updateEntry(Entry(
        id: 'e_empty',
        date: DateTime.now(),
        task: '   ',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      expect(state.companion.growthDays, 0);
    });

    test('deleteEntry 不回退伙伴成长，只按既有规则删除证据', () async {
      final state = await _debugState({});
      await state.bootstrap();
      await state.saveQuickToday('今天的记录');
      final backfill = Entry(
        id: 'e_backfill',
        date: DateTime(2026, 8, 1),
        task: '补写的历史小事',
        createdAt: DateTime(2026, 8, 1, 9),
        updatedAt: DateTime(2026, 8, 1, 9),
      );
      await state.updateEntry(backfill);
      expect(state.companion.growthDays, 2);

      await state.deleteEntry('e_backfill');

      expect(state.companion.growthDays, 2); // 删除不回退
      expect(state.companionStage, CompanionStage.sprout); // 阶段保持
      expect(state.allEntries.length, 1); // 证据按既有规则删除
    });

    test('补写历史日期触发节点：本次事件给节点语录，触发日期被持久化', () async {
      final dates = [for (var i = 1; i <= 6; i++) '2026-08-0$i'];
      final state = await _debugState({
        'companion_v1': jsonEncode({'countedDates': dates}),
      });
      await state.bootstrap();

      final backfill = Entry(
        id: 'e_bf',
        date: DateTime(2026, 7, 31),
        task: '补写触发节点',
        createdAt: DateTime(2026, 7, 31),
        updatedAt: DateTime(2026, 7, 31),
      );
      await state.updateEntry(backfill);

      expect(state.companion.growthDays, 7);
      expect(state.lastCompanionEvent?.milestone, 7);
      expect(state.lastCompanionEvent?.quoteIsNode, isTrue);
      expect(state.lastCompanionEvent?.quote, isNotNull);
      expect(state.companion.milestoneDates[7], '2026-07-31');
      // 今天（未计入）不是节点达成日，卡片展示普通日语录。
      expect(state.companionQuoteIsNode, isFalse);
      expect(state.companionCanReroll, isFalse); // 今天未计入
    });

    test('证据写入失败：异常向 UI 抛出且伙伴状态不变', () async {
      final store = _ThrowingStorage({'entries_v1'});
      final state = await _debugStateWith(store);
      await state.bootstrap();

      var threw = false;
      try {
        await state.saveQuickToday('这条会保存失败');
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue);
      expect(state.companion.growthDays, 0);
      expect(state.lastCompanionEvent?.counted, isNull);
    });

    test('追问写入失败：回滚已写 Entry/追问并抛出', () async {
      final store = _ThrowingStorage({'questions_v1'});
      final state = await _debugStateWith(store);
      await state.bootstrap();

      var threw = false;
      try {
        await state.saveQuickToday('追问写入失败');
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue);
      expect(state.allEntries, isEmpty); // 已写 Entry 被回滚
      expect(state.todayEntries, isEmpty);
      expect(state.companion.growthDays, 0);
    });

    test('补偿回滚失败不静默吞掉：抛出 SaveRollbackIncomplete 且快照刷新', () async {
      // entries_v1 与 companion_v1 都写失败：保存失败且回滚写入也失败。
      final store = _ThrowingStorage({'entries_v1', 'companion_v1'});
      final state = await _debugStateWith(store);
      await state.bootstrap();

      Object? caught;
      try {
        await state.saveQuickToday('保存与回滚都会失败');
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<SaveRollbackIncomplete>());
      expect((caught as SaveRollbackIncomplete).isNewEntry, isTrue);
      expect(state.companion.growthDays, 0);
    });

    test('Entry 已落盘但删除补偿失败：SaveRollbackIncomplete，数据已持久化', () async {
      final store = _FlakyStorage(failOnWrite: {
        'companion_v1': 1, // 伙伴写入第 1 次失败 → 触发补偿
        'entries_v1': 2, // 补偿删除（entries 第 2 次写）失败 → 回滚未完成
      });
      final state = await _debugStateWith(store);
      await state.bootstrap();

      Object? caught;
      try {
        await state.saveQuickToday('落盘但回滚失败');
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<SaveRollbackIncomplete>());
      expect((caught as SaveRollbackIncomplete).isNewEntry, isTrue);
      // 数据确实已落盘（状态不确定）：不能当作可安全重试的失败。
      final raw = jsonDecode(store.values['entries_v1']!) as List;
      expect(raw.length, 1);
      expect(state.companion.growthDays, 0);
    });

    test('updateEntry 已落盘但恢复补偿失败：SaveRollbackIncomplete(isNewEntry:false)', () async {
      final a = Entry(
        id: 'e_a',
        date: DateTime(2026, 8, 1),
        task: 'A 原始',
        createdAt: DateTime(2026, 8, 1, 9),
        updatedAt: DateTime(2026, 8, 1, 9),
      );
      final store = _FlakyStorage(
        failOnWrite: {
          'companion_v1': 1, // 伙伴写入第 1 次失败 → 触发补偿
          'entries_v1': 2, // 补偿恢复（entries 第 2 次写）失败 → 回滚未完成
        },
        seed: {'entries_v1': jsonEncode([a.toJson()])},
      );
      final state = await _debugStateWith(store);
      await state.bootstrap();

      Object? caught;
      try {
        await state.updateEntry(a.copy()..task = 'A 已编辑');
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<SaveRollbackIncomplete>());
      expect((caught as SaveRollbackIncomplete).isNewEntry, isFalse);
    });

    test('持久化成功但刷新失败：抛出 SaveSucceededButRefreshFailed 且数据已落盘', () async {
      final store = _MapStorage({});
      final state = await _debugStateWith(store);
      await state.bootstrap();
      state.debugRefreshFault = () async => throw StateError('refresh boom');

      Object? caught;
      try {
        await state.saveQuickToday('已落盘但刷新失败');
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<SaveSucceededButRefreshFailed>());
      // 数据确实已持久化：不能当作可安全重试的失败。
      final raw = jsonDecode(store.values['entries_v1']!) as List;
      expect(raw.length, 1);
      expect(state.companion.growthDays, 1); // 伙伴状态已推进
      // 刷新失败不影响补偿语义：异常不是补偿错误。
      expect((caught as SaveSucceededButRefreshFailed).cause, isA<StateError>());
      state.debugRefreshFault = null;
    });

    test('updateEntry 持久化成功但刷新失败：抛出 SaveSucceededButRefreshFailed', () async {
      final store = _MapStorage({});
      final state = await _debugStateWith(store);
      await state.bootstrap();
      final entry = Entry(
        id: 'e_upd',
        date: DateTime(2026, 8, 1),
        task: '更新内容',
        createdAt: DateTime(2026, 8, 1, 9),
        updatedAt: DateTime(2026, 8, 1, 9),
      );
      await state.updateEntry(entry);
      expect(state.companion.growthDays, 1);

      state.debugRefreshFault = () async => throw StateError('refresh boom');
      Object? caught;
      try {
        await state.updateEntry(entry.copy()..task = '更新后的内容');
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<SaveSucceededButRefreshFailed>());
      // 更新确实已持久化。
      final raw = jsonDecode(store.values['entries_v1']!) as List;
      expect((raw.single as Map)['task'], '更新后的内容');
      state.debugRefreshFault = null;
    });

    test('伙伴写入失败：回滚本次 Entry/追问并抛出，重试后可完整保存', () async {
      final store = _FlakyStorage(failOnWrite: {'companion_v1': 1});
      final state = await _debugStateWith(store);
      await state.bootstrap();

      var threw = false;
      try {
        await state.saveQuickToday('第一次（伙伴写失败）');
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue);
      expect(state.companion.growthDays, 0); // 伙伴不随半成功推进
      expect(state.allEntries, isEmpty); // 已落盘 Entry 被回滚
      expect(state.todayEntries, isEmpty);

      // 重试（存储恢复）后完整成功，成长只计一次。
      await state.saveQuickToday('重试成功');
      expect(state.allEntries.length, 1);
      expect(state.companion.growthDays, 1);
    });

    test('updateEntry 伙伴写入失败：回滚本次更新，重试后成功', () async {
      // 迁移场景：旧版本已有两条从未计入伙伴成长的 Entry。
      final a = Entry(
        id: 'e_a',
        date: DateTime(2026, 8, 1),
        task: 'A 原始',
        createdAt: DateTime(2026, 8, 1, 9),
        updatedAt: DateTime(2026, 8, 1, 9),
      );
      final b = Entry(
        id: 'e_b',
        date: DateTime(2026, 8, 2),
        task: 'B 原始',
        createdAt: DateTime(2026, 8, 2, 9),
        updatedAt: DateTime(2026, 8, 2, 9),
      );
      final store = _FlakyStorage(
        failOnWrite: {'companion_v1': 2}, // 第 2 次伙伴写入失败
        seed: {'entries_v1': jsonEncode([a.toJson(), b.toJson()])},
      );
      final state = await _debugStateWith(store);
      await state.bootstrap();

      await state.updateEntry(a.copy()..task = 'A 已编辑'); // 补写 08-01，写 #1 成功
      expect(state.companion.growthDays, 1);

      // 编辑 B（补写 08-02）→ 伙伴写入 #2 失败 → B 的更新被回滚。
      var threw = false;
      try {
        await state.updateEntry(b.copy()..task = 'B 已编辑');
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue);
      expect(state.allEntries.firstWhere((e) => e.id == 'e_b').task, 'B 原始');
      expect(state.companion.growthDays, 1);

      // 重试成功：B 更新生效，08-02 计入成长。
      await state.updateEntry(b.copy()..task = 'B 已编辑');
      expect(state.allEntries.firstWhere((e) => e.id == 'e_b').task, 'B 已编辑');
      expect(state.companion.growthDays, 2);
    });

    test('resetCompanion 只清空伙伴资料，证据数据保持不变', () async {
      final state = await _debugState({});
      await state.bootstrap();
      await state.saveQuickToday('今天的记录');
      expect(state.companion.growthDays, 1);

      await state.resetCompanion();

      expect(state.companion.growthDays, 0);
      expect(state.companion.name, isNull);
      expect(state.companion.celebratedMilestones, isEmpty);
      expect(state.allEntries.length, 1); // 证据不受影响
    });

    test('setCompanionName 合法名称生效，非法名称返回错误且不改变资料', () async {
      final state = await _debugState({});
      await state.bootstrap();

      final error = await state.setCompanionName('小芽');
      expect(error, isNull);
      expect(state.companion.name, '小芽');

      final bad = await state.setCompanionName('一二三四五六七八九');
      expect(bad, isNotNull);
      expect(state.companion.name, '小芽');
    });

    test('先换句再保存：换句被拒绝，首次保存仍产生普通语录', () async {
      final state = await _debugState({
        'companion_v1': jsonEncode({
          'countedDates': ['2026-08-01', '2026-08-02'],
        }),
      });
      await state.bootstrap();

      expect(state.companionCanReroll, isFalse); // 今天未计入，不可换句
      final rr = await state.rerollCompanionQuote();
      expect(rr.changed, isFalse);

      await state.saveQuickToday('今天的记录');
      expect(state.lastCompanionEvent?.quote, isNotNull); // 普通语录未被吞掉
      expect(state.lastCompanionEvent?.quoteIsNode, isFalse);
    });

    test('普通日语录换句有限次，节点日不可换句', () async {
      // 今天已计入且今天出过语录：growth=2，普通日，可有限换句。
      final state = await _debugState({
        'companion_v1': jsonEncode({
          'countedDates': [todayKey, '2026-08-01'],
          'lastQuoteDate': todayKey,
        }),
      });
      await state.bootstrap();
      expect(state.companionCanReroll, isTrue);

      final before = state.companionQuote;
      final r1 = await state.rerollCompanionQuote();
      expect(r1.changed, isTrue);
      expect(state.companionQuote, isNot(before));

      final r2 = await state.rerollCompanionQuote();
      expect(r2.changed, isTrue);

      final r3 = await state.rerollCompanionQuote();
      expect(r3.changed, isFalse);
      expect(state.companionCanReroll, isFalse);
      expect(state.companionQuoteIsNode, isFalse);

      // 节点达成日：今天首次记录即节点 1，不可换句。
      final nodeState = await _debugState({});
      await nodeState.bootstrap();
      await nodeState.saveQuickToday('首条记录');
      expect(nodeState.companionQuoteIsNode, isTrue);
      expect(nodeState.companionCanReroll, isFalse);
      final rr = await nodeState.rerollCompanionQuote();
      expect(rr.changed, isFalse);
    });
  });
}

Future<AppState> _debugState(Map<String, String> values) async =>
    _debugStateWith(_MapStorage(values));

Future<AppState> _debugStateWith(StorageService store) async {
  FlutterSecureStorage.setMockInitialValues({});
  return AppState.debug(store);
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

/// 指定 key 写入时抛错，模拟持久化失败。
class _ThrowingStorage implements StorageService {
  _ThrowingStorage(this._failingKeys);

  final Set<String> _failingKeys;
  final Map<String, String> _values = {};

  @override
  Future<String?> readString(String key) async => _values[key];

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    if (_failingKeys.contains(key)) {
      throw StateError('模拟写入失败: $key');
    }
    _values[key] = value;
  }
}

/// 指定 key 在第 [failOnWrite[key]] 次写入时抛错，其余成功（用于重试场景）。
class _FlakyStorage implements StorageService {
  _FlakyStorage({
    required this.failOnWrite,
    Map<String, String>? seed,
  }) : values = {...?seed};

  final Map<String, int> failOnWrite;
  final Map<String, String> values;
  final Map<String, int> _writes = {};

  @override
  Future<String?> readString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    final n = (_writes[key] ?? 0) + 1;
    _writes[key] = n;
    final failAt = failOnWrite[key];
    if (failAt != null && n == failAt) {
      throw StateError('模拟写入失败: $key');
    }
    values[key] = value;
  }
}
