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
  Future<void> saveAll({
    required List<EvidenceQuestion> questions,
    required List<EvidenceAnswer> answers,
  });
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
    _qs = (await _store.readList(
      _qKey,
    )).map(EvidenceQuestion.fromJson).toList();
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
    return _as.where((a) => a.questionId == questionId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> saveQuestion(EvidenceQuestion q) async {
    await _ensure();
    final next = List<EvidenceQuestion>.of(_qs);
    final i = next.indexWhere((e) => e.id == q.id);
    if (i >= 0) {
      next[i] = q;
    } else {
      next.add(q);
    }
    await _store.writeList(_qKey, next.map((e) => e.toJson()).toList());
    _qs = next;
  }

  @override
  Future<void> saveAnswer(EvidenceAnswer a) async {
    await _ensure();
    final next = List<EvidenceAnswer>.of(_as);
    final i = next.indexWhere((e) => e.id == a.id);
    if (i >= 0) {
      next[i] = a;
    } else {
      next.add(a);
    }
    await _store.writeList(_aKey, next.map((e) => e.toJson()).toList());
    _as = next;
  }

  /// 两个 key 各写一次，并分别在写入成功后更新缓存；不承诺跨 key 事务。
  @override
  Future<void> saveAll({
    required List<EvidenceQuestion> questions,
    required List<EvidenceAnswer> answers,
  }) async {
    final persistedQuestions = (await _store.readList(
      _qKey,
    )).map(EvidenceQuestion.fromJson).toList();
    final persistedAnswers = (await _store.readList(
      _aKey,
    )).map(EvidenceAnswer.fromJson).toList();
    _qs = persistedQuestions;
    _as = persistedAnswers;
    _loaded = true;
    final nextQuestions = <String, EvidenceQuestion>{
      for (final q in persistedQuestions) q.id: q,
      for (final q in questions) q.id: EvidenceQuestion.fromJson(q.toJson()),
    }.values.toList();
    final nextAnswers = <String, EvidenceAnswer>{
      for (final a in persistedAnswers) a.id: a,
      for (final a in answers) a.id: EvidenceAnswer.fromJson(a.toJson()),
    }.values.toList();
    await _store.writeList(
      _qKey,
      nextQuestions.map((q) => q.toJson()).toList(),
    );
    _qs = nextQuestions;
    await _store.writeList(_aKey, nextAnswers.map((a) => a.toJson()).toList());
    _as = nextAnswers;
  }

  @override
  Future<void> deleteForEntry(String entryId) async {
    await _ensure();
    final qids = _qs
        .where((q) => q.entryId == entryId)
        .map((q) => q.id)
        .toSet();
    final nextQuestions = _qs.where((q) => q.entryId != entryId).toList();
    final nextAnswers = _as.where((a) => !qids.contains(a.questionId)).toList();
    await _store.writeList(
      _qKey,
      nextQuestions.map((e) => e.toJson()).toList(),
    );
    _qs = nextQuestions;
    await _store.writeList(_aKey, nextAnswers.map((e) => e.toJson()).toList());
    _as = nextAnswers;
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
