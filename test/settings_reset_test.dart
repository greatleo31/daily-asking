import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('设置页重置伙伴：明确二次确认，清空伙伴且证据不受影响', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final entry = Entry(
      id: 'e_seed',
      date: DateTime(2026, 8, 20),
      task: '种子证据',
      createdAt: DateTime(2026, 8, 20, 9),
      updatedAt: DateTime(2026, 8, 20, 9),
    );
    final store = _MapStorage({
      'entries_v1': jsonEncode([entry.toJson()]),
      'companion_v1': jsonEncode({
        'name': '小芽',
        'countedDates': ['2026-08-20'],
        'milestoneDates': {'1': '2026-08-20'},
      }),
    });
    final state = await AppState.debug(store);
    await state.bootstrap();
    expect(state.companion.name, '小芽');

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: Scaffold(body: SettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 首次点击 → 二次确认对话框。
    await tester.tap(find.text('重置伙伴成长'));
    await tester.pumpAndSettle();
    expect(find.text('重置伙伴成长？'), findsOneWidget);

    // 取消：不重置。
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(state.companion.name, '小芽');
    expect(state.companion.growthDays, 1);

    // 再次进入并确认重置。
    await tester.tap(find.text('重置伙伴成长'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认重置'));
    await tester.pumpAndSettle();

    expect(state.companion.name, isNull);
    expect(state.companion.growthDays, 0);
    expect(state.companion.celebratedMilestones, isEmpty);
    // 证据数据保持不变。
    expect(state.allEntries.length, 1);
    expect(state.allEntries.single.task, '种子证据');
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
