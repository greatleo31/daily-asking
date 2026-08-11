/// evidence 服务：把 Entry、Question、Answer 聚合起来，并向图谱提供指标。
///
/// 页面依赖本服务，而不是直接操作多个 Repository。
library;

import 'dart:collection';

import '../core/models.dart';
import '../core/utils.dart';
import '../journal/journal_repository.dart';
import 'evidence_repository.dart';
import 'question_engine.dart';

/// 图谱展示所需的一组聚合指标。
class GraphMetrics {
  GraphMetrics({
    required this.totalEntries,
    required this.averageCompleteness,
    required this.recentFreqByDay,
    required this.tagCounts,
    required this.openQuestionCount,
    required this.contributionCount,
  });

  final int totalEntries;
  final int averageCompleteness; // 0-100
  final SplayTreeMap<DateTime, int> recentFreqByDay; // 近 14 天记录数
  final Map<String, int> tagCounts;
  final int openQuestionCount; // 待补充问题数
  final int contributionCount; // 已记录"个人贡献"的次数
}

class EvidenceService {
  EvidenceService(this._entries, this._evidence);

  final EntryRepository _entries;
  final EvidenceRepository _evidence;
  final QuestionEngine _engine = QuestionEngine();

  /// 保存一条记录，并生成"最多一个"本地追问。
  /// 返回新生成的追问（若生成）。
  Future<EvidenceQuestion?> saveEntryAndGenerateQuestion(Entry entry) async {
    await _entries.save(entry);
    final existing = await _evidence.questionsFor(entry.id);
    final q = _engine.nextQuestion(entry: entry, existing: existing);
    if (q != null) {
      await _evidence.saveQuestion(q);
    }
    return q;
  }

  /// 回答一个追问：更新回答内容，并回填到对应 entry 字段。
  Future<void> answerQuestion(String questionId, String content) async {
    final qs = await _allQuestions();
    late EvidenceQuestion q;
    for (final x in qs) {
      if (x.id == questionId) {
        q = x;
        break;
      }
    }
    final answer = EvidenceAnswer(
      id: genId(prefix: 'a_'),
      questionId: questionId,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    await _evidence.saveAnswer(answer);

    // 回填到 entry 对应字段（个人贡献无独立字段，仅存答案）。
    final entry = await _entries.find(q.entryId);
    if (entry != null) {
      final t = content.trim();
      if (t.isNotEmpty) {
        switch (q.kind) {
          case QuestionKind.result:
            entry.result = entry.result.trim().isEmpty
                ? t
                : '${entry.result.trim()}；$t';
          case QuestionKind.context:
            entry.context = entry.context.trim().isEmpty
                ? t
                : '${entry.context.trim()}；$t';
          case QuestionKind.action:
            entry.action = entry.action.trim().isEmpty
                ? t
                : '${entry.action.trim()}；$t';
          case QuestionKind.blocker:
            entry.blocker = entry.blocker.trim().isEmpty
                ? t
                : '${entry.blocker.trim()}；$t';
          case QuestionKind.contribution:
            break;
        }
      }
      entry.updatedAt = DateTime.now();
      await _entries.save(entry);
    }

    q.status = QuestionStatus.answered;
    q.updatedAt = DateTime.now();
    await _evidence.saveQuestion(q);
  }

  /// 更新追问状态（稍后 / 跳过）。
  Future<void> setQuestionStatus(String questionId, QuestionStatus status) async {
    final qs = await _allQuestions();
    for (final q in qs) {
      if (q.id == questionId) {
        q.status = status;
        q.updatedAt = DateTime.now();
        await _evidence.saveQuestion(q);
        return;
      }
    }
  }

  Future<List<EvidenceQuestion>> _allQuestions() async {
    final entries = await _entries.list();
    final out = <EvidenceQuestion>[];
    for (final e in entries) {
      out.addAll(await _evidence.questionsFor(e.id));
    }
    return out;
  }

  /// 某 entry 的待补充（pending/later）问题。
  Future<List<EvidenceQuestion>> openQuestionsForEntry(String entryId) =>
      _evidence.openQuestionsFor(entryId);

  /// 某 entry 的全部问题（含已答/跳过）。
  Future<List<EvidenceQuestion>> questionsForEntry(String entryId) =>
      _evidence.questionsFor(entryId);

  Future<List<EvidenceAnswer>> answersFor(String questionId) =>
      _evidence.answersFor(questionId);

  Future<void> deleteEntryCascade(String entryId) async {
    await _entries.delete(entryId);
    await _evidence.deleteForEntry(entryId);
  }

  /// 计算图谱指标。
  Future<GraphMetrics> metrics() async {
    final entries = await _entries.list();
    if (entries.isEmpty) {
      return GraphMetrics(
        totalEntries: 0,
        averageCompleteness: 0,
        recentFreqByDay: SplayTreeMap(),
        tagCounts: {},
        openQuestionCount: 0,
        contributionCount: 0,
      );
    }

    final recent = SplayTreeMap<DateTime, int>();
    for (final d in lastNDays(14)) {
      recent[d] = 0;
    }
    var compSum = 0;
    var contributionCount = 0;
    final tagCounts = <String, int>{};
    for (final e in entries) {
      compSum += e.completenessPercent();
      final d = dayOf(e.date);
      if (recent.containsKey(d)) recent[d] = recent[d]! + 1;
      for (final t in e.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
    }

    // 最近 14 天内有记录的 entry 中，是否含"个人贡献"回答。
    final qs = await _allQuestions();
    var open = 0;
    for (final q in qs) {
      if (q.status == QuestionStatus.pending ||
          q.status == QuestionStatus.later) {
        open++;
      }
    }
    for (final q in qs) {
      if (q.kind == QuestionKind.contribution &&
          q.status == QuestionStatus.answered) {
        contributionCount++;
      }
    }

    return GraphMetrics(
      totalEntries: entries.length,
      averageCompleteness: (compSum / entries.length).round(),
      recentFreqByDay: recent,
      tagCounts: tagCounts,
      openQuestionCount: open,
      contributionCount: contributionCount,
    );
  }
}