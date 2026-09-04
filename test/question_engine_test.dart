import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/evidence/question_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry({
  String id = 'e1',
  String context = '',
  String action = '',
  String result = '',
  String blocker = '',
}) {
  final now = DateTime(2026, 9, 3);
  return Entry(
    id: id,
    date: now,
    task: '一事',
    context: context,
    action: action,
    result: result,
    blocker: blocker,
    createdAt: now,
    updatedAt: now,
  );
}

EvidenceQuestion _q(QuestionKind kind, QuestionStatus status) {
  final now = DateTime(2026, 9, 3);
  return EvidenceQuestion(
    id: 'q_${kind.name}',
    entryId: 'e1',
    kind: kind,
    prompt: 'p',
    reason: 'r',
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final engine = QuestionEngine();

  group('QuestionEngine field priority', () {
    test('all empty fields → kind context', () {
      final q = engine.nextQuestion(entry: _entry(), existing: const []);
      expect(q, isNotNull);
      expect(q!.kind, QuestionKind.context);
    });

    test('context filled, action+result empty → action', () {
      final q = engine.nextQuestion(
        entry: _entry(context: '有背景'),
        existing: const [],
      );
      expect(q, isNotNull);
      expect(q!.kind, QuestionKind.action);
    });

    test('only result+blocker empty (context+action filled) → result', () {
      final q = engine.nextQuestion(
        entry: _entry(context: '有背景', action: '有行动'),
        existing: const [],
      );
      expect(q, isNotNull);
      expect(q!.kind, QuestionKind.result);
    });

    test('skip context → next is action; do not regenerate context', () {
      final q = engine.nextQuestion(
        entry: _entry(),
        existing: [_q(QuestionKind.context, QuestionStatus.skip)],
      );
      expect(q, isNotNull);
      expect(q!.kind, QuestionKind.action);
      expect(q.kind, isNot(QuestionKind.context));
    });

    test('answered contribution → never generate contribution again', () {
      final q = engine.nextQuestion(
        entry: _entry(
          context: '有背景',
          action: '有行动',
          result: '有结果',
          blocker: '有难点',
        ),
        existing: [_q(QuestionKind.contribution, QuestionStatus.answered)],
      );
      expect(q, isNull);
    });

    test('all structured fields filled, no contribution record → contribution', () {
      final q = engine.nextQuestion(
        entry: _entry(
          context: '有背景',
          action: '有行动',
          result: '有结果',
          blocker: '有难点',
        ),
        existing: const [],
      );
      expect(q, isNotNull);
      expect(q!.kind, QuestionKind.contribution);
    });

    test('contribution skipped → no new question', () {
      final q = engine.nextQuestion(
        entry: _entry(
          context: '有背景',
          action: '有行动',
          result: '有结果',
          blocker: '有难点',
        ),
        existing: [_q(QuestionKind.contribution, QuestionStatus.skip)],
      );
      expect(q, isNull);
    });

    test('nextQuestion returns at most 1; filled field kinds not selected', () {
      final q = engine.nextQuestion(
        entry: _entry(context: '有背景', action: '有行动'),
        existing: const [],
      );
      expect(q, isNotNull);
      expect(q!.kind, QuestionKind.result);
      expect(q.kind, isNot(QuestionKind.context));
      expect(q.kind, isNot(QuestionKind.action));
      // Single return value already means at most 1.
    });
  });
}