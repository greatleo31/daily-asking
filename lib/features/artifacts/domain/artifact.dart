enum ArtifactType { followUp, resumeBullet, weeklyReport, interviewCard }

extension ArtifactTypeLabel on ArtifactType {
  String get label {
    return switch (this) {
      ArtifactType.followUp => 'AI 追问',
      ArtifactType.resumeBullet => '简历 bullet',
      ArtifactType.weeklyReport => '周报',
      ArtifactType.interviewCard => '面试追问卡',
    };
  }

  String get promptId {
    return switch (this) {
      ArtifactType.followUp => 'follow_up',
      ArtifactType.resumeBullet => 'resume_bullet',
      ArtifactType.weeklyReport => 'weekly_report',
      ArtifactType.interviewCard => 'interview_card',
    };
  }
}

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
