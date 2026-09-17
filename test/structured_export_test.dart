import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/core/export/markdown_exporter.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/core/transfer/transfer_partition.dart';
import 'package:daily_asking/core/transfer/transfer_schema.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 17, 16, 42);
Entry _entry(int i) => Entry(
  id: 'e_$i',
  date: DateTime(2020),
  task: '历史记录 $i',
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

Future<AppState> _state(_Storage storage) async {
  final state = await AppState.debug(storage);
  await state.bootstrap();
  addTearDown(state.dispose);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('普通导出保留单文件名与 v2 内容，包含完整追问回答且不含配置', () async {
    final storage = _Storage();
    final state = await _state(storage);
    // bootstrap 后更改存储，证明不是导出旧的 state.allEntries 缓存。
    final entry = _entry(1);
    final question = EvidenceQuestion(
      id: 'q_1',
      entryId: entry.id,
      kind: QuestionKind.contribution,
      prompt: '贡献？',
      reason: '原因',
      status: QuestionStatus.answered,
      createdAt: _now,
      updatedAt: _now,
    );
    final answer = EvidenceAnswer(
      id: 'a_1',
      questionId: question.id,
      content: '回答',
      createdAt: _now,
    );
    storage.values.addAll({
      'entries_v1': jsonEncode([entry.toJson()]),
      'questions_v1': jsonEncode([question.toJson()]),
      'answers_v1': jsonEncode([answer.toJson()]),
      'unrelated_private_setting': 'not-business-data',
    });
    expect(state.allEntries, isEmpty);
    final files = await buildAllJsonFiles(state, now: _now);
    expect(files, hasLength(1));
    expect(files.single.name, 'daily-asking-export-20260917-1642.json');
    final data = jsonDecode(files.single.content) as Map<String, dynamic>;
    expect(
      data.keys,
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
    expect(data['exportedAt'], _now.toIso8601String());
    expect(data['entries'], [entry.toJson()]);
    expect(data['questions'], [question.toJson()]);
    expect(data['answers'], [answer.toJson()]);
    expect(files.single.content, isNot(contains('not-business-data')));
    expect(
      parseTransferJson(files.single.content, source: files.single.name).issues,
      isEmpty,
    );
    expect(data, jsonDecode(await buildAllJson(state, now: _now)));
  });

  test('空库仍交付一个合法 JSON 文件', () async {
    final state = await _state(_Storage());
    final files = await buildAllJsonFiles(state, now: _now);
    expect(files.single.name, jsonFileName(_now));
    final parsed = parseTransferJson(
      files.single.content,
      source: files.single.name,
    );
    expect(parsed.issues, isEmpty);
    expect(parsed.candidates, isEmpty);
  });

  test('5001 条分片有稳定编号，每份独立可导入且记录组不拆散', () async {
    final storage = _Storage();
    final state = await _state(storage);
    final entries = List.generate(5001, _entry);
    final questions = [
      for (final i in [0, 4999, 5000])
        EvidenceQuestion(
          id: 'q_$i',
          entryId: 'e_$i',
          kind: QuestionKind.contribution,
          prompt: '追问 $i',
          reason: '原因',
          status: QuestionStatus.answered,
          createdAt: _now,
          updatedAt: _now,
        ),
    ];
    final answers = [
      for (final q in questions)
        EvidenceAnswer(
          id: 'a_${q.id}',
          questionId: q.id,
          content: '回答',
          createdAt: _now,
        ),
    ];
    storage.values.addAll({
      'entries_v1': jsonEncode(entries.map((e) => e.toJson()).toList()),
      'questions_v1': jsonEncode(questions.map((q) => q.toJson()).toList()),
      'answers_v1': jsonEncode(answers.map((a) => a.toJson()).toList()),
    });
    final files = await buildAllJsonFiles(state, now: _now);
    expect(files.map((f) => f.name), [
      'daily-asking-export-20260917-1642-part-001-of-002.json',
      'daily-asking-export-20260917-1642-part-002-of-002.json',
    ]);
    final candidates = <ImportCandidate>[];
    for (final file in files) {
      expect(
        utf8.encode(file.content).length,
        lessThanOrEqualTo(maxTransferFileBytes),
      );
      final parsed = parseTransferJson(file.content, source: file.name);
      expect(parsed.issues, isEmpty);
      expect(parsed.candidates.length, lessThanOrEqualTo(5000));
      candidates.addAll(parsed.candidates);
    }
    expect(
      candidates.map((c) => c.entry.id),
      unorderedEquals(entries.map((e) => e.id)),
    );
    expect(
      candidates.expand((c) => c.questions).map((q) => q.id),
      unorderedEquals(questions.map((q) => q.id)),
    );
    expect(
      candidates.expand((c) => c.answers).map((a) => a.id),
      unorderedEquals(answers.map((a) => a.id)),
    );
  });

  group('分享通道', () {
    const channel = MethodChannel('com.dailyasking.daily_asking/export');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('单文件沿用 shareMarkdown；多文件一次发送全部内容', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      const first = TransferExportFile(
        name: 'first.json',
        content: '{"entries":[]}',
      );
      const second = TransferExportFile(
        name: 'second.json',
        content: '{"entries":[]}',
      );
      expect(await MarkdownShare.shareFiles([first]), isTrue);
      expect(calls.single.method, 'shareMarkdown');
      expect(calls.single.arguments, {
        'fileName': first.name,
        'content': first.content,
      });
      calls.clear();
      expect(await MarkdownShare.shareFiles([first, second]), isTrue);
      expect(calls.single.method, 'shareFiles');
      expect(calls.single.arguments, {
        'files': [
          {'fileName': first.name, 'content': first.content},
          {'fileName': second.name, 'content': second.content},
        ],
      });
      calls.clear();
      expect(await MarkdownShare.shareFiles([]), isFalse);
      expect(calls, isEmpty);
    });

    test('多文件平台失败返回 false，不伪报成功', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'export_failed', message: '测试失败');
      });
      expect(
        await MarkdownShare.shareFiles(const [
          TransferExportFile(name: 'first.json', content: '{}'),
          TransferExportFile(name: 'second.json', content: '{}'),
        ]),
        isFalse,
      );
    });
  });
}

class _Storage implements StorageService {
  final values = <String, String>{};
  @override
  Future<String?> readString(String key) async => values[key];
  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}
