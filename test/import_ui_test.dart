import 'dart:async';
import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/artifacts/generation_waiting_overlay.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/core/transfer/data_transfer_service.dart';
import 'package:daily_asking/core/transfer/file_pick_service.dart';
import 'package:daily_asking/core/transfer/import_plan.dart';
import 'package:daily_asking/core/transfer/transfer_schema.dart';
import 'package:daily_asking/core/transfer/transfer_partition.dart';
import 'package:daily_asking/settings/import_preview_page.dart';
import 'package:daily_asking/settings/import_result_page.dart';
import 'package:daily_asking/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

ImportPlan _plan({int count = 1, List<ImportIssue> issues = const []}) {
  final entries = List.generate(
    count,
    (i) => Entry(
      id: 'e_$i',
      date: DateTime(2020),
      task: '记录 $i',
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    ),
  );
  return ImportPlan(
    parsed: const ParsedImport(),
    entries: entries,
    questions: const [],
    answers: const [],
    skipped: 2,
    issues: issues,
    incompleteCount: count,
    legacyCount: 0,
    ignoredLines: 0,
    details: [
      for (var i = 0; i < entries.length; i++)
        ImportDetail(
          source: '历史.md',
          index: i + 1,
          disposition: ImportDisposition.added,
          label: '明细 $i',
          reason: '',
        ),
      for (final issue in issues)
        ImportDetail(
          source: issue.source,
          index: issue.index,
          disposition: ImportDisposition.invalid,
          label: '无法导入',
          reason: issue.reason,
        ),
    ],
  );
}

ImportResult _result(ImportPlan plan, {String? warning}) => ImportResult(
  plan: plan,
  importedCount: plan.addedCount,
  incompleteCount: plan.incompleteCount,
  legacyCount: 1,
  skippedCount: plan.skippedCount,
  failedCount: plan.invalidCount,
  issues: plan.issues,
  storageWarning: warning,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('预览固定损失提示、三个数字，明细最多渲染 50 项', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ImportPreviewPage(plan: _plan(count: 55))),
    );
    expect(find.text(ImportPreviewPage.markdownWarning), findsOneWidget);
    expect(find.text('将新增 55 条 · 已存在跳过 2 条 · 无法导入 0 项'), findsOneWidget);
    expect(find.text('明细 0'), findsNothing);
    await tester.tap(find.text('查看明细（共 55 项）'));
    await tester.pumpAndSettle();
    expect(find.text('仅显示前 50 项，共 55 项'), findsOneWidget);
    expect(
      find.textContaining('新增 · 明细', skipOffstage: false),
      findsNWidgets(50),
    );
    expect(find.text('新增 · 明细 49', skipOffstage: false), findsOneWidget);
    expect(find.text('新增 · 明细 50', skipOffstage: false), findsNothing);
  });

  const reasons = [
    '文件编码不是 UTF-8',
    '文件超过 10 MB',
    '文件包含超过 5000 条记录',
    '文件来自更新版本的留痕，请先升级 App',
    '无法识别的文件格式',
  ];
  for (final reason in reasons) {
    testWidgets('预览明确显示拒绝原因：$reason', (tester) async {
      final plan = _plan(
        count: 0,
        issues: [ImportIssue(source: '导入文件', index: 0, reason: reason)],
      );
      await tester.pumpWidget(MaterialApp(home: ImportPreviewPage(plan: plan)));
      expect(find.text('将新增 0 条 · 已存在跳过 2 条 · 无法导入 1 项'), findsOneWidget);
      await tester.tap(find.text('查看明细（共 1 项）'));
      await tester.pumpAndSettle();
      expect(find.textContaining(reason), findsOneWidget);
    });
  }

  testWidgets('结果说明不完整、旧格式、失败与存储警告，点击后关闭页面', (tester) async {
    final plan = _plan(
      issues: const [
        ImportIssue(source: '旧文件.json', index: 3, reason: '任务字段非法'),
      ],
    );
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('设置底页')),
      ),
    );
    final returned = navigator.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) => ImportResultPage(
          result: _result(plan, warning: '部分数据可能已保存，未自动回滚。'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已导入 1 条 · 跳过 2 条 · 失败 1 项'), findsOneWidget);
    expect(find.textContaining('其中 1 条为不完整解析'), findsOneWidget);
    expect(find.text('其中 1 条来自旧格式'), findsOneWidget);
    expect(find.text('任务字段非法'), findsOneWidget);
    expect(find.text('部分数据可能已保存，未自动回滚。'), findsOneWidget);
    await tester.tap(find.text('查看导入的记录'));
    await tester.pumpAndSettle();
    expect(await returned, isTrue);
    expect(find.text('设置底页'), findsOneWidget);
  });

  testWidgets('多文件准备与执行全程挡返回，确认后才执行，结果按钮回调切记录', (tester) async {
    final service = _FakeTransfer();
    final picker = _FakePicker();
    var viewed = false;
    await _settings(tester, service, picker, onView: () => viewed = true);
    await tester.ensureVisible(find.text('导入记录'));
    await tester.tap(find.text('导入记录'));
    await tester.pump();
    await tester.pump();
    expect(service.received?.length, 2);
    expect(find.byType(GenerationWaitingOverlay), findsOneWidget);
    await tester.pump(kCompanionSceneLoop + kWaitingHintFadeIn);
    await tester.binding.handlePopRoute();
    await tester.tap(find.byType(GenerationWaitingOverlay));
    await tester.pump();
    expect(find.byType(GenerationWaitingOverlay), findsOneWidget);
    expect(service.executeCalls, 0);
    service.prepared.complete(_plan());
    await tester.pumpAndSettle();
    expect(find.byType(ImportPreviewPage), findsOneWidget);
    await tester.tap(find.text('确认导入'));
    await tester.pump();
    await tester.pump();
    expect(service.executeCalls, 1);
    await tester.pump(kCompanionSceneLoop + kWaitingHintFadeIn);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(GenerationWaitingOverlay), findsOneWidget);
    service.executed.complete(_result(_plan()));
    await tester.pumpAndSettle();
    expect(viewed, isFalse);
    expect(find.byType(ImportResultPage), findsOneWidget);
    await tester.tap(find.text('查看导入的记录'));
    await tester.pumpAndSettle();
    expect(viewed, isTrue);
    expect(find.byType(ImportResultPage), findsNothing);
    expect(find.text('上次自动备份：2026-09-17 12:30'), findsOneWidget);
  });

  testWidgets('取消预览不执行导入，取消文件选择不打开预览', (tester) async {
    final service = _FakeTransfer()..prepared.complete(_plan());
    final picker = _FakePicker();
    await _settings(tester, service, picker);
    await tester.ensureVisible(find.text('导入记录'));
    await tester.tap(find.text('导入记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(service.executeCalls, 0);
    picker.cancel = true;
    await tester.tap(find.text('导入记录'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportPreviewPage), findsNothing);
    expect(find.byType(GenerationWaitingOverlay), findsNothing);
    expect(service.executeCalls, 0);
  });

  testWidgets('设置导出使用 JSON 文件名并提示全部记录与谨慎分享', (tester) async {
    const channel = MethodChannel('com.dailyasking.daily_asking/export');
    MethodCall? shared;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      shared = call;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await _settings(tester, _FakeTransfer(), _FakePicker());
    await tester.ensureVisible(find.text('导出数据（可再导入）'));
    await tester.tap(find.text('导出数据（可再导入）'));
    await tester.pumpAndSettle();
    expect(shared?.method, 'shareMarkdown');
    expect((shared!.arguments as Map)['fileName'], endsWith('.json'));
    expect(find.text('文件含你的全部记录（0 条），请谨慎分享'), findsOneWidget);
  });

  testWidgets('超过 5000 条一次分享全部分片，提示使用实际快照条数', (tester) async {
    const channel = MethodChannel('com.dailyasking.daily_asking/export');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final storage = _MemoryStorage();
    await _settings(tester, _FakeTransfer(), _FakePicker(), storage: storage);
    // 页面仍缓存空库；导出必须重新读取存储，并从实际内容计算条数。
    storage.values['entries_v1'] = jsonEncode(
      _plan(count: 5001).entries.map((e) => e.toJson()).toList(),
    );
    await tester.ensureVisible(find.text('导出数据（可再导入）'));
    await tester.tap(find.text('导出数据（可再导入）'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single.method, 'shareFiles');
    final files = (calls.single.arguments as Map)['files'] as List;
    expect(files, hasLength(2));
    expect((files[0] as Map)['fileName'], endsWith('-part-001-of-002.json'));
    expect((files[1] as Map)['fileName'], endsWith('-part-002-of-002.json'));
    final sizes = files.map(
      (file) =>
          ((jsonDecode((file as Map)['content'] as String) as Map)['entries']
                  as List)
              .length,
    );
    expect(sizes, [5000, 1]);
    expect(
      find.text('文件含你的全部记录（5001 条），请谨慎分享。共 2 个文件，完整迁移请全部导入'),
      findsOneWidget,
    );
  });

  testWidgets('单个记录组超限明确提示原因且不调用原生分享', (tester) async {
    const channel = MethodChannel('com.dailyasking.daily_asking/export');
    var shareCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      shareCalls++;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final storage = _MemoryStorage();
    await _settings(tester, _FakeTransfer(), _FakePicker(), storage: storage);
    final entry = _plan().entries.single.toJson();
    entry['task'] = 'x' * maxTransferFileBytes;
    storage.values['entries_v1'] = jsonEncode([entry]);
    await tester.ensureVisible(find.text('导出数据（可再导入）'));
    await tester.tap(find.text('导出数据（可再导入）'));
    await tester.pumpAndSettle();
    expect(shareCalls, 0);
    expect(find.text('单条记录及其追问回答超过 10 MB，无法分片导出'), findsOneWidget);
    expect(find.text('导出失败，请重试'), findsNothing);
  });

  testWidgets('意外错误只显示简短提示且收起蒙层', (tester) async {
    final service = _FakeTransfer();
    await _settings(tester, service, _FakePicker());
    await tester.ensureVisible(find.text('导入记录'));
    await tester.tap(find.text('导入记录'));
    await tester.pump();
    await tester.pump();
    service.prepared.completeError(StateError('敏感正文不应显示'));
    await tester.pumpAndSettle();
    expect(find.text('导入未完成，请重试'), findsOneWidget);
    expect(find.textContaining('敏感正文'), findsNothing);
    expect(find.byType(GenerationWaitingOverlay), findsNothing);
  });
}

Future<void> _settings(
  WidgetTester tester,
  _FakeTransfer service,
  _FakePicker picker, {
  VoidCallback? onView,
  _MemoryStorage? storage,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final state = await AppState.debug(storage ?? _MemoryStorage());
  await state.bootstrap();
  addTearDown(state.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            filePicker: picker,
            dataTransferService: service,
            onViewImportedRecords: onView,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakePicker extends FilePickService {
  bool cancel = false;
  @override
  Future<List<ImportFile>?> pickFiles() async => cancel
      ? null
      : [
          ImportFile(
            name: '第一份.json',
            size: 2,
            readBytes: () async => [123, 125],
          ),
          ImportFile(name: '第二份.md', size: 0, readBytes: () async => []),
        ];
}

class _FakeTransfer extends DataTransferService {
  final prepared = Completer<ImportPlan>();
  final executed = Completer<ImportResult>();
  List<ImportFile>? received;
  int executeCalls = 0;
  @override
  Future<ImportPlan> prepare(List<ImportFile> files, AppState state) {
    received = files;
    return prepared.future;
  }

  @override
  Future<ImportResult> execute(ImportPlan plan, AppState state) {
    executeCalls++;
    return executed.future;
  }

  @override
  Future<DateTime?> latestBackupAt() async =>
      executeCalls == 0 ? null : DateTime(2026, 9, 17, 12, 30);
}

class _MemoryStorage implements StorageService {
  final values = <String, String>{};
  @override
  Future<String?> readString(String key) async => values[key];
  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}
