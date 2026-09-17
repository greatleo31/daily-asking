/// 本地导入编排：有界读取 → 预览规划 → 自动快照 → 批量写入。
library;

import 'dart:convert';

import '../../app/app_state.dart';
import '../version.dart';
import 'file_pick_service.dart';
import 'import_parser.dart';
import 'import_plan.dart';
import 'transfer_schema.dart';
import 'transfer_partition.dart';
import 'transfer_backup_store.dart';

export 'transfer_backup_store.dart';

class ImportResult {
  const ImportResult({
    required this.plan,
    required this.importedCount,
    required this.incompleteCount,
    required this.legacyCount,
    required this.skippedCount,
    required this.failedCount,
    required this.issues,
    this.storageWarning,
  });

  final ImportPlan plan;
  final int importedCount;
  final int incompleteCount;
  final int legacyCount;
  final int skippedCount;
  final int failedCount;
  final List<ImportIssue> issues;

  /// 非事务写入中断时明确说明可能存在部分数据，不承诺回滚。
  final String? storageWarning;
}

class DataTransferService {
  DataTransferService({TransferBackupStore? backups, DateTime Function()? now})
    : _backups = backups ?? TransferBackupStore(),
      _now = now ?? DateTime.now;

  final TransferBackupStore _backups;
  final DateTime Function() _now;
  bool _executing = false;

  Future<DateTime?> latestBackupAt() => _backups.latestBackupAt();

  Future<ImportPlan> prepare(List<ImportFile> files, AppState state) async {
    final imports = <ParsedImport>[];
    for (final file in files) {
      try {
        final dot = file.name.lastIndexOf('.');
        final extension = dot < 0 ? '' : file.name.substring(dot).toLowerCase();
        if (extension != '.json' && extension != '.md') {
          throw const ImportFileException('无法识别的文件格式');
        }
        if (file.size > maxImportFileBytes) {
          throw const ImportFileException('文件超过 10 MB');
        }
        final bytes = await file.readBytes();
        if (bytes.length > maxImportFileBytes) {
          throw const ImportFileException('文件超过 10 MB');
        }
        String text;
        try {
          text = utf8.decode(bytes, allowMalformed: false);
        } on FormatException {
          throw const ImportFileException('文件编码不是 UTF-8');
        }
        // UTF-8 BOM 不是正文。
        if (text.startsWith('\uFEFF')) text = text.substring(1);
        imports.add(
          parseImportText(text, source: file.name, extension: extension),
        );
      } on ImportFileException catch (error) {
        imports.add(_fileIssue(file.name, error.message));
      } catch (_) {
        imports.add(_fileIssue(file.name, '无法读取文件，请重新选择'));
      }
    }
    return _plan(
      ParsedImport.combine(imports),
      await state.exportTransferData(),
    );
  }

  ParsedImport _fileIssue(String source, String reason) => ParsedImport(
    issues: [ImportIssue(source: source, index: 0, reason: reason)],
  );

  ImportPlan _plan(ParsedImport parsed, TransferData current) =>
      buildImportPlan(
        parsed,
        existingEntries: current.entries,
        existingQuestions: current.questions,
        existingAnswers: current.answers,
        now: _now(),
      );

  Future<ImportResult> execute(ImportPlan preview, AppState state) async {
    if (_executing) throw StateError('导入正在进行中');
    _executing = true;
    try {
      final before = await state.exportTransferData();
      // 预览后可能有新增记录；确认时重新判重，绝不覆盖。
      final plan = _plan(preview.parsed, before);
      if (plan.entries.isEmpty) return _result(plan, const {});
      try {
        await _backups.writeSnapshotParts(
          encodeTransferParts(
            before,
            exportedAt: _now(),
            appVersion: kAppVersionName,
          ),
          now: _now(),
        );
      } on TransferPartitionException catch (error) {
        return _result(
          plan,
          const {},
          warning: '自动备份失败，未写入任何记录。${error.message}',
        );
      } catch (_) {
        return _result(plan, const {}, warning: '自动备份失败，未写入任何记录。请检查可用空间后重试。');
      }
      try {
        await state.importEntries(plan);
        return _result(plan, plan.entries.map((e) => e.id).toSet());
      } catch (_) {
        // 三个 key 不是事务；只把实际已完整保存的记录组计为成功。
        final complete = <String>{};
        try {
          final actual = await state.exportTransferData();
          final entries = actual.entries.map((e) => e.id).toSet();
          final questions = actual.questions.map((q) => q.id).toSet();
          final answers = actual.answers.map((a) => a.id).toSet();
          for (final candidate in plan.acceptedCandidates) {
            if (entries.contains(candidate.entry.id) &&
                candidate.questions.every((q) => questions.contains(q.id)) &&
                candidate.answers.every((a) => answers.contains(a.id))) {
              complete.add(candidate.entry.id);
            }
          }
        } catch (_) {
          // 无法核实的记录不计成功，保留自动快照供人工恢复。
        }
        return _result(
          plan,
          complete,
          warning:
              '写入或界面刷新中断，部分数据可能已保存，未自动回滚。'
              '导入前快照已保留，请先查看记录核对，不要直接重复导入。',
        );
      }
    } finally {
      _executing = false;
    }
  }

  ImportResult _result(
    ImportPlan plan,
    Set<String> complete, {
    String? warning,
  }) {
    final issues = [...plan.issues];
    for (final candidate in plan.acceptedCandidates.where(
      (c) => !complete.contains(c.entry.id),
    )) {
      issues.add(
        ImportIssue(
          source: candidate.source,
          index: candidate.index,
          reason: warning == null ? '未写入' : '未确认完整写入，请查看上方说明',
        ),
      );
    }
    final imported = plan.acceptedCandidates.where(
      (c) => complete.contains(c.entry.id),
    );
    return ImportResult(
      plan: plan,
      importedCount: complete.length,
      incompleteCount: imported.where((c) => c.incomplete).length,
      legacyCount: imported.where((c) => c.legacy).length,
      skippedCount: plan.skippedCount,
      failedCount: issues.length,
      issues: issues,
      storageWarning: warning,
    );
  }
}
