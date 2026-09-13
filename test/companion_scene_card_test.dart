import 'package:daily_asking/companion/companion_profile.dart';
import 'package:daily_asking/companion/companion_scene_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'CompanionSceneCard renders background, shadow, character and tags correctly',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompanionSceneCard(
            stage: CompanionStage.sprout,
            name: '小豆芽',
            statusText: 'AI 构思中…',
            showSpinner: true,
            height: 200,
          ),
        ),
      ),
    );
    await tester.pump();

    // 验证展示伙伴阶段标签与名称
    expect(find.text('小芽'), findsOneWidget);
    expect(find.text('小豆芽'), findsOneWidget);

    // 验证状态覆盖栏文本与进度圈
    expect(find.text('AI 构思中…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
      'CompanionSceneCard renders without stage, name, or statusText gracefully',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompanionSceneCard(
            height: 180,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CompanionSceneCard), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
