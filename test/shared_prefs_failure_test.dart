import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/core/transfer/data_transfer_service.dart';
import 'package:daily_asking/core/transfer/file_pick_service.dart';
import 'package:daily_asking/core/transfer/transfer_schema.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Explicitly exercise the plugin's real MethodChannel implementation, not its
// in-memory fake (which cannot reproduce cache-before-native-commit failures).
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/method_channel_shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late SharedPreferencesStorePlatform previousPlatform;
  late _NativePreferences native;
  late SharedPreferences prefs;
  late SharedPrefsStorage storage;
  late SharedPrefsStorage otherWrapper;

  setUp(() async {
    previousPlatform = SharedPreferencesStorePlatform.instance;
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance =
        MethodChannelSharedPreferencesStore();
    native = _NativePreferences();
    messenger.setMockMethodCallHandler(channel, native.handle);
    prefs = await SharedPreferences.getInstance();
    storage = SharedPrefsStorage(prefs);
    otherWrapper = await SharedPrefsStorage.create();
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previousPlatform;
  });

  test('确认成功的写入和删除保持原有读取语义', () async {
    expect(await storage.readString('key'), isNull);
    await storage.writeString('key', 'saved');
    expect(native.disk['flutter.key'], 'saved');
    expect(await otherWrapper.readString('key'), 'saved');
    await otherWrapper.remove('key');
    expect(native.disk.containsKey('flutter.key'), isFalse);
    expect(await storage.readString('key'), isNull);
  });

  for (final throwsNative in [false, true]) {
    final mode = throwsNative ? 'throw' : 'false';
    Matcher getFailure() =>
        throwsNative ? throwsA(isA<PlatformException>()) : throwsStateError;

    test('原生 setValue $mode：跨包装器拒读 ghost，成功重试才恢复', () async {
      await storage.writeString('key', 'confirmed');
      await storage.writeString('unrelated', 'safe');
      native.failKey = 'flutter.key';
      native.throwsNative = throwsNative;
      await expectLater(storage.writeString('key', 'ghost'), getFailure());
      // Reproduce the plugin bug: raw Dart cache lies, native disk does not.
      expect(prefs.getString('key'), 'ghost');
      expect(native.disk['flutter.key'], 'confirmed');
      await expectLater(storage.readString('key'), throwsStateError);
      await expectLater(otherWrapper.readString('key'), throwsStateError);
      expect(await otherWrapper.readString('unrelated'), 'safe');

      // Even a native getAll/reload response can itself be optimistic.
      native.reportedValues = {...native.disk, 'flutter.key': 'ghost'};
      await prefs.reload();
      expect(prefs.getString('key'), 'ghost');
      await expectLater(otherWrapper.readString('key'), throwsStateError);
      native.failKey = null;
      await otherWrapper.writeString('key', 'acknowledged retry');
      expect(native.disk['flutter.key'], 'acknowledged retry');
      expect(await storage.readString('key'), 'acknowledged retry');
    });

    test('原生 remove $mode：不能把缓存中的缺失当作删除成功', () async {
      await storage.writeString('key', 'confirmed');
      native.failKey = 'flutter.key';
      native.throwsNative = throwsNative;
      await expectLater(storage.remove('key'), getFailure());
      expect(prefs.getString('key'), isNull);
      expect(native.disk['flutter.key'], 'confirmed');
      await expectLater(otherWrapper.readString('key'), throwsStateError);
      native.failKey = null;
      await otherWrapper.remove('key');
      expect(await storage.readString('key'), isNull);
      expect(native.disk.containsKey('flutter.key'), isFalse);
    });

    test('写入 $mode 后成功确认 remove 也能解除隔离', () async {
      native.failKey = 'flutter.key';
      native.throwsNative = throwsNative;
      await expectLater(storage.writeString('key', 'ghost'), getFailure());
      native.failKey = null;
      await otherWrapper.remove('key');
      expect(await storage.readString('key'), isNull);
    });

    for (final failedKey in ['entries_v1', 'questions_v1', 'answers_v1']) {
      test('导入 $failedKey $mode：AppState/服务不计 ghost 成功，禁止后续快照', () async {
        final directory = await Directory.systemTemp.createTemp(
          'prefs-failure-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final state = await AppState.debug(storage);
        addTearDown(state.dispose);
        await state.bootstrap();
        final service = DataTransferService(
          backups: TransferBackupStore(directory: () async => directory),
          now: () => DateTime(2026, 9, 17, 12),
        );
        final plan = await service.prepare([_importFile()], state);
        expect(plan.addedCount, 1);
        native.failKey = 'flutter.$failedKey';
        native.throwsNative = throwsNative;
        final result = await service.execute(plan, state);
        expect(result.importedCount, 0);
        expect(result.failedCount, 1);
        expect(result.storageWarning, isNotNull);
        expect(native.disk.containsKey('flutter.$failedKey'), isFalse);
        expect(prefs.getString(failedKey), contains('ghost_'));
        expect(state.companion.growthDays, 0);
        expect(state.allEntries.length, failedKey == 'entries_v1' ? 0 : 1);
        if (failedKey == 'answers_v1') {
          expect(native.disk['flutter.entries_v1'], contains('ghost_entry'));
          expect(
            native.disk['flutter.questions_v1'],
            contains('ghost_question'),
          );
        }

        await expectLater(otherWrapper.readString(failedKey), throwsStateError);
        await expectLater(state.exportTransferData(), throwsStateError);
        final anotherState = await AppState.debug(otherWrapper);
        addTearDown(anotherState.dispose);
        await expectLater(anotherState.exportTransferData(), throwsStateError);

        // Only the pre-import backup exists. A second attempt cannot create a
        // backup/export from optimistic cache or silently turn failure to skip.
        final backupFiles = await directory
            .list(recursive: true)
            .where((e) => e is File)
            .cast<File>()
            .toList();
        expect(backupFiles, isNotEmpty);
        final pathsBefore = backupFiles.map((f) => f.path).toSet();
        for (final file in backupFiles) {
          expect(await file.readAsString(), isNot(contains('ghost_')));
        }
        await expectLater(
          service.execute(plan, anotherState),
          throwsStateError,
        );
        expect(
          (await directory
                  .list(recursive: true)
                  .where((e) => e is File)
                  .toList())
              .map((f) => f.path)
              .toSet(),
          pathsBefore,
        );
      });
    }
  }

  test('原生确认仍在进行时不允许从另一包装器读取乐观值', () async {
    final pending = Completer<bool>();
    final reachedNative = Completer<void>();
    native.response = (call) {
      reachedNative.complete();
      return pending.future;
    };
    final writing = storage.writeString('key', 'pending');
    await reachedNative.future;
    expect(prefs.getString('key'), 'pending');
    await expectLater(otherWrapper.readString('key'), throwsStateError);
    pending.complete(true);
    await writing;
    expect(await otherWrapper.readString('key'), 'pending');
  });

  test('同 key 并发乱序确认不能过早解禁，独立成功重试恢复', () async {
    final first = Completer<bool>();
    final second = Completer<bool>();
    final bothReached = Completer<void>();
    var calls = 0;
    native.response = (call) {
      calls++;
      if (calls == 2) bothReached.complete();
      return calls == 1 ? first.future : second.future;
    };
    final olderWrite = storage.writeString('key', 'older');
    final newerWrite = otherWrapper.writeString('key', 'newer');
    await bothReached.future;
    second.complete(true);
    await newerWrite;
    await expectLater(storage.readString('key'), throwsStateError);
    first.complete(true);
    await olderWrite;
    expect(native.disk['flutter.key'], 'older');
    expect(prefs.getString('key'), 'newer');
    await expectLater(otherWrapper.readString('key'), throwsStateError);
    native.response = null;
    await storage.writeString('key', 'retry');
    expect(native.disk['flutter.key'], 'retry');
    expect(await otherWrapper.readString('key'), 'retry');
  });
}

/// The actual SharedPreferences Dart cache is exercised. Only native responses
/// are mocked; no method is dispatched to the device or real user preferences.
class _NativePreferences {
  final disk = <String, Object>{};
  Map<String, Object>? reportedValues;
  String? failKey;
  bool throwsNative = false;
  Future<bool> Function(MethodCall call)? response;

  Future<Object?> handle(MethodCall call) async {
    if (call.method == 'getAll') {
      return Map<String, Object>.of(reportedValues ?? disk);
    }
    if (call.method != 'setString' && call.method != 'remove') {
      throw StateError('Unexpected native call: ${call.method}');
    }
    final args = call.arguments as Map;
    final key = args['key'] as String;
    if (key == failKey) {
      if (throwsNative) throw PlatformException(code: 'commit_failed');
      return false;
    }
    final acknowledged = response == null ? true : await response!(call);
    if (acknowledged) {
      if (call.method == 'remove') {
        disk.remove(key);
      } else {
        disk[key] = args['value'] as String;
      }
    }
    return acknowledged;
  }
}

ImportFile _importFile() {
  final date = DateTime(2020, 1, 1);
  final bytes = utf8.encode(
    encodeTransfer(
      TransferData(
        entries: [
          Entry(
            id: 'ghost_entry',
            date: date,
            task: 'historical entry',
            createdAt: date,
            updatedAt: date,
          ),
        ],
        questions: [
          EvidenceQuestion(
            id: 'ghost_question',
            entryId: 'ghost_entry',
            kind: QuestionKind.result,
            prompt: 'result?',
            reason: '',
            status: QuestionStatus.answered,
            createdAt: date,
            updatedAt: date,
          ),
        ],
        answers: [
          EvidenceAnswer(
            id: 'ghost_answer',
            questionId: 'ghost_question',
            content: 'answer',
            createdAt: date,
          ),
        ],
      ),
      exportedAt: date,
      appVersion: 'test',
    ),
  );
  return ImportFile(
    name: 'test.json',
    size: bytes.length,
    readBytes: () async => bytes,
  );
}
