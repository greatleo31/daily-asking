/// 产物文件库的纯数据操作：虚拟目录、显示名称和排序。
library;

import '../core/export/markdown_exporter.dart';
import '../core/models.dart';
import 'markdown_document.dart';

enum ArtifactLibraryFolder {
  all('全部', null),
  resume('简历要点', ArtifactType.resume),
  weekly('周报', ArtifactType.weekly),
  interview('面试反馈', ArtifactType.interview);

  const ArtifactLibraryFolder(this.label, this.type);
  final String label;
  final ArtifactType? type;
}

enum ArtifactSortField {
  name('名称'),
  date('日期'),
  type('类型');

  const ArtifactSortField(this.label);
  final String label;
}

List<Artifact> filterArtifacts(
  List<Artifact> artifacts,
  ArtifactLibraryFolder folder,
) {
  final type = folder.type;
  if (type == null) return List.of(artifacts);
  return artifacts.where((artifact) => artifact.type == type).toList();
}

List<Artifact> sortArtifacts(
  List<Artifact> artifacts,
  ArtifactSortField field, {
  required bool ascending,
}) {
  final result = List<Artifact>.of(artifacts);
  result.sort((a, b) {
    final comparison = switch (field) {
      ArtifactSortField.name => artifactDisplayName(
        a,
      ).toLowerCase().compareTo(artifactDisplayName(b).toLowerCase()),
      ArtifactSortField.date => a.updatedAt.compareTo(b.updatedAt),
      ArtifactSortField.type => a.type.label.compareTo(b.type.label),
    };
    if (comparison != 0) return ascending ? comparison : -comparison;
    return a.id.compareTo(b.id);
  });
  return result;
}

String artifactDisplayName(Artifact artifact) {
  final document = parseMarkdownDocument(artifactMarkdownSource(artifact));
  for (final block in document.blocks) {
    if (block.type == MarkdownBlockType.heading) {
      final heading = block.raw
          .replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '')
          .trim();
      if (heading.isNotEmpty) return heading;
    }
  }
  for (final block in document.blocks) {
    final line = block.raw.split('\n').first.trim();
    if (line.isNotEmpty) {
      return line.length > 32 ? '${line.substring(0, 32)}…' : line;
    }
  }
  return artifact.type.label;
}
