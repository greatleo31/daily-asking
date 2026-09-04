import 'package:daily_asking/artifacts/artifact_library.dart';
import 'package:daily_asking/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Artifact _artifact({
  required String id,
  required ArtifactType type,
  required String content,
  required DateTime updatedAt,
}) => Artifact(
  id: id,
  type: type,
  content: content,
  sourceEntryIds: const [],
  risks: const [],
  gaps: const [],
  createdAt: updatedAt,
  updatedAt: updatedAt,
);

void main() {
  final artifacts = [
    _artifact(
      id: 'a2',
      type: ArtifactType.weekly,
      content: '# Beta\n\n内容',
      updatedAt: DateTime(2026, 8, 25),
    ),
    _artifact(
      id: 'a1',
      type: ArtifactType.resume,
      content: '# Alpha\n\n内容',
      updatedAt: DateTime(2026, 8, 26),
    ),
    _artifact(
      id: 'a3',
      type: ArtifactType.interview,
      content: '# Gamma\n\n内容',
      updatedAt: DateTime(2026, 8, 24),
    ),
  ];

  test('全部和三类虚拟目录按类型过滤', () {
    expect(filterArtifacts(artifacts, ArtifactLibraryFolder.all), hasLength(3));
    expect(
      filterArtifacts(artifacts, ArtifactLibraryFolder.resume).map((a) => a.id),
      ['a1'],
    );
  });

  test('默认按日期倒序，名称支持升降序', () {
    expect(
      sortArtifacts(
        artifacts,
        ArtifactSortField.date,
        ascending: false,
      ).map((a) => a.id),
      ['a1', 'a2', 'a3'],
    );
    expect(
      sortArtifacts(
        artifacts,
        ArtifactSortField.name,
        ascending: true,
      ).map((a) => a.id),
      ['a1', 'a2', 'a3'],
    );
  });
  test('显示名称来自标题而不是整段正文', () {
    final artifact = _artifact(
      id: 'a4',
      type: ArtifactType.weekly,
      content: '# 本周交付\n\n完成了 **迁移**',
      updatedAt: DateTime(2026, 8, 26),
    );
    expect(artifactDisplayName(artifact), '本周交付');
  });
}
