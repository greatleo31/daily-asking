// 启动更新提示的 widget 测试：
// 1) 非强制 + 自动更新关闭 → 启动检查给一次轻提示（SnackBar「查看」入口）
// 2) 强制更新 → 弹不可关闭框，「立即更新」点击后禁用（防重复拉起下载）
import 'dart:async';
import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/app/shell.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/core/version.dart';
import 'package:daily_asking/updater/update_prefs.dart';
import 'package:daily_asking/updater/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _channel = MethodChannel('com.dailyasking.daily_asking/update');
const _base = 'https://mirror.example.com/update';

String _manifest({required bool mandatory}) => jsonEncode(<String, Object>{
  'versionCode': kAppVersionCode + 1,
  'versionName': '9.9.9',
  'url': '$_base/liuhen-9.9.9.apk',
  'changelog': '测试更新日志',
  'mandatory': mandatory,
});

Future<AppState> _state({required bool mandatory}) async {
  FlutterSecureStorage.setMockInitialValues({});
  final store = _MapStorage({});
  final updateService = UpdateService(
    UpdatePrefs(store),
    baseUrls: const [_base],
    client: MockClient(
      (req) async => http.Response(
        _manifest(mandatory: mandatory),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  );
  final state = await AppState.debug(store, updateService: updateService);
  await state.bootstrap();
  return state;
}

Widget _app(AppState state) => ChangeNotifierProvider<AppState>.value(
  value: state,
  child: const MaterialApp(home: AppShell()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('非强制更新且自动更新关闭：启动给一次轻提示，点「查看」打开更新框', (tester) async {
    final state = await _state(mandatory: false);
    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();

    // 延迟 4s 才检查，之前不应有任何提示。
    expect(find.text('发现新版本 9.9.9'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(); // 落到 check() 的异步结果
    await tester.pumpAndSettle(); // 入场动画走完（动画中 IgnorePointer 会挡点击）
    expect(find.text('发现新版本 9.9.9'), findsOneWidget);
    expect(find.text('查看'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('测试更新日志'), findsOneWidget);
    expect(find.text('暂不更新'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    // 非强制：可以关掉。
    expect(find.byType(PopScope), findsNothing);

    // 收尾：关框 + 冲掉 SnackBar 的 10s 计时器，避免遗留 pending Timer。
    await tester.tap(find.text('暂不更新'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
  });

  testWidgets('强制更新：弹不可关闭框，「立即更新」点击后禁用防重复', (tester) async {
    final state = await _state(mandatory: true);
    final gate = Completer<void>();
    var calls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      calls++;
      await gate.future; // 挂住，模拟下载尚未入队完成
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('需要更新到 9.9.9'), findsOneWidget);
    expect(find.text('测试更新日志'), findsOneWidget);
    // 强制框没有「暂不更新」出口，且包裹在不可返回的 PopScope 里。
    expect(find.text('暂不更新'), findsNothing);
    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);

    await tester.tap(find.text('立即更新'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('正在下载…'), findsOneWidget);
    expect(find.text('立即更新'), findsNothing);

    // 禁用状态下再点不会重复拉起下载。
    await tester.tap(find.text('正在下载…'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);

    // 下载入队返回后（失败/成功都不会关框）恢复可点，便于重试。
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('正在下载…'), findsNothing);
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
