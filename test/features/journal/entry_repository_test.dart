import 'package:daily_asking/features/journal/data/entry_repository.dart';
import 'package:daily_asking/features/journal/domain/entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('creates, reads, updates, deletes, and sorts entries', () async {
    final repository = EntryRepository();
    final older = Entry(
      id: 'older',
      date: DateTime(2026, 8, 1, 9),
      task: '整理竞品价格页',
      createdAt: DateTime(2026, 8, 1, 9),
      updatedAt: DateTime(2026, 8, 1, 9),
    );
    final newer = Entry(
      id: 'newer',
      date: DateTime(2026, 8, 2, 9),
      task: '完成周报草稿',
      createdAt: DateTime(2026, 8, 2, 9),
      updatedAt: DateTime(2026, 8, 2, 9),
    );

    await repository.addEntry(older);
    await repository.addEntry(newer);

    expect((await repository.loadEntries()).map((entry) => entry.id), ['newer', 'older']);

    final updatedOlder = older.copyWith(
      task: '整理竞品价格页截图',
      result: '沉淀 12 张截图',
      updatedAt: DateTime(2026, 8, 3, 9),
    );
    await repository.updateEntry(updatedOlder);

    final afterUpdate = await repository.loadEntries();
    expect(afterUpdate.singleWhere((entry) => entry.id == 'older').task, '整理竞品价格页截图');
    expect(afterUpdate.singleWhere((entry) => entry.id == 'older').updatedAt.isAfter(older.createdAt), isTrue);

    await repository.deleteEntry('newer');

    expect((await repository.loadEntries()).map((entry) => entry.id), ['older']);
  });

  test('does not overwrite corrupt local payload when loading fails', () async {
    SharedPreferences.setMockInitialValues({EntryRepository.storageKey: '{broken json'});
    final repository = EntryRepository();

    await expectLater(repository.loadEntries(), throwsA(isA<EntryRepositoryException>()));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(EntryRepository.storageKey), '{broken json');
  });
}
