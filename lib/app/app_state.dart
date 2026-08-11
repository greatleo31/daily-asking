/// 应用级状态：组装所有 Repository / Service，并向页面暴露反应式数据。
///
/// 保持低耦合：页面只依赖 [AppState] 暴露的方法与数据，不直接碰存储。
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../artifacts/artifact_repository.dart';
import '../artifacts/artifact_service.dart';
import '../core/models.dart';
import '../core/storage/storage.dart';
import '../core/utils.dart';
import '../evidence/evidence_repository.dart';
import '../evidence/evidence_service.dart';
import '../journal/journal_repository.dart';
import '../settings/settings_repository.dart';

class AppState extends ChangeNotifier {
  AppState._({
    required this.storage,
    required this.entries,
    required this.evidence,
    required this.artifactRepo,
    required this.settings,
    required this.evidenceService,
    required this.artifactService,
  });

  /// 依赖全部由 [AppState.create] 一次性注入。
  final StorageService storage;
  final EntryRepository entries;
  final EvidenceRepository evidence;
  final ArtifactRepository artifactRepo;
  final SettingsRepository settings;
  final EvidenceService evidenceService;
  final ArtifactService artifactService;

  static Future<AppState> create() async {
    final store = await SharedPrefsStorage.create();
    final jsonStore = JsonStore(store);
    final entryRepo = LocalEntryRepository(jsonStore);
    final evidenceRepo = LocalEvidenceRepository(jsonStore);
    final artifactRepo = LocalArtifactRepository(jsonStore);
    final settingsRepo = SettingsRepository(store);
    return AppState._(
      storage: store,
      entries: entryRepo,
      evidence: evidenceRepo,
      artifactRepo: artifactRepo,
      settings: settingsRepo,
      evidenceService: EvidenceService(entryRepo, evidenceRepo),
      artifactService: ArtifactService(),
    );
  }

  // ---- 缓存（供页面读取，避免页面直接查库）----
  List<Entry> _todayEntries = [];
  List<Entry> _allEntries = [];
  GraphMetrics _metrics = GraphMetrics(
    totalEntries: 0,
    averageCompleteness: 0,
    recentFreqByDay: SplayTreeMap<DateTime, int>(),
    tagCounts: {},
    openQuestionCount: 0,
    contributionCount: 0,
  );
  List<Artifact> _artifacts = [];
  bool _loaded = false;
  LlmSettings _llm = LlmSettings();
  bool _hasApiKey = false;
  ThemeModePreference _theme = ThemeModePreference.system;

  List<Entry> get todayEntries => _todayEntries;
  List<Entry> get allEntries => _allEntries;
  GraphMetrics get metrics => _metrics;
  List<Artifact> get artifacts => _artifacts;
  bool get loaded => _loaded;
  LlmSettings get llmSettings => _llm;
  bool get hasApiKey => _hasApiKey;
  bool get aiReady => _llm.isConfigured && _hasApiKey;
  ThemeModePreference get theme => _theme;

  /// 今日已沉淀证据数量。
  int get todayCount => _todayEntries.length;

  /// 今日最近一次补充反馈（最近一条记录的更新时间）。
  String? get lastFeedbackLabel {
    if (_todayEntries.isEmpty) return null;
    final e = _todayEntries.first; // 已按时间倒序
    final gaps = _openFor(e.id);
    if (gaps.isNotEmpty) {
      return '还有 ${gaps.length} 个待补充问题';
    }
    return '今天已沉淀 ${_todayEntries.length} 条证据';
  }

  final Map<String, List<EvidenceQuestion>> _openByEntry = {};

  List<EvidenceQuestion> _openFor(String entryId) =>
      _openByEntry[entryId] ?? const [];

  /// 加载全部数据并通知。
  Future<void> bootstrap() async {
    await reload();
  }

  Future<void> reload() async {
    _allEntries = await entries.list();
    _todayEntries = _allEntries
        .where((e) => sameDay(e.date, DateTime.now()))
        .toList();
    _metrics = await evidenceService.metrics();
    _artifacts = await artifactRepo.list();
    _llm = await settings.readLlmSettings();
    _hasApiKey = await settings.hasApiKey();
    _theme = await settings.readTheme();
    _openByEntry.clear();
    for (final e in _allEntries) {
      _openByEntry[e.id] = await evidenceService.openQuestionsForEntry(e.id);
    }
    _loaded = true;
    notifyListeners();
  }

  // ---- 今日 / 记录操作 ----

  /// 快速记录一句话事实，返回可能生成的追问。
  Future<EvidenceQuestion?> saveQuickToday(String task) async {
    final now = DateTime.now();
    final entry = Entry(
      id: genId(prefix: 'e_'),
      date: now,
      task: task.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final q = await evidenceService.saveEntryAndGenerateQuestion(entry);
    await reload();
    return q;
  }

  Future<void> updateEntry(Entry entry) async {
    entry.updatedAt = DateTime.now();
    await entries.save(entry);
    await reload();
  }

  Future<void> deleteEntry(String entryId) async {
    await evidenceService.deleteEntryCascade(entryId);
    await reload();
  }

  /// 回答追问，并回填 entry 字段。
  Future<void> answerQuestion(String questionId, String content) async {
    await evidenceService.answerQuestion(questionId, content);
    await reload();
  }

  Future<void> setQuestionStatus(String questionId, QuestionStatus status) async {
    await evidenceService.setQuestionStatus(questionId, status);
    await reload();
  }

  Future<List<EvidenceQuestion>> questionsFor(String entryId) =>
      evidenceService.questionsForEntry(entryId);

  Future<List<EvidenceAnswer>> answersFor(String questionId) =>
      evidenceService.answersFor(questionId);

  // ---- 工作室 ----

  Future<Artifact> generateLocalArtifact({
    required ArtifactType type,
    required List<Entry> sourceEntries,
  }) async {
    final a = artifactService.generateLocal(
        type: type, sourceEntries: sourceEntries);
    await artifactRepo.save(a);
    await reload();
    return a;
  }

  Future<void> updateArtifact(Artifact a) async {
    a.updatedAt = DateTime.now();
    await artifactRepo.save(a);
    await reload();
  }

  Future<void> deleteArtifact(String id) async {
    await artifactRepo.delete(id);
    await reload();
  }

  // ---- 设置 ----

  Future<void> setTheme(ThemeModePreference t) async {
    await settings.writeTheme(t);
    _theme = t;
    notifyListeners();
  }
}