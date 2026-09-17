/// 自动快照：单文件或完整分片批次；仅保留最近三个已完成批次。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class TransferBackupStore {
  TransferBackupStore({Future<Directory> Function()? directory})
    : _directory = directory ?? _nativeDirectory;

  final Future<Directory> Function() _directory;
  static const _channel = MethodChannel('com.dailyasking.daily_asking/export');
  static final _batchName = RegExp(
    r'^auto-(\d{8}-\d{6})(?:-(\d+))?(?:\.json)?$',
  );

  static Future<Directory> _nativeDirectory() async {
    final path = await _channel.invokeMethod<String>('getBackupDirectory');
    if (path == null || path.isEmpty) {
      throw const FileSystemException('无法获取自动备份目录');
    }
    return Directory(path);
  }

  String _name(FileSystemEntity entity) =>
      entity.path.replaceAll('\\', '/').split('/').last;

  Future<List<FileSystemEntity>> _batches(Directory directory) async {
    if (!await directory.exists()) return [];
    final batches = <FileSystemEntity>[];
    await for (final entity in directory.list(followLinks: false)) {
      if ((entity is File || entity is Directory) &&
          _batchName.hasMatch(_name(entity))) {
        batches.add(entity);
      }
    }
    final modified = <String, DateTime>{};
    for (final batch in batches) {
      modified[batch.path] = (await batch.stat()).modified;
    }
    batches.sort((a, b) {
      final order = modified[b.path]!.compareTo(modified[a.path]!);
      if (order != 0) return order;
      final aMatch = _batchName.firstMatch(_name(a))!;
      final bMatch = _batchName.firstMatch(_name(b))!;
      final stampOrder = bMatch.group(1)!.compareTo(aMatch.group(1)!);
      if (stampOrder != 0) return stampOrder;
      return int.parse(
        bMatch.group(2) ?? '0',
      ).compareTo(int.parse(aMatch.group(2) ?? '0'));
    });
    return batches;
  }

  Future<DateTime?> latestBackupAt() async {
    final batches = await _batches(await _directory());
    return batches.isEmpty ? null : (await batches.first.stat()).modified;
  }

  Future<void> writeSnapshot(String content, {required DateTime now}) =>
      _commit([content], now: now);

  Future<void> writeSnapshotParts(List<String> parts, {required DateTime now}) {
    if (parts.isEmpty) throw ArgumentError.value(parts, 'parts', '快照不能为空');
    // 保留单文件接口的可注入性与原有路径。
    if (parts.length == 1) return writeSnapshot(parts.single, now: now);
    return _commit(parts, now: now);
  }

  Future<void> _commit(List<String> parts, {required DateTime now}) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final existing = await _batches(directory);
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    var sequence = 0;
    for (final batch in existing) {
      final match = _batchName.firstMatch(_name(batch))!;
      if (match.group(1) == stamp) {
        final next = int.parse(match.group(2) ?? '0') + 1;
        if (next > sequence) sequence = next;
      }
    }
    String stem() =>
        '${directory.path}/auto-$stamp${sequence == 0 ? '' : '-$sequence'}';
    // 不覆盖未完成的临时批次，同秒多次确认也不复用已有文件名。
    while (await FileSystemEntity.type(stem()) !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type('${stem()}.json') !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type('${stem()}.pending') !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type('${stem()}.json.pending') !=
            FileSystemEntityType.notFound) {
      sequence++;
    }
    if (parts.length == 1) {
      final target = '${stem()}.json';
      final pending = File('$target.pending');
      await pending.writeAsString(parts.single, encoding: utf8, flush: true);
      await pending.rename(target);
    } else {
      final target = stem();
      final pending = Directory('$target.pending');
      await pending.create();
      final count = parts.length.toString().padLeft(3, '0');
      for (var i = 0; i < parts.length; i++) {
        final part = (i + 1).toString().padLeft(3, '0');
        await File(
          '${pending.path}/part-$part-of-$count.json',
        ).writeAsString(parts[i], encoding: utf8, flush: true);
      }
      // 全部分片完成后才发布批次目录；失败不删除旧快照。
      await pending.rename(target);
    }
    // 当前完整批次 + 最近两个旧批次；按批删除，绝不拆散一份备份。
    for (final old in existing.skip(2)) {
      await old.delete(recursive: old is Directory);
    }
  }
}
