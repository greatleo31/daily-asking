/// artifacts 模块：产物的 Repository。
library;

import '../core/models.dart';
import '../core/storage/storage.dart';

/// 产物存取接口。
abstract class ArtifactRepository {
  Future<List<Artifact>> list();
  Future<Artifact?> find(String id);
  Future<void> save(Artifact artifact);
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
    final i = _cache.indexWhere((a) => a.id == artifact.id);
    if (i >= 0) {
      _cache[i] = artifact;
    } else {
      _cache.add(artifact);
    }
    _cache.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _store.writeList(_key, _cache.map((e) => e.toJson()).toList());
  }

  @override
  Future<void> delete(String id) async {
    await _ensure();
    _cache.removeWhere((a) => a.id == id);
    await _store.writeList(_key, _cache.map((e) => e.toJson()).toList());
  }
}

extension on Artifact {
  Artifact copy() => Artifact.fromJson(toJson());
}