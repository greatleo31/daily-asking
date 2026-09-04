import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/evidence/question_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> pumpCard(
    WidgetTester tester, {
    required EvidenceQuestion question,
    required StorageService store,
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    final state = await AppState.debug(store);
    await state.bootstrap();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: QuestionCard(question: question),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('界面无稍后，仅有跳过与回答', (tester) async {
    final q = EvidenceQuestion(
      id: 'q_ui',
      entryId: 'e_ui',
      kind: QuestionKind.context,
      prompt: '这件事发生在什么背景 / 场景下？',
      reason: '背景让记录可被后人体会，避免孤证',
      status: QuestionStatus.pending,
      createdAt: DateTime(2026, 9, 3),
      updatedAt: DateTime(2026, 9, 3),
    );
    await pumpCard(tester, question: q, store: _MapStorage({}));

    expect(find.text('稍后'), findsNothing);
    expect(find.text('跳过'), findsOneWidget);
    expect(find.text('回答'), findsOneWidget);
  });

  testWidgets('点跳过写入 skip 并通过 pop 带回下一问', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = _MapStorage({});
    final state = await AppState.debug(store);
    await state.bootstrap();

    final first = await state.saveQuickToday('一件小事');
    expect(first, isNotNull);
    expect(first!.kind, QuestionKind.context);

    EvidenceQuestion? popped;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await showModalBottomSheet<EvidenceQuestion?>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => QuestionCard(question: first),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('稍后'), findsNothing);
    expect(find.text('跳过'), findsOneWidget);

    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();

    expect(popped, isNotNull);
    expect(popped!.kind, QuestionKind.action);

    final qs = await state.questionsFor(first.entryId);
    expect(
      qs.any((q) =>
          q.kind == QuestionKind.context && q.status == QuestionStatus.skip),
      isTrue,
    );
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