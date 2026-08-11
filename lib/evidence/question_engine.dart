/// 本地追问规则引擎：决定"保存后最多追问一个最值得补充的问题"。
///
/// 纯业务规则，不涉及 UI。规则：
/// - result 为空 → 问结果/验证
/// - context 为空 → 问背景
/// - action 为空 → 问具体行动
/// - blocker 为空 → 问难点/取舍
/// - 个人贡献不清晰 → 问个人贡献
/// - 每次最多生成一个问题
/// - 同一条记录上被 skip 的问题不立即重复出现
library;

import '../core/models.dart';
import '../core/utils.dart';

class QuestionEngine {
  /// 依据当前 entry 与已有追问，生成"最多一个"待追问问题；无则返回 null。
  EvidenceQuestion? nextQuestion({
    required Entry entry,
    required List<EvidenceQuestion> existing,
  }) {
    const order = [
      QuestionKind.result,
      QuestionKind.context,
      QuestionKind.action,
      QuestionKind.blocker,
      QuestionKind.contribution,
    ];

    // 已被跳过的问题，短期内不重复出现。
    final skippedKinds =
        existing.where((q) => q.status == QuestionStatus.skip).map((q) => q.kind).toSet();

    for (final kind in order) {
      if (skippedKinds.contains(kind)) continue;
      // 已答过的问题不再追问。
      final answered =
          existing.any((q) => q.kind == kind && q.status == QuestionStatus.answered);
      if (answered) continue;

      final isEmpty = _isEmpty(kind, entry);
      if (!isEmpty) {
        // 该字段已填，不追问。
        continue;
      }
      return _build(kind, entry);
    }
    return null;
  }

  bool _isEmpty(QuestionKind kind, Entry e) {
    switch (kind) {
      case QuestionKind.result:
        return e.isFieldEmpty('result');
      case QuestionKind.context:
        return e.isFieldEmpty('context');
      case QuestionKind.action:
        return e.isFieldEmpty('action');
      case QuestionKind.blocker:
        return e.isFieldEmpty('blocker');
      case QuestionKind.contribution:
        // 个人贡献无独立字段，视为"总在缺失时追问"。
        return true;
    }
  }

  EvidenceQuestion _build(QuestionKind kind, Entry e) {
    final (prompt, reason) = switch (kind) {
      QuestionKind.result => (
          '这件事最后有什么结果，或可验证的变化？',
          '结果/验证最能体现价值，先补它',
        ),
      QuestionKind.context => (
          '这件事发生在什么背景 / 场景下？',
          '背景让记录可被后人体会，避免孤证',
        ),
      QuestionKind.action => (
          '你具体做了哪一步？',
          '行动点是把"经历"变成"能力"的钥匙',
        ),
      QuestionKind.blocker => (
          '过程中有没有难点、取舍或没做成的事？',
          '难点与取舍证明真实，也往往是成长点',
        ),
      QuestionKind.contribution => (
          '这件事里你个人负责的部分是什么？',
          '个人贡献是简历与面试最需要的证据',
        ),
    };
    final now = DateTime.now();
    return EvidenceQuestion(
      id: genId(prefix: 'q_'),
      entryId: e.id,
      kind: kind,
      prompt: prompt,
      reason: reason,
      status: QuestionStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
  }
}