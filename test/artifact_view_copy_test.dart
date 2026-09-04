import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/artifacts/artifact_view_page.dart';
import 'package:daily_asking/artifacts/markdown_document.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('阅读页标题块无复制按钮，段落块仍有复制入口', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final now = DateTime(2026, 9, 4, 10);
    // 标题用独特文案，避免与类型 Chip「周报」撞名。
    const markdown =
        '# 切片二验收标题\n\n本周完成了迁移与验收。\n\n## 计划小节\n\n下周继续优化。';
    final artifact = Artifact(
      id: 'artifact_copy_slice2',
      type: ArtifactType.weekly,
      content: markdown,
      sourceEntryIds: const ['e1'],
      risks: const [],
      gaps: const [],
      createdAt: now,
      updatedAt: now,
    );
    final state = await AppState.debug(_MapStorage({
      'artifacts_v1': jsonEncode([artifact.toJson()]),
    }));
    await state.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: ArtifactViewPage(artifactId: 'artifact_copy_slice2'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 标题与正文仍可见（Markdown 渲染后无 # 前缀）。
    expect(find.text('切片二验收标题'), findsOneWidget);
    expect(find.text('本周完成了迁移与验收。'), findsOneWidget);
    expect(find.text('计划小节'), findsOneWidget);
    expect(find.text('下周继续优化。'), findsOneWidget);

    // 两个标题块无复制；两个段落块各有一个「复制此段 Markdown」。
    expect(find.byTooltip('复制此段 Markdown'), findsNWidgets(2));
    expect(find.byIcon(Icons.content_copy_outlined), findsNWidgets(2));
  });

  test('整篇可读文本仍含标题纯文本结构', () {
    // design 默认：块级去标题入口；toReadableText 仍保留标题结构。
    final document = parseMarkdownDocument('# 周报\n\n正文一段。');
    expect(document.toReadableText(), contains('周报'));
    expect(document.toReadableText(), contains('正文一段。'));
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