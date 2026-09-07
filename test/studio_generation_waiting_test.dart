import 'dart:async';
import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/artifacts/studio_page.dart';
import 'package:daily_asking/core/llm/llm_client.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('工作室生成等待：展示单张等待卡、三按钮禁用保留图标、无旋转圈圈且错误恢复', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    FlutterSecureStorage.setMockInitialValues({
      'settings_llm_api_key': 'sk-test',
    });

    final now = DateTime.now();
    final entry = Entry(
      id: 'e_1',
      date: DateTime(now.year, now.month, now.day),
      task: '完成测试任务',
      createdAt: now,
      updatedAt: now,
    );

    final state = await AppState.debug(_MapStorage({
      'entries_v1': jsonEncode([entry.toJson()]),
      'settings_llm': jsonEncode({
        'provider': 'custom',
        'baseUrl': 'https://api.example.com/v1',
        'model': 'gpt-4o',
        'enabled': true,
      }),
    }));
    await state.bootstrap();

    final completer = Completer<LlmResult>();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: StudioPage(
              initialEntryIds: const ['e_1'],
              generationCall: ({
                required settings,
                required apiKey,
                required system,
                required user,
              }) => completer.future,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 初始状态：无等待卡，按钮可用
    expect(find.textContaining('正在生成「'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // 点击「周报」生成
    await tester.tap(find.text('整理工作进展'));
    await tester.pumpAndSettle();

    // 弹出出站披露确认对话框，点击「确认访问」
    expect(find.text('确认访问'), findsOneWidget);
    await tester.tap(find.text('确认访问'));
    await tester.pump(); // 开始生成，setState(_generatingType = ArtifactType.weekly)

    // 验证等待卡出现
    expect(find.text('正在生成「周报」…'), findsOneWidget);
    expect(find.text('整理记录中，完成后会自动打开产物。'), findsOneWidget);
    // 生成区无 CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // 验证三个按钮原图标仍存在
    expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
    expect(find.byIcon(Icons.calendar_view_week_outlined), findsOneWidget);
    expect(find.byIcon(Icons.question_answer_outlined), findsOneWidget);

    // 完成调用（模拟错误返回）
    completer.complete(LlmResult(content: '', error: '模拟调用超时'));
    await tester.pumpAndSettle();

    // 错误后等待卡消失，恢复初始状态
    expect(find.textContaining('正在生成「'), findsNothing);
    expect(find.text('模拟调用超时'), findsOneWidget);
  });
}
