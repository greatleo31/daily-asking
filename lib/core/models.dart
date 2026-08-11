/// 领域模型：晨昏证据图谱。
///
/// 所有实体都是纯 Dart 对象，通过 `fromJson/toJson` 序列化，
/// 与具体持久化方案（当前为本地 JSON，后续可替换为 SQLite/Drift）解耦。
library;

/// 一条职场证据记录（每天一句话事实及其上下文）。
class Entry {
  Entry({
    required this.id,
    required this.date,
    this.task = '',
    this.context = '',
    this.action = '',
    this.result = '',
    this.blocker = '',
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime date; // 记录归属的"那一天"
  String task; // 一句话事实（必填）
  String context; // 背景
  String action; // 具体行动
  String result; // 结果 / 可验证变化
  String blocker; // 难点 / 取舍
  List<String> tags;
  final DateTime createdAt;
  DateTime updatedAt;

  /// 证据完整度：已填写的核心叙事字段（不含 tags）占比。
  int completenessPercent() {
    const fields = ['task', 'context', 'action', 'result', 'blocker'];
    final filled = fields
        .where((f) => (f == 'task' ? task : _fieldValue(f)).trim().isNotEmpty)
        .length;
    return (filled / fields.length * 100).round();
  }

  String _fieldValue(String f) {
    switch (f) {
      case 'context':
        return context;
      case 'action':
        return action;
      case 'result':
        return result;
      case 'blocker':
        return blocker;
      default:
        return '';
    }
  }

  /// 判断某"叙事字段"是否空缺。
  bool isFieldEmpty(String field) {
    final v = _fieldValue(field);
    return v.trim().isEmpty;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'task': task,
        'context': context,
        'action': action,
        'result': result,
        'blocker': blocker,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        task: json['task'] as String? ?? '',
        context: json['context'] as String? ?? '',
        action: json['action'] as String? ?? '',
        result: json['result'] as String? ?? '',
        blocker: json['blocker'] as String? ?? '',
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Entry copy() => Entry.fromJson(toJson());
}

/// 追问类型。
enum QuestionKind {
  result('结果/验证', '结果'),
  context('背景', '背景'),
  action('具体行动', '行动'),
  blocker('难点/取舍', '难点'),
  contribution('个人贡献', '贡献');

  const QuestionKind(this.label, this.field);
  final String label;
  final String field;
}

enum QuestionStatus { pending, answered, later, skip }

/// 一条本地规则生成的追问。
class EvidenceQuestion {
  EvidenceQuestion({
    required this.id,
    required this.entryId,
    required this.kind,
    required this.prompt,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String entryId;
  final QuestionKind kind;
  final String prompt;
  final String reason;
  QuestionStatus status;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'entryId': entryId,
        'kind': kind.name,
        'prompt': prompt,
        'reason': reason,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EvidenceQuestion.fromJson(Map<String, dynamic> json) =>
      EvidenceQuestion(
        id: json['id'] as String,
        entryId: json['entryId'] as String,
        kind: QuestionKind.values.byName(json['kind'] as String),
        prompt: json['prompt'] as String,
        reason: json['reason'] as String? ?? '',
        status:
            QuestionStatus.values.byName(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// 追问的回答。
class EvidenceAnswer {
  EvidenceAnswer({
    required this.id,
    required this.questionId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String questionId;
  String content;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'questionId': questionId,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory EvidenceAnswer.fromJson(Map<String, dynamic> json) => EvidenceAnswer(
        id: json['id'] as String,
        questionId: json['questionId'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// 产物类型。
enum ArtifactType {
  resume('简历要点'),
  weekly('周报'),
  interview('面试追问卡');

  const ArtifactType(this.label);
  final String label;
}

/// 工作室生成的一份产物。
class Artifact {
  Artifact({
    required this.id,
    required this.type,
    required this.content,
    required this.sourceEntryIds,
    required this.risks,
    required this.gaps,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ArtifactType type;
  String content;
  final List<String> sourceEntryIds;
  final List<String> risks; // 风险提示
  final List<String> gaps; // 缺失证据
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
        'sourceEntryIds': sourceEntryIds,
        'risks': risks,
        'gaps': gaps,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Artifact.fromJson(Map<String, dynamic> json) => Artifact(
        id: json['id'] as String,
        type: ArtifactType.values.byName(json['type'] as String),
        content: json['content'] as String,
        sourceEntryIds: (json['sourceEntryIds'] as List?)?.cast<String>() ??
            const [],
        risks: (json['risks'] as List?)?.cast<String>() ?? const [],
        gaps: (json['gaps'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

// 修复上面 extension 与字段名冲突的写法（避免自赋值）。