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
    final current = state.value ?? [];
    final next = [entry, ...current]..sort((a, b) => b.date.compareTo(a.date));
    state = AsyncValue.data(next);
    await _repository.saveEntries(next);
  }

  Future<void> deleteEntry(String id) async {
    final next = [...state.value ?? []]..removeWhere((entry) => entry.id == id);
    state = AsyncValue.data(next);
    await _repository.saveEntries(next);
  }
}
