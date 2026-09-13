import 'dart:async';
import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/artifacts/generation_waiting_overlay.dart';
import 'package:daily_asking/artifacts/studio_page.dart';
import 'package:daily_asking/companion/companion_scene_card.dart';
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

  Future<AppState> buildState() async {
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

    final state = await AppState.debug(
      _MapStorage({
        'entries_v1': jsonEncode([entry.toJson()]),
        'settings_llm': jsonEncode({
          'provider': 'custom',
          'baseUrl': 'https://api.example.com/v1',
          'model': 'gpt-4o',
          'enabled': true,
        }),
      }),
    );
    await state.bootstrap();
    return state;
  }

  Future<void> pumpStudio(
    WidgetTester tester,
    AppState state,
    Completer<LlmResult> completer,
  ) async {
    tester.view.physicalSize = const Size(900, 1900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
  }

  /// 选择记录 → 确认出站披露 → 全屏等待蒙层淡入完成。
  Future<void> startWeeklyGeneration(WidgetTester tester) async {
    await tester.tap(find.text('整理工作进展'));
    await tester.pumpAndSettle();
    expect(find.text('确认访问'), findsOneWidget);
    await tester.tap(find.text('确认访问'));
    await tester.pump(); // setState(_generatingType) + 推入蒙层
    await tester.pump(const Duration(milliseconds: 400)); // 蒙层淡入
  }

  testWidgets('工作室生成等待：全屏蒙层 + 内嵌画报卡同时就位，三按钮禁用保留图标且无旋转圈圈', (tester) async {
    final state = await buildState();
    final completer = Completer<LlmResult>();
    await pumpStudio(tester, state, completer);

    // 初始状态：无蒙层、无等待卡，按钮可用
    expect(find.byType(GenerationWaitingOverlay), findsNothing);
    expect(find.byType(CompanionSceneCard), findsNothing);
    expect(find.textContaining('正在生成「'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await startWeeklyGeneration(tester);

    // 全屏等待蒙层接管视线，首遍动画尚未播完，关闭提示不显示
    expect(find.byType(GenerationWaitingOverlay), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GenerationWaitingOverlay),
        matching: find.text('正在生成「周报」…'),
      ),
      findsOneWidget,
    );
    // 提示文案以 0 透明度等待淡入（语义树中同样不可见）
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byType(GenerationWaitingOverlay),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity,
      0,
    );

    // 蒙层之下仍保留内嵌画报大卡片（用户关闭蒙层后即可看到）
    expect(find.byType(CompanionSceneCard), findsOneWidget);
    expect(find.text('整理记录中，完成后会自动打开产物。'), findsOneWidget);

    // 生成期间无旋转圈圈，三个按钮原图标仍在
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
    expect(find.byIcon(Icons.calendar_view_week_outlined), findsOneWidget);
    expect(find.byIcon(Icons.question_answer_outlined), findsOneWidget);

    // 完成调用（模拟错误返回）
    completer.complete(LlmResult(content: '', error: '模拟调用超时'));
    await tester.pumpAndSettle();

    // 错误后蒙层与等待卡一起消失并提示错误
    expect(find.byType(GenerationWaitingOverlay), findsNothing);
    expect(find.textContaining('正在生成「'), findsNothing);
    expect(find.text('模拟调用超时'), findsOneWidget);
  });

  testWidgets('工作室生成等待：用户未关闭蒙层时，完成后收起蒙层并自动进入产物页', (tester) async {
    final state = await buildState();
    final completer = Completer<LlmResult>();
    await pumpStudio(tester, state, completer);

    await startWeeklyGeneration(tester);
    expect(find.byType(GenerationWaitingOverlay), findsOneWidget);

    completer.complete(LlmResult(content: '# 周报\n\n本周进展', error: null));
    await tester.pumpAndSettle();

    // 蒙层已被页面收起，并平滑切到 Markdown 产物页
    expect(find.byType(GenerationWaitingOverlay), findsNothing);
    expect(find.text('产物'), findsOneWidget);

    // 收尾：跑完列表高亮计时器，避免遗留挂起定时器
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('工作室生成等待：用户关闭蒙层后，完成只弹提示、不自动跳转', (tester) async {
    final state = await buildState();
    final completer = Completer<LlmResult>();
    await pumpStudio(tester, state, completer);

    await startWeeklyGeneration(tester);

    // 首遍动画播完后，点击空白处离开全屏等待
    await tester.pump(kCompanionSceneLoop);
    await tester.pump(kWaitingHintFadeIn);
    expect(find.text(GenerationWaitingOverlay.dismissHint), findsOneWidget);
    await tester.tap(find.byType(GenerationWaitingOverlay));
    await tester.pumpAndSettle();

    // 回到 icon 内嵌式画报大卡片，文案不再承诺自动打开
    expect(find.byType(GenerationWaitingOverlay), findsNothing);
    expect(find.byType(CompanionSceneCard), findsOneWidget);
    expect(find.text('整理记录中…'), findsOneWidget);
    expect(find.text('整理记录中，完成后会自动打开产物。'), findsNothing);

    completer.complete(LlmResult(content: '# 周报\n\n本周进展', error: null));
    await tester.pumpAndSettle();

    // 只提示任务完成，并留一个手动查看入口
    expect(find.text('「周报」已生成'), findsOneWidget);
    expect(find.text('查看'), findsOneWidget);
    expect(find.text('产物'), findsNothing);
    expect(find.byType(StudioPage), findsOneWidget);

    // 收尾：跑完列表高亮与 SnackBar 计时器，避免遗留挂起定时器
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
