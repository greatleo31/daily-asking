import 'package:daily_asking/artifacts/artifact_generation.dart';
import 'package:daily_asking/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 26, 10);
  final entries = [
    Entry(
      id: 'e1',
      date: DateTime(2026, 8, 25),
      task: '完成周报脚本',
      action: '编写自动化脚本',
      result: '新同事已跑通',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  const markdown = '''# 简历要点

## 简历要点（可直接使用）
编写自动化周报脚本，帮助新同事跑通流程。

## 逐条依据
来自「完成周报脚本」记录。

## 缺失与建议
缺少节省时间等量化结果。
''';

  test('Markdown 响应保存原文，不生成第二份 JSON', () {
    final artifact = buildGeneratedArtifact(
      id: 'a1',
      type: ArtifactType.resume,
      rawContent: markdown,
      sourceEntries: entries,
      generatedAt: now,
    );

    expect(artifact.hasStructuredContent, isFalse);
    expect(artifact.content, markdown);
    expect(artifact.structuredIssues, isEmpty);
    expect(artifact.risks, isEmpty);
    expect(artifact.gaps, isEmpty);
    expect(artifact.referenceDate, '2026-08-26');
  });

  test('旧 Markdown 响应仍保留全文且不添加虚假列表', () {
    const source = '## 风险\n\n无';
    final artifact = buildGeneratedArtifact(
      id: 'a2',
      type: ArtifactType.weekly,
      rawContent: source,
      sourceEntries: entries,
      generatedAt: now,
    );

    expect(artifact.hasStructuredContent, isFalse);
    expect(artifact.content, source);
    expect(artifact.structuredIssues, isEmpty);
  });

  test('来源证据生成后更新时判定产物过期', () {
    final artifact = buildGeneratedArtifact(
      id: 'a3',
      type: ArtifactType.resume,
      rawContent: markdown,
      sourceEntries: entries,
      generatedAt: now,
    );
    final changed = Entry.fromJson(entries.single.toJson())
      ..updatedAt = DateTime(2026, 8, 26, 11);

    expect(isArtifactStale(artifact, [changed]), isTrue);
    expect(isArtifactStale(artifact, entries), isFalse);
  });
}
