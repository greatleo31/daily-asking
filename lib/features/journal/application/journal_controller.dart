import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entry_repository.dart';
import '../domain/entry.dart';

final entryRepositoryProvider = Provider<EntryRepository>((ref) => EntryRepository());

final journalControllerProvider =
    StateNotifierProvider<JournalController, AsyncValue<List<Entry>>>((ref) {
  return JournalController(ref.watch(entryRepositoryProvider))..load();
});

class JournalController extends StateNotifier<AsyncValue<List<Entry>>> {
  JournalController(this._repository) : super(const AsyncValue.loading());

  final EntryRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.loadEntries);
  }

  Future<void> addEntry(Entry entry) async {
    final current = _loadedEntries();
    final next = [entry, ...current]..sort((a, b) => b.date.compareTo(a.date));
    await _persist(next);
  }

  Future<void> updateEntry(Entry entry) async {
    final current = _loadedEntries();
    final index = current.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      throw const EntryRepositoryException('要更新的记录不存在');
    }
    final next = <Entry>[...current];
    next[index] = entry;
    next.sort((a, b) => b.date.compareTo(a.date));
    await _persist(next);
  }

  Future<void> deleteEntry(String id) async {
    final current = _loadedEntries();
    final next = <Entry>[...current]..removeWhere((entry) => entry.id == id);
    await _persist(next);
  }

  List<Entry> _loadedEntries() {
    final current = state.value;
    if (state.hasError || current == null) {
      throw const EntryRepositoryException('记录尚未成功载入，不能写入以免覆盖本地数据');
    }
    return <Entry>[...current];
  }

  Future<void> _persist(List<Entry> next) async {
    state = AsyncValue.data(next);
    try {
      await _repository.saveEntries(next);
    } on Object catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
