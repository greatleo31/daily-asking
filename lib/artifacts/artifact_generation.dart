/// Markdown-first 产物生成结果的确定性组装与新鲜度检查。
library;

import '../core/llm/prompts.dart';
import '../core/models.dart';

/// 保存 API 返回的 Markdown 原文，不做二次结构化或语法清理。
Artifact buildGeneratedArtifact({
  required String id,
  required ArtifactType type,
  required String rawContent,
  required List<Entry> sourceEntries,
  required DateTime generatedAt,
}) {
  return Artifact(
    id: id,
    type: type,
    content: rawContent,
    sourceEntryIds: sourceEntries.map((e) => e.id).toList(),
    risks: const [],
    gaps: const [],
    createdAt: generatedAt,
    updatedAt: generatedAt,
    referenceDate: generatedAt.toIso8601String().substring(0, 10),
    promptVersion: artifactPromptVersion,
  );
}

/// 产物是否引用了生成后被修改过的来源证据。
bool isArtifactStale(Artifact artifact, List<Entry> currentEntries) {
  final byId = {for (final entry in currentEntries) entry.id: entry};
  for (final id in artifact.sourceEntryIds) {
    final entry = byId[id];
    if (entry != null && entry.updatedAt.isAfter(artifact.updatedAt)) {
      return true;
    }
  }
  return false;
}
