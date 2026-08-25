/// 应用级状态：组装所有 Repository / Service，并向页面暴露反应式数据。
///
/// 保持低耦合：页面只依赖 [AppState] 暴露的方法与数据，不直接碰存储。
/// Repository 是私有实现细节；写操作按受影响领域定向刷新，避免无条件完整 reload。
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../artifacts/artifact_repository.dart';
import '../core/models.dart';
import '../core/storage/storage.dart';
import '../core/utils.dart';
import '../evidence/evidence_repository.dart';
import '../evidence/evidence_service.dart';
import '../journal/journal_repository.dart';
import '../settings/settings_repository.dart';
import '../updater/update_prefs.dart';
import '../updater/update_service.dart';

/// 应用组合根与门面：持有全部 Repository / Service，向 UI 暴露稳定状态快照
/// 与跨实体业务操作。
class AppState extends ChangeNotifier {
  AppState._({
    required this._entries,
    required this._artifactRepo,
    required this._settings,
    required this._evidenceService,
    required this.updateService,
  });

  /// 依赖全部由 [AppState.create] 一次性注入。
  final EntryRepository _entries;
  final ArtifactRepository _artifactRepo;
  final SettingsRepository _settings;
  final EvidenceService _evidenceService;

  /// 更新服务（非持久化 Repository，UI 直接使用）。
  final UpdateService updateService;

  static Future<AppState> create() async {
    final store = await SharedPrefsStorage.create();
    final jsonStore = JsonStore(store);
    final entryRepo = LocalEntryRepository(jsonStore);
    final evidenceRepo = LocalEvidenceRepository(jsonStore);
    final artifactRepo = LocalArtifactRepository(jsonStore);
    final settingsRepo = SettingsRepository(store);
    final updatePrefs = UpdatePrefs(store);
    final updateService = UpdateService(updatePrefs);
    return AppState._(
      entries: entryRepo,
      artifactRepo: artifactRepo,
      settings: settingsRepo,
      evidenceService: EvidenceService(entryRepo, evidenceRepo),
      updateService: updateService,
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

  Map<String, List<EvidenceQuestion>> _openByEntry = {};

  List<EvidenceQuestion> _openFor(String entryId) =>
      _openByEntry[entryId] ?? const [];

  /// 加载全部数据并通知。
  Future<void> bootstrap() async {
    await reload();
  }

  List<Entry> _computeToday() =>
      _allEntries.where((e) => sameDay(e.date, DateTime.now())).toList();

  /// 完整加载（应用启动 bootstrap 使用）。
  Future<void> reload() async {
    await _refreshAll();
    _loaded = true;
    notifyListeners();
  }

  // ---- 领域刷新单元（写操作按受影响领域定向刷新，避免完整 reload）----

  /// 证据域：Entry / 今日 / 全部证据 / 图谱指标 / 开放问题。
  Future<void> _refreshEvidence() async {
    _allEntries = await _entries.list();
    _todayEntries = _computeToday();
    final view = await _evidenceService.refreshView(_allEntries);
    _metrics = view.metrics;
    _openByEntry = view.openByEntry;
  }

  /// 产物域。
  Future<void> _refreshArtifacts() async {
    _artifacts = await _artifactRepo.list();
  }

  /// 设置域：LLM 配置 / API Key 状态 / 主题。
  Future<void> _refreshSettings() async {
    _llm = await _settings.readLlmSettings();
    _hasApiKey = await _settings.hasApiKey();
    _theme = await _settings.readTheme();
  }

  Future<void> _refreshAll() async {
    await _refreshEvidence();
    await _refreshArtifacts();
    await _refreshSettings();
  }

  // ---- 今日 / 记录操作 ----

  /// 只重算「今日」视图并通知。
  ///
  /// 进程跨天存活（隔夜后台 / 跨零点）时 [reload] 不会自动执行，
  /// 由应用壳在恢复前台 / 切回「今日」Tab 时调用，避免日期与列表过期。
  void refreshToday() {
    _todayEntries = _computeToday();
    notifyListeners();
  }

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
    final q = await _evidenceService.saveEntryAndGenerateQuestion(entry);
    await _refreshEvidence();
    notifyListeners();
    return q;
  }

  Future<void> updateEntry(Entry entry) async {
    entry.updatedAt = DateTime.now();
    await _entries.save(entry);
    await _refreshEvidence();
    notifyListeners();
  }

  Future<void> deleteEntry(String entryId) async {
    await _evidenceService.deleteEntryCascade(entryId);
    await _refreshEvidence();
    notifyListeners();
  }

  /// 回答追问，并回填 entry 字段。
  Future<void> answerQuestion(String questionId, String content) async {
    await _evidenceService.answerQuestion(questionId, content);
    await _refreshEvidence();
    notifyListeners();
  }

  Future<void> setQuestionStatus(String questionId, QuestionStatus status) async {
    await _evidenceService.setQuestionStatus(questionId, status);
    await _refreshEvidence();
    notifyListeners();
  }

  Future<List<EvidenceQuestion>> questionsFor(String entryId) =>
      _evidenceService.questionsForEntry(entryId);

  Future<List<EvidenceAnswer>> answersFor(String questionId) =>
      _evidenceService.answersFor(questionId);

  /// 按 id 读取 Entry（供证据详情页）。
  Future<Entry?> findEntry(String id) => _entries.find(id);

  // ---- 工作室 ----

  /// 保存（新建或更新）一份产物，仅刷新产物域。
  Future<void> updateArtifact(Artifact a) async {
    a.updatedAt = DateTime.now();
    await _artifactRepo.save(a);
    await _refreshArtifacts();
    notifyListeners();
  }

  Future<void> deleteArtifact(String id) async {
    await _artifactRepo.delete(id);
    await _refreshArtifacts();
    notifyListeners();
  }

  /// 按 id 读取 Artifact（供产物查看页）。
  Future<Artifact?> findArtifact(String id) => _artifactRepo.find(id);

  // ---- 设置 ----

  Future<void> setTheme(ThemeModePreference t) async {
    await _settings.writeTheme(t);
    _theme = t;
    notifyListeners();
  }

  /// 读取 LLM 配置（供配置页回填 / 出站调用）。
  Future<LlmSettings> readLlmSettings() => _settings.readLlmSettings();

  /// 保存 LLM 配置，仅刷新设置域。
  Future<void> saveLlmSettings(LlmSettings settings, {String? apiKey}) async {
    await _settings.writeLlmSettings(settings, apiKey: apiKey);
    await _refreshSettings();
    notifyListeners();
  }

  /// 清除 LLM 配置，仅刷新设置域。
  Future<void> clearLlmSettings() async {
    await _settings.clearLlm();
    await _refreshSettings();
    notifyListeners();
  }

  /// 供出站 AI 调用读取 Key（无 Key 时返回 null；内容绝不回显 UI）。
  Future<String?> readApiKeyForCall() => _settings.readApiKeyForCall();
}
