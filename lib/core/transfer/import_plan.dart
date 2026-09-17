import '../models.dart';
import 'transfer_schema.dart';

enum ImportDisposition { added, skipped, invalid }

class ImportDetail {
  const ImportDetail({
    required this.source,
    required this.index,
    required this.disposition,
    required this.label,
    required this.reason,
  });

  final String source;
  final int index;
  final ImportDisposition disposition;
  final String label;
  final String reason;
}

class ImportPlan {
  const ImportPlan({
    required this.parsed,
    required this.entries,
    required this.questions,
    required this.answers,
    required this.skipped,
    required this.issues,
    required this.incompleteCount,
    required this.legacyCount,
    required this.ignoredLines,
    required this.details,
    this.acceptedCandidates = const [],
  });

  /// Retained for execute-time revalidation against a fresh storage snapshot.
  final ParsedImport parsed;
  // Additions only. Existing repository rows are never returned for rewriting.
  final List<Entry> entries;
  final List<EvidenceQuestion> questions;
  final List<EvidenceAnswer> answers;
  final int skipped;
  final List<ImportIssue> issues;
  final int incompleteCount;
  final int legacyCount;
  final int ignoredLines;
  final List<ImportDetail> details;

  /// Exact accepted source candidates, in the same order as [entries]. A prior
  /// rejected candidate may have the same entry ID but different metadata.
  final List<ImportCandidate> acceptedCandidates;

  int get addedCount => entries.length;
  int get skippedCount => skipped;
  // Includes standalone orphan/file issues, not only failed entry groups.
  int get invalidCount => issues.length;
}

String importFingerprint(Entry entry) {
  String two(int value) => value.toString().padLeft(2, '0');
  final date = entry.date;
  final task = entry.task.replaceAll(RegExp(r'[\s\u3000]+'), ' ').trim();
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}|$task';
}

ImportPlan buildImportPlan(
  ParsedImport parsed, {
  required List<Entry> existingEntries,
  required List<EvidenceQuestion> existingQuestions,
  required List<EvidenceAnswer> existingAnswers,
  required DateTime now,
}) {
  final entryIds = existingEntries.map((entry) => entry.id).toSet();
  final fingerprints = existingEntries.map(importFingerprint).toSet();
  final questionIds = existingQuestions.map((question) => question.id).toSet();
  final answerIds = existingAnswers.map((answer) => answer.id).toSet();
  final entries = <Entry>[];
  final questions = <EvidenceQuestion>[];
  final answers = <EvidenceAnswer>[];
  final acceptedCandidates = <ImportCandidate>[];
  final issues = List<ImportIssue>.of(parsed.issues);
  final details = <ImportDetail>[
    for (final issue in parsed.issues)
      ImportDetail(
        source: issue.source,
        index: issue.index,
        disposition: ImportDisposition.invalid,
        label: issue.index == 0 ? issue.source : '第 ${issue.index} 项',
        reason: issue.reason,
      ),
  ];
  var skipped = 0;
  var incomplete = 0;
  var legacy = 0;
  String two(int value) => value.toString().padLeft(2, '0');
  final tag =
      '#导入-${now.year.toString().padLeft(4, '0')}${two(now.month)}${two(now.day)}';

  for (final candidate in parsed.candidates) {
    final entry = candidate.entry;
    final fingerprint = importFingerprint(entry);
    void detail(ImportDisposition disposition, String reason) {
      details.add(
        ImportDetail(
          source: candidate.source,
          index: candidate.index,
          disposition: disposition,
          label: entry.task.trim().isEmpty
              ? '第 ${candidate.index} 条记录'
              : entry.task,
          reason: reason,
        ),
      );
    }

    if (entryIds.contains(entry.id) ||
        (!candidate.hasOriginalId && fingerprints.contains(fingerprint))) {
      skipped++;
      detail(
        ImportDisposition.skipped,
        '已存在相同${entryIds.contains(entry.id) ? ' id' : '日期与任务'}的记录，追问与回答一并跳过',
      );
      continue;
    }
    // Defensive relationship validation also protects manually built candidates.
    final localQuestionIds = <String>{};
    final localAnswerIds = <String>{};
    final reasons = <String>[];
    for (final question in candidate.questions) {
      if (question.entryId != entry.id) {
        reasons.add('追问 ${question.id} 不属于当前记录');
      }
      if (questionIds.contains(question.id) ||
          !localQuestionIds.add(question.id)) {
        reasons.add('追问 id 已存在或重复：${question.id}（不会覆盖）');
      }
    }
    for (final answer in candidate.answers) {
      if (!localQuestionIds.contains(answer.questionId)) {
        reasons.add('回答 ${answer.id} 未引用当前记录中的追问');
      }
      if (answerIds.contains(answer.id) || !localAnswerIds.add(answer.id)) {
        reasons.add('回答 id 已存在或重复：${answer.id}（不会覆盖）');
      }
    }
    if (reasons.isNotEmpty) {
      final reason = reasons.toSet().join('；');
      issues.add(
        ImportIssue(
          source: candidate.source,
          index: candidate.index,
          reason: reason,
        ),
      );
      detail(ImportDisposition.invalid, reason);
      continue;
    }
    // Copy mutable model fields: preview must not change the retained parse tree
    // or repository objects, and re-planning must not accumulate batch tags.
    entries.add(
      Entry(
        id: entry.id,
        date: entry.date,
        task: entry.task,
        context: entry.context,
        action: entry.action,
        result: entry.result,
        blocker: entry.blocker,
        tags: [...entry.tags, if (!entry.tags.contains(tag)) tag],
        createdAt: entry.date,
        updatedAt: entry.date,
      ),
    );
    questions.addAll(
      candidate.questions.map((q) => EvidenceQuestion.fromJson(q.toJson())),
    );
    answers.addAll(
      candidate.answers.map((a) => EvidenceAnswer.fromJson(a.toJson())),
    );
    acceptedCandidates.add(candidate);
    entryIds.add(entry.id);
    fingerprints.add(fingerprint);
    questionIds.addAll(localQuestionIds);
    answerIds.addAll(localAnswerIds);
    if (candidate.incomplete) incomplete++;
    if (candidate.legacy) legacy++;
    detail(
      ImportDisposition.added,
      candidate.incomplete ? '将新增（不完整解析，缺失信息已用默认值补齐）' : '将新增',
    );
  }
  return ImportPlan(
    parsed: parsed,
    entries: entries,
    questions: questions,
    answers: answers,
    skipped: skipped,
    issues: issues,
    incompleteCount: incomplete,
    legacyCount: legacy,
    ignoredLines: parsed.ignoredLines,
    details: details,
    acceptedCandidates: acceptedCandidates,
  );
}
