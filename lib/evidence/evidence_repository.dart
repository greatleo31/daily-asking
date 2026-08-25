/// evidence 模块：追问与答案的 Repository。
library;

import '../core/models.dart';
import '../core/storage/storage.dart';

/// 追问与答案存取接口。
abstract class EvidenceRepository {
  Future<List<EvidenceQuestion>> questionsFor(String entryId);
  Future<List<EvidenceAnswer>> answersFor(String questionId);
  Future<void> saveQuestion(EvidenceQuestion q);
  Future<void> saveAnswer(EvidenceAnswer a);
  Future<void> deleteForEntry(String entryId);
  Future<List<EvidenceQuestion>> openQuestionsFor(String entryId);

  /// 全量读取 Question 集合（按创建时间升序）。
  Future<List<EvidenceQuestion>> listQuestions();

  /// 全量读取 Answer 集合（按创建时间升序）。
  Future<List<EvidenceAnswer>> listAnswers();

  /// 一次读取并按 Entry 分组多个 Entry 的问题（每组按创建时间升序）。
  Future<Map<String, List<EvidenceQuestion>>> questionsByEntryIds(
    Iterable<String> entryIds,
  );
}

class LocalEvidenceRepository implements EvidenceRepository {
  LocalEvidenceRepository(this._store);

  final JsonStore _store;
  static const _qKey = 'questions_v1';
  static const _aKey = 'answers_v1';

  List<EvidenceQuestion> _qs = [];
  List<EvidenceAnswer> _as = [];
  bool _loaded = false;

  Future<void> _ensure() async {
    if (_loaded) return;
    _qs = (await _store.readList(_qKey)).map(EvidenceQuestion.fromJson).toList();
    _as = (await _store.readList(_aKey)).map(EvidenceAnswer.fromJson).toList();
    _loaded = true;
  }

  @override
  Future<List<EvidenceQuestion>> questionsFor(String entryId) async {
    await _ensure();
    return _qs.where((q) => q.entryId == entryId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<List<EvidenceAnswer>> answersFor(String questionId) async {
    await _ensure();
    return _as
        .where((a) => a.questionId == questionId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> saveQuestion(EvidenceQuestion q) async {
    await _ensure();
    final i = _qs.indexWhere((e) => e.id == q.id);
    if (i >= 0) {
      _qs[i] = q;
    } else {
      _qs.add(q);
    }
    await _store.writeList(_qKey, _qs.map((e) => e.toJson()).toList());
  }

  @override
  Future<void> saveAnswer(EvidenceAnswer a) async {
    await _ensure();
    final i = _as.indexWhere((e) => e.id == a.id);
    if (i >= 0) {
      _as[i] = a;
    } else {
      _as.add(a);
    }
    await _store.writeList(_aKey, _as.map((e) => e.toJson()).toList());
  }

  @override
  Future<void> deleteForEntry(String entryId) async {
    await _ensure();
    final qids = _qs.where((q) => q.entryId == entryId).map((q) => q.id).toSet();
    _qs.removeWhere((q) => q.entryId == entryId);
    _as.removeWhere((a) => qids.contains(a.questionId));
    await _store.writeList(_qKey, _qs.map((e) => e.toJson()).toList());
    await _store.writeList(_aKey, _as.map((e) => e.toJson()).toList());
  }

  /// 列出某一 entry 尚未结束（pending / later）的追问。
  @override
  Future<List<EvidenceQuestion>> openQuestionsFor(String entryId) async {
    final qs = await questionsFor(entryId);
    return qs
        .where((q) =>
            q.status == QuestionStatus.pending ||
            q.status == QuestionStatus.later)
        .toList();
  }

  @override
  Future<List<EvidenceQuestion>> listQuestions() async {
    await _ensure();
    return List.of(_qs)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<List<EvidenceAnswer>> listAnswers() async {
    await _ensure();
    return List.of(_as)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<Map<String, List<EvidenceQuestion>>> questionsByEntryIds(
    Iterable<String> entryIds,
  ) async {
    await _ensure();
    final ids = entryIds.toSet();
    if (ids.isEmpty) return <String, List<EvidenceQuestion>>{};
    final grouped = <String, List<EvidenceQuestion>>{};
    for (final q in _qs) {
      if (!ids.contains(q.entryId)) continue;
      grouped.putIfAbsent(q.entryId, () => []).add(q);
    }
    for (final qs in grouped.values) {
      qs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return grouped;
  }
}
