/// artifacts 模块：产物的 Repository。
library;

import '../core/models.dart';
import '../core/storage/storage.dart';

/// 产物存取接口。
abstract class ArtifactRepository {
  Future<List<Artifact>> list();
  Future<Artifact?> find(String id);
  Future<void> save(Artifact artifact);
  Future<void> saveAll(List<Artifact> artifacts);
  Future<void> delete(String id);
}

class LocalArtifactRepository implements ArtifactRepository {
  LocalArtifactRepository(this._store);

  final JsonStore _store;
  static const _key = 'artifacts_v1';
  List<Artifact> _cache = [];
  bool _loaded = false;

  Future<void> _ensure() async {
    if (_loaded) return;
    _cache = (await _store.readList(_key)).map(Artifact.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _loaded = true;
  }

  @override
  Future<List<Artifact>> list() async {
    await _ensure();
    return List.of(_cache);
  }

  @override
  Future<Artifact?> find(String id) async {
    await _ensure();
    for (final a in _cache) {
      if (a.id == id) return a.copy();
    }
    return null;
  }

  @override
  Future<void> save(Artifact artifact) async {
    await _ensure();
    final next = List<Artifact>.of(_cache);
    final i = next.indexWhere((a) => a.id == artifact.id);
    if (i >= 0) {
      next[i] = artifact;
    } else {
      next.add(artifact);
    }
    await _persist(next);
  }

  /// 一批合并后只写一次，并隔离导入方持有的可变列表。
  @override
  Future<void> saveAll(List<Artifact> artifacts) async {
    final rows = await _store.readList(_key);
    final merged = <String, Artifact>{
      for (final row in rows) row['id'] as String: Artifact.fromJson(row),
      for (final artifact in artifacts)
        artifact.id: Artifact.fromJson({
          ...artifact.toJson(),
          'sourceEntryIds': List<String>.of(artifact.sourceEntryIds),
          'risks': List<String>.of(artifact.risks),
          'gaps': List<String>.of(artifact.gaps),
          'structuredIssues': List<String>.of(artifact.structuredIssues),
        }),
    };
    await _persist(merged.values.toList());
    _loaded = true;
  }

  @override
  Future<void> delete(String id) async {
    await _ensure();
    await _persist(_cache.where((a) => a.id != id).toList());
  }

  Future<void> _persist(List<Artifact> next) async {
    next.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _store.writeList(_key, next.map((e) => e.toJson()).toList());
    _cache = next;
  }
}

extension on Artifact {
  Artifact copy() => Artifact.fromJson(toJson());
}
