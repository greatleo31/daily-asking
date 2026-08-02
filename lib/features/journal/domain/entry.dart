import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Entry {
  Entry({
    required this.id,
    required this.date,
    required this.task,
    this.context = '',
    this.action = '',
    this.result = '',
    this.blocker = '',
    this.tags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Entry.create({
    required String task,
    String context = '',
    String action = '',
    String result = '',
    String blocker = '',
    List<String> tags = const [],
    DateTime? date,
  }) {
    return Entry(
      id: _uuid.v4(),
      date: date ?? DateTime.now(),
      task: task,
      context: context,
      action: action,
      result: result,
      blocker: blocker,
      tags: tags,
    );
  }

  final String id;
  final DateTime date;
  final String task;
  final String context;
  final String action;
  final String result;
  final String blocker;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Entry copyWith({
    DateTime? date,
    String? task,
    String? context,
    String? action,
    String? result,
    String? blocker,
    List<String>? tags,
  }) {
    return Entry(
      id: id,
      date: date ?? this.date,
      task: task ?? this.task,
      context: context ?? this.context,
      action: action ?? this.action,
      result: result ?? this.result,
      blocker: blocker ?? this.blocker,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
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

  static Entry fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      task: json['task'] as String? ?? '',
      context: json['context'] as String? ?? '',
      action: json['action'] as String? ?? '',
      result: json['result'] as String? ?? '',
      blocker: json['blocker'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
