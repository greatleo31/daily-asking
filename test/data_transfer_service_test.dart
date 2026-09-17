import 'dart:convert';
import 'dart:io';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/core/export/markdown_exporter.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/core/transfer/data_transfer_service.dart';
import 'package:daily_asking/core/transfer/file_pick_service.dart';
import 'package:daily_asking/core/transfer/transfer_schema.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Storage storage;
  late AppState state;
  late TransferBackupStore backups;
  late DataTransferService service;
  final now = DateTime(2026, 9, 17, 11, 30, 5);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'llm_api_key': 'secret-value'});
    directory = await Directory.systemTemp.createTemp('record-transfer-test-');
    storage = _Storage();
    state = await AppState.debug(storage);
    await state.bootstrap();
    backups = TransferBackupStore(directory: () async => directory);
    service = DataTransferService(backups: backups, now: () => now);
  });

  tearDown(() async {
    state.dispose();
    await directory.delete(recursive: true);
  });

  test('预览不落盘；确认前快照；合法记录部分成功且不成长', () async {
    final good = _entry('valid');
    final broken = _entry('broken').toJson()..remove('task');
    final file = _jsonFile([good.toJson(), broken]);
    final plan = await service.prepare([file], state);
    expect(plan.addedCount, 1);
    expect(plan.invalidCount, 1);
    expect(storage.writes, isEmpty);
    expect(await directory.list().toList(), isEmpty);
    storage.beforeWrite = () async {
      final files = await directory
          .list()
          .where((e) => e.path.endsWith('.json'))
          .toList();
      expect(files, hasLength(1));
      final snapshot =
          jsonDecode(await File(files.single.path).readAsString()) as Map;
      expect(snapshot['entries'], isEmpty);
      expect(
        snapshot.keys,
        unorderedEquals([
          'schema',
          'schemaVersion',
          'exportedAt',
          'appVersion',
          'entries',
          'questions',
          'answers',
        ]),
      );
    };
    final result = await service.execute(plan, state);
    expect(result.importedCount, 1);
    expect(result.failedCount, 1);
    expect(state.allEntries.single.tags, contains('#导入-20260917'));
    expect(state.companion.growthDays, 0);
    expect(await service.latestBackupAt(), isNotNull);
  });

  test('同文件再次导入全跳过，无多余快照；确认时重新判重', () async {
    final file = _jsonFile([_entry('same').toJson()]);
    final stale = await service.prepare([file], state);
    final first = await service.execute(stale, state);
    expect(first.importedCount, 1);
    final second = await service.execute(stale, state);
    expect(second.importedCount, 0);
    expect(second.skippedCount, 1);
    expect(state.allEntries, hasLength(1));
    expect(await directory.list().toList(), hasLength(1));
  });

  test('按文件验证扩展名、大小、UTF-8与5000条上限，其余文件继续', () async {
    var oversizedRead = false;
    final files = [
      ImportFile(
        name: 'large.json',
        size: maxImportFileBytes + 1,
        readBytes: () async {
          oversizedRead = true;
          return [];
        },
      ),
      ImportFile(
        name: 'encoding.md',
        size: 2,
        readBytes: () async => [0xc3, 0x28],
      ),
      ImportFile(name: 'archive.zip', size: 0, readBytes: () async => []),
      _jsonFile(List.generate(5001, (i) => _entry('limit-$i').toJson())),
      _jsonFile([_entry('allowed').toJson()]),
    ];
    final plan = await service.prepare(files, state);
    expect(oversizedRead, isFalse);
    expect(plan.addedCount, 1);
    expect(plan.invalidCount, 4);
    expect(
      plan.issues.map((i) => i.reason),
      containsAll([
        '文件超过 10 MB',
        '文件编码不是 UTF-8',
        '无法识别的文件格式',
        '文件包含超过 5000 条记录',
      ]),
    );
  });

  test('读取时再次限制字节数，接受UTF-8 BOM', () async {
    final valid = _jsonFile([_entry('bom').toJson()]);
    final bytes = await valid.readBytes();
    final plan = await service.prepare([
      ImportFile(
        name: 'grown.md',
        size: 0,
        readBytes: () async => List.filled(maxImportFileBytes + 1, 32),
      ),
      ImportFile(
        name: 'bom.JSON',
        size: bytes.length + 3,
        readBytes: () async => [0xef, 0xbb, 0xbf, ...bytes],
      ),
    ], state);
    expect(plan.addedCount, 1);
    expect(plan.issues.single.reason, '文件超过 10 MB');
  });

  test('流读取超过10MB时停止，不读剩余数据', () async {
    var reachedTail = false;
    Stream<List<int>> stream() async* {
      yield List.filled(maxImportFileBytes, 32);
      yield [32];
      reachedTail = true;
      yield [32];
    }

    await expectLater(
      readBoundedImportBytes(stream()),
      throwsA(isA<ImportFileException>()),
    );
    expect(reachedTail, isFalse);
    expect(await readBoundedImportBytes(Stream.value([1, 2])), [1, 2]);
  });

  test('同秒连续快照不覆盖，仅保留最近三份且不动无关文件', () async {
    final unrelated = File('${directory.path}/manual.json');
    await unrelated.writeAsString('keep');
    for (var i = 0; i < 15; i++) {
      await backups.writeSnapshot('snapshot-$i', now: now);
    }
    final files = await directory
        .list()
        .where((e) => e.path.contains('auto-'))
        .cast<File>()
        .toList();
    expect(files, hasLength(3));
    final contents = await Future.wait(files.map((e) => e.readAsString()));
    expect(
      contents,
      unorderedEquals(['snapshot-12', 'snapshot-13', 'snapshot-14']),
    );
    expect(await unrelated.readAsString(), 'keep');
  });

  test('快照失败禁止数据写入', () async {
    final failed = DataTransferService(
      backups: _FailingBackup(),
      now: () => now,
    );
    final plan = await failed.prepare([
      _jsonFile([_entry('no-write').toJson()]),
    ], state);
    final result = await failed.execute(plan, state);
    expect(result.importedCount, 0);
    expect(result.failedCount, 1);
    expect(result.storageWarning, contains('未写入任何记录'));
    expect(storage.writes, isEmpty);
    expect(state.allEntries, isEmpty);
  });

  test('存储中断不谎称回滚；完整记录组才计成功', () async {
    final entry = _entry('partial');
    final q = EvidenceQuestion(
      id: 'q_partial',
      entryId: entry.id,
      kind: QuestionKind.action,
      prompt: '做了什么',
      reason: '',
      status: QuestionStatus.answered,
      createdAt: entry.date,
      updatedAt: entry.date,
    );
    final a = EvidenceAnswer(
      id: 'a_partial',
      questionId: q.id,
      content: '答案',
      createdAt: entry.date,
    );
    final text = encodeTransfer(
      TransferData(entries: [entry], questions: [q], answers: [a]),
      exportedAt: now,
      appVersion: 'test',
    );
    final plan = await service.prepare([
      _textFile('partial.json', text),
    ], state);
    storage.failKey = 'answers_v1';
    final result = await service.execute(plan, state);
    expect(result.importedCount, 0);
    expect(result.failedCount, 1);
    expect(result.storageWarning, contains('未自动回滚'));
    expect(jsonDecode(storage.values['entries_v1']!), hasLength(1));
    expect(jsonDecode(storage.values['questions_v1']!), hasLength(1));
    expect(storage.values['answers_v1'], isNull);
    expect(await directory.list().toList(), hasLength(1));
    expect(state.companion.growthDays, 0);
  });

  test('结构化导出只含业务数据，命名正确且可再导入', () async {
    final plan = await service.prepare([
      _jsonFile([_entry('exported').toJson()]),
    ], state);
    await service.execute(plan, state);
    storage.values['llm_settings'] =
        '{"apiKey":"must-not-leak","theme":"dark"}';
    final exported = await buildAllJson(state, now: now);
    expect(jsonFileName(now), 'daily-asking-export-20260917-1130.json');
    expect(exported, isNot(contains('secret-value')));
    expect(exported, isNot(contains('must-not-leak')));
    expect(exported, isNot(contains('llm_settings')));
    final parsed = parseTransferJson(exported, source: 'export.json');
    expect(parsed.issues, isEmpty);
    expect(
      parsed.candidates.single.entry.toJson(),
      state.allEntries.single.toJson(),
    );
  });

  test('空库导出有效，回读为空且不产生快照', () async {
    final text = await buildAllJson(state, now: now);
    final plan = await service.prepare([_textFile('empty.json', text)], state);
    expect(plan.addedCount, 0);
    expect(plan.invalidCount, 0);
    final result = await service.execute(plan, state);
    expect(result.importedCount, 0);
    expect(await directory.list().toList(), isEmpty);
  });
}

Entry _entry(String id) => Entry(
  id: id,
  date: DateTime(2020, 2, 3),
  task: '历史任务$id',
  createdAt: DateTime(2020, 2, 3, 12),
  updatedAt: DateTime(2020, 2, 4),
);

ImportFile _jsonFile(List<Map<String, dynamic>> entries) => _textFile(
  'data.json',
  jsonEncode({
    'schema': transferSchemaV2,
    'schemaVersion': 2,
    'exportedAt': '2026-09-17T11:30:05',
    'appVersion': 'test',
    'entries': entries,
    'questions': [],
    'answers': [],
  }),
);

ImportFile _textFile(String name, String text) {
  final bytes = utf8.encode(text);
  return ImportFile(
    name: name,
    size: bytes.length,
    readBytes: () async => bytes,
  );
}

class _Storage implements StorageService {
  final values = <String, String>{};
  final writes = <String>[];
  String? failKey;
  Future<void> Function()? beforeWrite;
  @override
  Future<String?> readString(String key) async => values[key];
  @override
  Future<void> remove(String key) async => values.remove(key);
  @override
  Future<void> writeString(String key, String value) async {
    if (key == failKey) throw const FileSystemException('test disk failure');
    await beforeWrite?.call();
    writes.add(key);
    values[key] = value;
  }
}

class _FailingBackup extends TransferBackupStore {
  @override
  Future<void> writeSnapshot(String content, {required DateTime now}) async {
    throw const FileSystemException('test backup failure');
  }
}
