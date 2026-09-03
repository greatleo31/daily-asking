/// 应用级状态：组装所有 Repository / Service，并向页面暴露反应式数据。
///
/// 保持低耦合：页面只依赖 [AppState] 暴露的方法与数据，不直接碰存储。
/// Repository 是私有实现细节；写操作按受影响领域定向刷新，避免无条件完整 reload。
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../artifacts/artifact_repository.dart';
import '../companion/companion_profile.dart';
import '../companion/companion_repository.dart';
import '../companion/companion_service.dart';
import '../core/models.dart';
import '../core/storage/storage.dart';
import '../core/utils.dart';
import '../evidence/evidence_repository.dart';
import '../evidence/evidence_service.dart';
import '../journal/journal_repository.dart';
import '../settings/settings_repository.dart';
import '../updater/update_prefs.dart';
import '../updater/update_service.dart';

/// 保存 / 更新已持久化成功，但内存快照刷新与完整重载均失败。
///
/// UI 不得把该异常当作「可安全重试的保存失败」——数据已落盘，重试会重复；
/// 应提示真实状态、保留最后已知快照，等待下次 reload / refreshToday 恢复。
class SaveSucceededButRefreshFailed implements Exception {
  SaveSucceededButRefreshFailed(this.cause);

  final Object cause;

  @override
  String toString() => '数据已保存成功，但界面刷新失败：$cause';
}

/// 保存 / 更新写入失败，且补偿回滚也未完成：持久化状态不确定。
///
/// 数据可能已部分落盘，UI 不得恢复输入、不得提示「可重试」——重复提交会
/// 产生重复 Entry / 半更新；应提示真实状态并先刷新确认。
class SaveRollbackIncomplete implements Exception {
  SaveRollbackIncomplete(this.isNewEntry, this.cause, this.rollbackCause);

  /// true 表示本次是新建 Entry（updateEntry 对未知 id 的新建同理）。
  final bool isNewEntry;

  /// 原始写入失败原因。
  final Object cause;

  /// 补偿回滚失败原因。
  final Object rollbackCause;

  @override
  String toString() =>
      '保存失败且回滚未完成（${isNewEntry ? '新建' : '更新'}：$cause；回滚：$rollbackCause）';
}

/// 应用组合根与门面：持有全部 Repository / Service，向 UI 暴露稳定状态快照
/// 与跨实体业务操作。
class AppState extends ChangeNotifier {
  AppState._({
    required this._entries,
    required this._artifactRepo,
    required this._settings,
    required this._evidenceService,
    required this.updateService,
    required this._companionRepo,
  });

  /// 依赖全部由 [AppState.create] 一次性注入。
  final EntryRepository _entries;
  final ArtifactRepository _artifactRepo;
  final SettingsRepository _settings;
  final EvidenceService _evidenceService;
  final CompanionRepository _companionRepo;

  /// 更新服务（非持久化 Repository，UI 直接使用）。
  final UpdateService updateService;

  static Future<AppState> create() async {
    final store = await SharedPrefsStorage.create();
    return AppState._build(store);
  }

  /// 测试专用构造：注入任意 [StorageService]，绕开 SharedPreferences。
  @visibleForTesting
  static Future<AppState> debug(StorageService store) async =>
      AppState._build(store);

  static AppState _build(StorageService store) {
    final jsonStore = JsonStore(store);
    final entryRepo = LocalEntryRepository(jsonStore);
    final evidenceRepo = LocalEvidenceRepository(jsonStore);
    final artifactRepo = LocalArtifactRepository(jsonStore);
    final settingsRepo = SettingsRepository(store);
    final companionRepo = LocalCompanionRepository(jsonStore);
    final updatePrefs = UpdatePrefs(store);
    final updateService = UpdateService(updatePrefs);
    return AppState._(
      entries: entryRepo,
      artifactRepo: artifactRepo,
      settings: settingsRepo,
      evidenceService: EvidenceService(entryRepo, evidenceRepo),
      updateService: updateService,
      companionRepo: companionRepo,
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

  // ---- 伙伴域（只读快照 + 瞬时保存事件）----
  final CompanionService _companionService = const CompanionService();
  CompanionProfile _companion = CompanionProfile.empty;
  CompanionGrowthResult? _lastCompanionEvent;

  /// 仅测试用：注入「保存成功后刷新失败」故障，验证
  /// [SaveSucceededButRefreshFailed] 契约（正常运行时为 null）。
  @visibleForTesting
  Future<void> Function()? debugRefreshFault;

  /// 伙伴资料只读快照（不可变，UI 不直接写）。
  CompanionProfile get companion => _companion;

  /// 当前视觉阶段（含素材路径）。
  CompanionStage get companionStage =>
      _companionService.stageFor(_companion.growthDays);

  /// 最近一次成功保存产生的伙伴事件（UI 消费后即失效）。
  CompanionGrowthResult? get lastCompanionEvent => _lastCompanionEvent;

  /// 今日成长卡语录：节点日返回节点语录，未记录返回引导文案。
  String get companionQuote {
    final today = _companionService.normalizeDate(DateTime.now());
    return _companionService.quoteForDay(_companion, today);
  }

  /// 今日语录是否为节点语录（节点语录不提供替换操作）。
  bool get companionQuoteIsNode {
    final today = _companionService.normalizeDate(DateTime.now());
    return _companionService.isCelebrationDay(_companion, today);
  }

  /// 今日是否仍可普通换句。
  bool get companionCanReroll {
    final today = _companionService.normalizeDate(DateTime.now());
    return _companionService.canRerollToday(_companion, today);
  }

  /// 下一个成长节点；已达第 30 天后为 null。
  int? get companionNextMilestone =>
      _companionService.nextMilestone(_companion.growthDays);

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
    return '今天已沉淀 ${_todayEntries.length} 条记录';
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

  /// 伙伴域：只读加载持久化资料。
  Future<void> _refreshCompanion() async {
    _companion = await _companionRepo.load();
  }

  Future<void> _refreshAll() async {
    await _refreshEvidence();
    await _refreshArtifacts();
    await _refreshSettings();
    await _refreshCompanion();
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
  ///
  /// 只有证据持久化成功后伙伴才成长；任一写入失败（含追问写入）都会向上
  /// 抛出。若证据已落盘而后续写入失败，回滚本次新建的 Entry / 追问（补偿），
  /// 并把内存快照刷新到真实持久化状态，避免 UI 把已落盘数据当作可安全
  /// 重试的失败。持久化成功后若刷新与完整重载均失败，抛出
  /// [SaveSucceededButRefreshFailed]，让 UI 提示真实状态而非普通成功。
  Future<EvidenceQuestion?> saveQuickToday(String task) async {
    final now = DateTime.now();
    final entry = Entry(
      id: genId(prefix: 'e_'),
      date: now,
      task: task.trim(),
      createdAt: now,
      updatedAt: now,
    );
    EvidenceQuestion? q;
    try {
      q = await _evidenceService.saveEntryAndGenerateQuestion(entry);
      await _recordCompanionGrowth(entry);
    } catch (e, st) {
      await _rollbackNewEntry(entry, e, st);
    }
    await _refreshAfterSave();
    notifyListeners();
    return q;
  }

  Future<void> updateEntry(Entry entry) async {
    final before = await _entries.find(entry.id);
    entry.updatedAt = DateTime.now();
    try {
      await _entries.save(entry);
      await _recordCompanionGrowth(entry);
    } catch (e, st) {
      await _rollbackUpdate(entry, before, e, st);
    }
    await _refreshAfterSave();
    notifyListeners();
  }

  /// 补偿：回滚本次新建的 Entry / 追问；回滚失败不静默吞掉——抛出
  /// [SaveRollbackIncomplete]（状态不确定，UI 不得恢复输入 / 提示可重试），
  /// 并在回滚后把内存快照刷新到真实持久化状态。
  Future<void> _rollbackNewEntry(Entry entry, Object e, StackTrace st) async {
    Object? rollbackError;
    try {
      await _evidenceService.deleteEntryCascade(entry.id);
    } catch (rollback) {
      rollbackError = rollback;
    }
    await _refreshSnapshotAfterRollback();
    if (rollbackError != null) {
      throw SaveRollbackIncomplete(true, e, rollbackError);
    }
    Error.throwWithStackTrace(e, st);
  }

  /// 补偿：回滚本次更新（新建则删除）；语义同 [_rollbackNewEntry]。
  Future<void> _rollbackUpdate(
      Entry entry, Entry? before, Object e, StackTrace st) async {
    Object? rollbackError;
    try {
      if (before != null) {
        await _entries.save(before);
      } else {
        await _evidenceService.deleteEntryCascade(entry.id);
      }
    } catch (rollback) {
      rollbackError = rollback;
    }
    await _refreshSnapshotAfterRollback();
    if (rollbackError != null) {
      throw SaveRollbackIncomplete(before == null, e, rollbackError);
    }
    Error.throwWithStackTrace(e, st);
  }

  /// 回滚后刷新内存快照到真实持久化状态；刷新失败时保留最后已知快照
  /// 并继续抛出原始异常。
  Future<void> _refreshSnapshotAfterRollback() async {
    try {
      await _refreshEvidence();
    } catch (_) {/* 保留原始异常；快照保持最后已知状态 */}
    notifyListeners();
  }

  /// 持久化成功后刷新内存快照；不静默吞掉失败。
  ///
  /// 先尝试定向刷新；失败再尝试完整 [reload] 恢复；两者都失败时抛出
  /// [SaveSucceededButRefreshFailed]（数据已落盘，调用方不得当作可安全
  /// 重试的失败）。
  Future<void> _refreshAfterSave() async {
    if (debugRefreshFault != null) {
      // 仅测试用：模拟「刷新与完整重载均失败」。
      try {
        await debugRefreshFault!();
      } catch (e) {
        throw SaveSucceededButRefreshFailed(e);
      }
      return;
    }
    try {
      await _refreshEvidence();
    } catch (e) {
      try {
        await reload();
      } catch (reloadError) {
        throw SaveSucceededButRefreshFailed(reloadError);
      }
    }
  }

  /// 有效记录（事件描述非空）持久化成功后，把 Entry 日期幂等计入伙伴成长。
  ///
  /// 同一自然日只计入一次；补写历史日期可计入；删除记录不在此回退。
  /// 伙伴资料仅在持久化成功后替换内存快照，保存失败不改变伙伴状态。
  Future<void> _recordCompanionGrowth(Entry entry) async {
    if (entry.task.trim().isEmpty) return; // 无效记录不计成长
    final result = _companionService.record(_companion, entry.date);
    if (result.counted) {
      await _companionRepo.save(result.profile);
      _companion = result.profile;
    }
    _lastCompanionEvent = result;
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

  // ---- 伙伴 ----

  /// 设置伙伴名称；返回错误文案，成功返回 null。
  ///
  /// 名称限制为 1–8 个中文或英文字符；命名失败不改变伙伴资料。
  Future<String?> setCompanionName(String name) async {
    final trimmed = name.trim();
    final error = _companionService.validateName(trimmed);
    if (error != null) return error;
    final updated = CompanionProfile.sealed(
      name: trimmed,
      countedDates: _companion.countedDates,
      lastQuoteDate: _companion.lastQuoteDate,
      quoteRerolls: _companion.quoteRerolls,
      milestoneDates: _companion.milestoneDates,
    );
    await _companionRepo.save(updated);
    _companion = updated;
    notifyListeners();
    return null;
  }

  /// 独立重置伙伴：名称、累计成长日、节点状态与语录状态全部清空；
  /// 不触碰 Entry / EvidenceQuestion / EvidenceAnswer / Artifact。
  Future<void> resetCompanion() async {
    await _companionRepo.reset();
    _companion = CompanionProfile.empty;
    _lastCompanionEvent = null;
    notifyListeners();
  }

  /// 普通日语录换句（每自然日有限次数）；节点日 / 未记录日不改变状态。
  Future<CompanionRerollResult> rerollCompanionQuote() async {
    final today = _companionService.normalizeDate(DateTime.now());
    final result = _companionService.reroll(_companion, today);
    if (result.changed) {
      await _companionRepo.save(result.profile);
      _companion = result.profile;
    }
    notifyListeners();
    return result;
  }

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
