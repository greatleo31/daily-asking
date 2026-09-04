import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/app/shell.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/evidence/evidence_detail_page.dart';
import 'package:daily_asking/evidence/evidence_page.dart';
import 'package:daily_asking/journal/today_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('底栏标签为记录，今日占位为请输入精简概括', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final state = await AppState.debug(_MapStorage({}));
    await state.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('记录'), findsWidgets);
    expect(find.text('证据'), findsNothing);
    expect(find.text('请输入精简概括'), findsOneWidget);

    // AppShell 启动后有 4s 自动检查更新的 Timer，冲掉以免测试结束断言失败。
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('今日已沉淀显示单行条数文案', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final now = DateTime.now();
    final entry = Entry(
      id: 'e_today',
      date: DateTime(now.year, now.month, now.day),
      task: '写一条测试记录',
      createdAt: now,
      updatedAt: now,
    );
    final state = await AppState.debug(_MapStorage({
      'entries_v1': jsonEncode([entry.toJson()]),
    }));
    await state.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: TodayPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日已沉淀 1 条记录'), findsOneWidget);
    expect(find.text('今日已沉淀'), findsNothing);
    expect(find.text('条证据'), findsNothing);
  });
  testWidgets('今日记录列表卡不显示完整度小字且圆内可见百分比', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final now = DateTime.now();
    final entry = Entry(
      id: 'e_full',
      date: DateTime(now.year, now.month, now.day),
      task: '圆标百分比测试',
      context: '背景已填',
      action: '行动已填',
      result: '结果已填',
      blocker: '难点已填',
      createdAt: now,
      updatedAt: now,
    );
    final state = await AppState.debug(_MapStorage({
      'entries_v1': jsonEncode([entry.toJson()]),
    }));
    await state.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: TodayPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('完整度 '), findsNothing);
    expect(find.text('完整度 100%'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CircleAvatar),
        matching: find.text('100%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('记录列表卡左侧圆标仅显示百分比且无完整度小字', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final now = DateTime(2026, 9, 3, 12);
    final entry = Entry(
      id: 'e_list_full',
      date: DateTime(2026, 9, 3),
      task: '记录列表圆标测试',
      context: '背景',
      action: '行动',
      result: '结果',
      blocker: '难点',
      tags: const ['测试'],
      createdAt: now,
      updatedAt: now,
    );
    final state = await AppState.debug(_MapStorage({
      'entries_v1': jsonEncode([entry.toJson()]),
    }));
    await state.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: EvidencePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('完整度 '), findsNothing);
    expect(find.text('完整度 100%'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CircleAvatar),
        matching: find.text('100%'),
      ),
      findsOneWidget,
    );
    expect(find.text('记录列表圆标测试'), findsOneWidget);
  });

  testWidgets('待补充卡以种类短名为标题，右侧显示已答/待补充状态', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final now = DateTime(2026, 9, 3, 12);
    const promptAnswered = '这件事发生在什么背景 / 场景下？';
    const promptPending = '你具体做了哪一步？';
    final entry = Entry(
      id: 'e_pending_tile',
      date: DateTime(2026, 9, 3),
      task: '切片二测试记录',
      createdAt: now,
      updatedAt: now,
    );
    final answered = EvidenceQuestion(
      id: 'q_answered',
      entryId: entry.id,
      kind: QuestionKind.context,
      prompt: promptAnswered,
      reason: '背景',
      status: QuestionStatus.answered,
      createdAt: now,
      updatedAt: now,
    );
    final pending = EvidenceQuestion(
      id: 'q_pending',
      entryId: entry.id,
      kind: QuestionKind.action,
      prompt: promptPending,
      reason: '行动',
      status: QuestionStatus.pending,
      createdAt: now.add(const Duration(minutes: 1)),
      updatedAt: now.add(const Duration(minutes: 1)),
    );
    final state = await AppState.debug(_MapStorage({
      'entries_v1': jsonEncode([entry.toJson()]),
      'questions_v1': jsonEncode([answered.toJson(), pending.toJson()]),
    }));
    await state.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: EvidenceDetailPage(entryId: entry.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 主标题为种类短名（ListTile title），而非完整追问句。
    // 详情页字段分区也有「背景」「具体行动」标题，故用 ListTile 限定。
    expect(find.widgetWithText(ListTile, '背景'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '具体行动'), findsOneWidget);
    expect(find.text(promptAnswered), findsNothing);
    expect(find.text(promptPending), findsNothing);

    // 右侧状态文案。
    expect(find.text('已答'), findsOneWidget);
    expect(find.text('待补充'), findsAtLeastNWidgets(2)); // 分区标题 + 状态框

    // 旧的「种类 · 状态」副标题不应再出现。
    expect(find.textContaining('· 已答'), findsNothing);
    expect(find.textContaining('· 待补充'), findsNothing);
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
