enum ArtifactType { resumeBullet, weeklyReport, interviewCard }

class Artifact {
  const Artifact({
    required this.id,
    required this.type,
    required this.sourceEntryIds,
    required this.content,
    required this.promptVersion,
    required this.modelInfo,
    required this.createdAt,
  });

  final String id;
  final ArtifactType type;
  final List<String> sourceEntryIds;
  final String content;
  final int promptVersion;
  final String modelInfo;
  final DateTime createdAt;
}
