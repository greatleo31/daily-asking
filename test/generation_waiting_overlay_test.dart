import 'package:daily_asking/artifacts/generation_waiting_overlay.dart';
import 'package:daily_asking/companion/companion_profile.dart';
import 'package:daily_asking/core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('全屏等待蒙层：首遍动画播完前不响应关闭，一轮播完后淡入关闭提示', (tester) async {
    tester.view.physicalSize = const Size(1000, 1900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var dismissed = false;
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    navigatorKey.currentState!.push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, _, _) => GenerationWaitingOverlay(
          type: ArtifactType.weekly,
          stage: CompanionStage.sprout,
          name: '小豆芽',
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 场景与状态就位
    expect(find.byType(GenerationWaitingOverlay), findsOneWidget);
    expect(find.text('正在生成「周报」…'), findsOneWidget);
    expect(find.text('小豆芽'), findsOneWidget);

    // 首遍播放期间：关闭提示还不可见，点击空白处无效
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
    await tester.tap(find.byType(GenerationWaitingOverlay));
    await tester.pump();
    expect(dismissed, isFalse);
    expect(find.byType(GenerationWaitingOverlay), findsOneWidget);

    // 完整播放一遍（bloom_idle：116 帧 / 5080ms）后，关闭提示慢慢淡入
    await tester.pump(kCompanionSceneLoop);
    await tester.pump(kWaitingHintFadeIn);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    expect(
      find.text(GenerationWaitingOverlay.dismissHint),
      findsOneWidget,
    );
    expect(
      find.text(GenerationWaitingOverlay.autoOpenHint),
      findsOneWidget,
    );
    expect(dismissed, isFalse);

    // 此时点击空白处才关闭蒙层
    await tester.tap(find.byType(GenerationWaitingOverlay));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
    expect(find.byType(GenerationWaitingOverlay), findsNothing);
  });

  testWidgets('全屏等待蒙层：系统返回键与点击空白处行为一致', (tester) async {
    var dismissed = false;
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => GenerationWaitingOverlay(
          type: ArtifactType.resume,
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 首遍播放期间：返回键被拦住，蒙层仍在
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(dismissed, isFalse);
    expect(find.byType(GenerationWaitingOverlay), findsOneWidget);

    // 播完一遍后返回键可关闭
    await tester.pump(kCompanionSceneLoop);
    await tester.pump(kWaitingHintFadeIn);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
    expect(find.byType(GenerationWaitingOverlay), findsNothing);
  });
}
