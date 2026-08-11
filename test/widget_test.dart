// 冒烟测试：验证核心领域模型序列化与本地追问规则。
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/evidence/question_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Entry JSON 往返一致', () {
    final e = Entry(
      id: 'e_1',
      date: DateTime(2026, 8, 11),
      task: '给同事做 SQL 培训',
      context: '新同事不熟悉周报脚本',
      action: '演示并答疑',
      result: '跑通了脚本',
      blocker: '脚本路径配置费了些时间',
      tags: ['培训'],
      createdAt: DateTime(2026, 8, 11, 9),
      updatedAt: DateTime(2026, 8, 11, 9),
    );
    final back = Entry.fromJson(e.toJson());
    expect(back.id, e.id);
    expect(back.task, e.task);
    expect(back.completenessPercent(), 100);
  });

  test('本地追问：result 为空时优先问结果', () {
    final entry = Entry(
      id: 'e_2',
      date: DateTime(2026, 8, 11),
      task: '优化了报表查询',
      context: '数据量大查询慢',
      action: '加了索引',
      createdAt: DateTime(2026, 8, 11),
      updatedAt: DateTime(2026, 8, 11),
    );
    final engine = QuestionEngine();
    final q = engine.nextQuestion(entry: entry, existing: []);
    expect(q, isNotNull);
    expect(q!.kind, QuestionKind.result);
  });

  test('本地追问：最多生成一个问题，且跳过的不立即重复', () {
    final empty = Entry(
      id: 'e_3',
      date: DateTime(2026, 8, 11),
      task: '某项工作',
      createdAt: DateTime(2026, 8, 11),
      updatedAt: DateTime(2026, 8, 11),
    );
    final engine = QuestionEngine();
    final q1 = engine.nextQuestion(entry: empty, existing: [])!;
    expect(q1.kind, QuestionKind.result);

    // 用户跳过结果问题后，下一次不应再问同一个。
    q1.status = QuestionStatus.skip;
    final q2 = engine.nextQuestion(entry: empty, existing: [q1]);
    expect(q2, isNotNull);
    expect(q2!.kind, isNot(QuestionKind.result));
  });
}