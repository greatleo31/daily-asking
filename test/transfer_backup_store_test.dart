import 'dart:convert';
import 'dart:io';

import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/transfer/transfer_backup_store.dart';
import 'package:daily_asking/core/transfer/transfer_partition.dart';
import 'package:daily_asking/core/transfer/transfer_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late TransferBackupStore store;
  final now = DateTime(2026, 9, 17, 12);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('transfer-backup-test-');
    store = TransferBackupStore(directory: () async => directory);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'mixed legacy single files and shards retain three whole batches',
    () async {
      final legacy = File('${directory.path}/auto-20260916-120000.json');
      await legacy.writeAsString('legacy');
      await legacy.setLastModified(now.subtract(const Duration(days: 1)));
      expect(await store.latestBackupAt(), await legacy.lastModified());

      await store.writeSnapshotParts(['a1', 'a2'], now: now);
      await store.writeSnapshot('b', now: now);
      await store.writeSnapshotParts(['c1', 'c2', 'c3'], now: now);
      expect(await legacy.exists(), isFalse);
      final batches = await directory.list().toList();
      expect(batches, hasLength(3));
      expect(batches.whereType<File>(), hasLength(1));
      final contents = <String>[];
      for (final batch in batches) {
        if (batch is File) {
          contents.add(await batch.readAsString());
        } else if (batch is Directory) {
          for (final part in await batch.list().toList()) {
            contents.add(await File(part.path).readAsString());
          }
        }
      }
      expect(contents, unorderedEquals(['a1', 'a2', 'b', 'c1', 'c2', 'c3']));
      await store.writeSnapshot('d', now: now);
      expect(
        await Directory('${directory.path}/auto-20260917-120000').exists(),
        isFalse,
      );
      expect(await directory.list().length, 3);
      expect(
        await Directory(
          '${directory.path}/auto-20260917-120000-2',
        ).list().length,
        3,
      );
    },
  );

  test('same-second single and multipart names never collide', () async {
    await store.writeSnapshot('first', now: now);
    await store.writeSnapshotParts(['second-1', 'second-2'], now: now);
    await store.writeSnapshot('third', now: now);
    expect(
      await File('${directory.path}/auto-20260917-120000.json').readAsString(),
      'first',
    );
    expect(
      await Directory('${directory.path}/auto-20260917-120000-1').list().length,
      2,
    );
    expect(
      await File(
        '${directory.path}/auto-20260917-120000-2.json',
      ).readAsString(),
      'third',
    );
  });

  test(
    'unfinished pending directories are ignored and not overwritten',
    () async {
      final pending = Directory(
        '${directory.path}/auto-20260917-120000.pending',
      );
      await pending.create();
      final fragment = File('${pending.path}/part-001-of-002.json');
      await fragment.writeAsString('unfinished');
      final pendingFile = File(
        '${directory.path}/auto-20260917-120000-1.json.pending',
      );
      await pendingFile.writeAsString('unfinished-single');
      expect(await store.latestBackupAt(), isNull);
      await store.writeSnapshotParts(['complete-1', 'complete-2'], now: now);
      expect(
        await Directory(
          '${directory.path}/auto-20260917-120000-2',
        ).list().length,
        2,
      );
      expect(await store.latestBackupAt(), isNotNull);
      await store.writeSnapshot('next', now: now);
      await store.writeSnapshot('third', now: now);
      await store.writeSnapshot('fourth', now: now);
      expect(await fragment.readAsString(), 'unfinished');
      expect(await pendingFile.readAsString(), 'unfinished-single');
      expect(await directory.list().length, 5);
    },
  );

  test(
    '6000 saved entries form independently parseable seven-key v2 files',
    () async {
      final entries = List.generate(
        6000,
        (i) => Entry(
          id: 'entry-$i',
          date: now,
          task: '记录 $i',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final questions = [
        for (final i in [0, 4999, 5000, 5999])
          EvidenceQuestion(
            id: 'q-$i',
            entryId: 'entry-$i',
            kind: QuestionKind.values.first,
            prompt: '追问 $i',
            reason: '',
            status: QuestionStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
      ];
      final answers = [
        for (final q in questions)
          EvidenceAnswer(
            id: 'a-${q.id}',
            questionId: q.id,
            content: '回答',
            createdAt: now,
          ),
      ];
      final parts = encodeTransferParts(
        TransferData(entries: entries, questions: questions, answers: answers),
        exportedAt: now,
        appVersion: 'test',
      );
      expect(parts, hasLength(2));
      await store.writeSnapshotParts(parts, now: now);
      final batches = await directory.list().toList();
      expect(batches, hasLength(1));
      final files = await Directory(batches.single.path).list().toList();
      expect(
        files.map((f) => f.uri.pathSegments.last),
        unorderedEquals(['part-001-of-002.json', 'part-002-of-002.json']),
      );
      final ids = <String>{};
      var questionCount = 0;
      var answerCount = 0;
      for (final file in files) {
        final bytes = await File(file.path).readAsBytes();
        expect(bytes.length, lessThanOrEqualTo(maxTransferFileBytes));
        final text = utf8.decode(bytes, allowMalformed: false);
        final root = jsonDecode(text) as Map<String, dynamic>;
        expect(
          root.keys,
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
        expect((root['entries'] as List).length, lessThanOrEqualTo(5000));
        final parsed = parseTransferJson(text, source: file.path);
        expect(parsed.issues, isEmpty);
        for (final candidate in parsed.candidates) {
          expect(ids.add(candidate.entry.id), isTrue);
          questionCount += candidate.questions.length;
          answerCount += candidate.answers.length;
        }
      }
      expect(ids, unorderedEquals(entries.map((e) => e.id)));
      expect(questionCount, 4);
      expect(answerCount, 4);
    },
  );
}
