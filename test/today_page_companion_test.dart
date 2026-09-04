import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/companion/companion_service.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/journal/today_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> pumpTodayPage(WidgetTester tester, StorageService store,
      {AppState? state}) async {
    FlutterSecureStorage.setMockInitialValues({});
    final appState = state ?? await AppState.debug(store);
    await appState.bootstrap();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(home: Scaffold(body: TodayPage())),
      ),
    );
    await tester.pumpAndSettle();
    return appState;
  }

  testWidgets('成长卡首次记录前显示引导文案，不显示虚假成长天数', (tester) async {
    await pumpTodayPage(tester, _MapStorage({}));

    // 首屏伙伴区展示已确认的引导文案，不显示「一起留下了 0 天」。
    expect(find.text(CompanionService.preRecordCopy), findsOneWidget);
    expect(find.textContaining('一起留下了'), findsNothing);
    expect(find.textContaining('0 天'), findsNothing);

    // 点击伙伴展开成长卡。
    await tester.tap(find.text(CompanionService.preRecordCopy));
    await tester.pumpAndSettle();

    // 成长卡同样不显示「阶段 · 一起留下了 0 天」的虚假信息。
    expect(find.textContaining('一起留下了'), findsNothing);
    expect(find.textContaining('0 天'), findsNothing);
    // 卡片展示当前阶段小芽与引导文案（卡片 2 处 + 首屏 1 处）。
    expect(find.text('小芽'), findsWidgets);
    expect(find.text(CompanionService.preRecordCopy), findsWidgets);
  });

  testWidgets('每条成功保存都触发一次轻微舒展，同日重复保存也触发', (tester) async {
    await pumpTodayPage(tester, _MapStorage({}));

    // 第一次保存：动画进行中，缩放值离开 1.0。
    await tester.enterText(_inputField, '第一件小事');
    await tester.tap(find.text('保存并沉淀'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        tester.widget<ScaleTransition>(_stretch).scale.value, isNot(1.0),
        reason: '首次保存应触发舒展');
    await tester.pumpAndSettle();
    expect(tester.widget<ScaleTransition>(_stretch).scale.value, 1.0);
    // 关闭追问弹层。
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 第二次保存（同一天，counted=false）：仍触发舒展。
    await tester.enterText(_inputField, '第二件小事');
    await tester.tap(find.text('保存并沉淀'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        tester.widget<ScaleTransition>(_stretch).scale.value, isNot(1.0),
        reason: '同日重复保存也应触发舒展');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });

  testWidgets('保存已落盘但刷新失败：提示真实状态且不提供重复提交路径', (tester) async {
    final store = _MapStorage({});
    final state = await AppState.debug(store);
    await state.bootstrap();
    state.debugRefreshFault = () async => throw StateError('refresh boom');
    await pumpTodayPage(tester, store, state: state);

    await tester.enterText(_inputField, '这条已落盘');
    await tester.tap(find.text('保存并沉淀'));
    await tester.pumpAndSettle();

    // 提示真实状态而非普通成功。
    expect(find.text('已保存，但界面刷新失败，请稍后刷新查看'), findsOneWidget);
    // 数据确实只落盘一次，输入不恢复（避免重试造成重复 Entry）。
    final raw = jsonDecode(store.values['entries_v1']!) as List;
    expect(raw.length, 1);
    expect(tester.widget<TextField>(_inputField).controller!.text, isEmpty);
    state.debugRefreshFault = null;
  });

  testWidgets('保存失败且回滚未完成：提示状态不确定，不走普通重试路径', (tester) async {
    final store = _FlakyStorage(failOnWrite: {
      'companion_v1': 1, // 伙伴写入失败 → 触发补偿
      'entries_v1': 2, // 补偿删除失败 → 回滚未完成
    });
    final state = await AppState.debug(store);
    await state.bootstrap();
    await pumpTodayPage(tester, store, state: state);

    await tester.enterText(_inputField, '会半成功的内容');
    await tester.tap(find.text('保存并沉淀'));
    await tester.pumpAndSettle();

    // 明确提示状态不确定，而非「可重试」的普通保存失败。
    expect(find.text('保存状态不确定，请先刷新确认，暂不要重复提交'), findsOneWidget);
    expect(find.text('保存失败，请稍后重试'), findsNothing);
    // 不恢复输入（避免用户重复提交造成重复 Entry）。
    expect(tester.widget<TextField>(_inputField).controller!.text, isEmpty);
    // 数据已落盘：状态确实不确定。
    final raw = jsonDecode(store.values['entries_v1']!) as List;
    expect(raw.length, 1);
  });
}

Finder get _inputField => find.descendant(
    of: find.byType(TodayPage), matching: find.byType(TextField)).first;

Finder get _stretch => find.descendant(
    of: find.byType(TodayPage), matching: find.byType(ScaleTransition)).first;

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

/// 指定 key 在第 [failOnWrite[key]] 次写入时抛错，其余成功。
class _FlakyStorage implements StorageService {
  _FlakyStorage({required this.failOnWrite});

  final Map<String, int> failOnWrite;
  final Map<String, String> values = {};
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
