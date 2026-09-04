/// 伙伴成长 Repository：封装 `companion_v1` 的读写。
///
/// 沿用 [JsonStore.readMap/writeMap]，不引入新依赖或第二套存储机制；
/// 缺省字段兼容、未知字段忽略由 [CompanionProfile.fromJson] 保证。
library;

import '../core/storage/storage.dart';
import 'companion_profile.dart';

/// 伙伴资料存取接口。
abstract class CompanionRepository {
  Future<CompanionProfile> load();
  Future<void> save(CompanionProfile profile);

  /// 独立重置：移除存储键，资料回到空状态（不触碰任何证据数据）。
  Future<void> reset();
}

/// 基于 JsonStore 的伙伴仓库实现。
class LocalCompanionRepository implements CompanionRepository {
  LocalCompanionRepository(this._store);

  final JsonStore _store;
  static const key = 'companion_v1';

  CompanionProfile? _cache;

  @override
  Future<CompanionProfile> load() async {
    if (_cache != null) return _cache!;
    final map = await _store.readMap(key);
    _cache = map == null ? CompanionProfile.empty : CompanionProfile.fromJson(map);
    return _cache!;
  }

  @override
  Future<void> save(CompanionProfile profile) async {
    await _store.writeMap(key, profile.toJson());
    _cache = profile;
  }

  @override
  Future<void> reset() async {
    await _store.remove(key);
    _cache = null;
  }
}
