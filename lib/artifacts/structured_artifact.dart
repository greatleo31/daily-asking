/// 结构化产物契约：模型输出 JSON，旧 Markdown 作为兼容回退。
library;

import 'dart:convert';

import '../core/models.dart';

const String structuredArtifactSchemaVersion = 'artifact.v1';

/// 结构化结果条目。
class StructuredArtifactItem {
  const StructuredArtifactItem({
    required this.text,
    this.evidenceRefs = const [],
    this.missingProof = const [],
    this.status,
    this.details = const {},
  });

  final String text;
  final List<String> evidenceRefs;
  final List<String> missingProof;
  final String? status;
  final Map<String, dynamic> details;

  String? detail(String key) {
    final value = details[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'evidenceRefs': evidenceRefs,
        'missingProof': missingProof,
        if (status != null) 'status': status,
        if (details.isNotEmpty) 'details': details,
      };
}

/// 结构化产物章节。
class StructuredArtifactSection {
  const StructuredArtifactSection({
    required this.id,
    required this.title,
    this.items = const [],
  });

  final String id;
  final String title;
  final List<StructuredArtifactItem> items;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'items': items.map((item) => item.toJson()).toList(),
      };
}

/// 三类产物共享的结构化文档。
class StructuredArtifactDocument {
  const StructuredArtifactDocument({
    required this.schemaVersion,
    required this.artifactType,
    required this.title,
    required this.summary,
    required this.sections,
    required this.evidenceRefs,
    required this.missingEvidence,
    required this.risks,
    this.referenceDate,
    this.promptVersion,
  });

  final String schemaVersion;
  final ArtifactType artifactType;
  final String? title;
  final String? summary;
  final List<StructuredArtifactSection> sections;
  final List<String> evidenceRefs;
  final List<String> missingEvidence;
  final List<String> risks;
  final String? referenceDate;
  final String? promptVersion;

  StructuredArtifactSection? section(String id) {
    for (final section in sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'artifactType': artifactType.name,
        if (title != null) 'title': title,
        if (summary != null) 'summary': summary,
        'sections': sections.map((section) => section.toJson()).toList(),
        'evidenceRefs': evidenceRefs,
        'missingEvidence': missingEvidence,
        'risks': risks,
        if (referenceDate != null) 'referenceDate': referenceDate,
        if (promptVersion != null) 'promptVersion': promptVersion,
      };
}

/// 结构化解析结果。
class StructuredArtifactParseResult {
  const StructuredArtifactParseResult({
    this.document,
    this.issues = const [],
    this.isLegacyContent = false,
  });

  final StructuredArtifactDocument? document;
  final List<String> issues;
  final bool isLegacyContent;

  bool get isStructured => document != null;
  bool get isNeedsReview => isStructured && issues.isNotEmpty;
}

/// 解析并校验模型输出。
///
/// 仅识别原始 JSON 或 ```json 围栏中的 JSON；其它内容视为旧 Markdown，
/// 由调用方继续走 Markdown 解析回退，不会把普通文本误报为结构化结果。
StructuredArtifactParseResult parseStructuredArtifact(
  String content, {
  required ArtifactType expectedType,
  required Set<String> allowedEvidenceRefs,
}) {
  final source = _extractJsonSource(content);
  if (source == null) {
    return const StructuredArtifactParseResult(isLegacyContent: true);
  }

  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    return const StructuredArtifactParseResult(issues: ['结构化结果不是合法 JSON']);
  }
  if (decoded is! Map) {
    return const StructuredArtifactParseResult(issues: ['结构化结果必须是 JSON 对象']);
  }

  final json = Map<String, dynamic>.from(decoded);
  final issues = <String>[];
  final schemaVersion = json['schemaVersion'];
  if (schemaVersion is! String || schemaVersion.trim().isEmpty) {
    issues.add('缺少 schemaVersion');
  } else if (schemaVersion != structuredArtifactSchemaVersion) {
    issues.add('不支持的 schemaVersion：$schemaVersion');
  }

  final rawType = json['artifactType'];
  ArtifactType? artifactType;
  if (rawType is! String) {
    issues.add('缺少 artifactType');
  } else {
    for (final type in ArtifactType.values) {
      if (type.name == rawType) {
        artifactType = type;
        break;
      }
    }
    if (artifactType == null) issues.add('未知 artifactType：$rawType');
  }
  if (artifactType != null && artifactType != expectedType) {
    issues.add('产物类型不匹配：期望 ${expectedType.name}，实际 ${artifactType.name}');
  }

  final rawSections = json['sections'];
  if (rawSections is! List) {
    issues.add('缺少 sections 数组');
  }
  if (artifactType == null || rawSections is! List) {
    return StructuredArtifactParseResult(issues: List.unmodifiable(issues));
  }

  final sections = <StructuredArtifactSection>[];
  final sectionIds = <String>{};
  for (var index = 0; index < rawSections.length; index++) {
    final rawSection = rawSections[index];
    if (rawSection is! Map) {
      issues.add('sections[$index] 不是对象');
      continue;
    }
    final section = Map<String, dynamic>.from(rawSection);
    final id = section['id'];
    final title = section['title'];
    final rawItems = section['items'];
    if (id is! String || id.trim().isEmpty) {
      issues.add('sections[$index] 缺少 id');
      continue;
    }
    if (title is! String || title.trim().isEmpty) {
      issues.add('sections[$index] 缺少 title');
      continue;
    }
    if (!sectionIds.add(id)) {
      issues.add('sections[$index] 的 id 重复：$id');
    }
    if (rawItems is! List) {
      issues.add('sections[$index] 缺少 items 数组');
      continue;
    }

    final items = <StructuredArtifactItem>[];
    for (var itemIndex = 0; itemIndex < rawItems.length; itemIndex++) {
      final rawItem = rawItems[itemIndex];
      if (rawItem is! Map) {
        issues.add('sections[$index].items[$itemIndex] 不是对象');
        continue;
      }
      final item = Map<String, dynamic>.from(rawItem);
      final text = item['text'];
      if (text is! String || text.trim().isEmpty) {
        issues.add('sections[$index].items[$itemIndex] 缺少 text');
        continue;
      }
      final hasEvidenceRefs = item.containsKey('evidenceRefs');
      if (!hasEvidenceRefs) {
        issues.add('sections[$index].items[$itemIndex] 缺少 evidenceRefs');
      }
      final refs = _stringList(item['evidenceRefs'], issues,
          'sections[$index].items[$itemIndex].evidenceRefs');
      final missingProof = _stringList(item['missingProof'], issues,
          'sections[$index].items[$itemIndex].missingProof');
      final status = item['status'];
      if (status != null && status is! String) {
        issues.add('sections[$index].items[$itemIndex].status 必须是字符串');
      } else if (status is String &&
          status != 'supported' &&
          status != 'needs_verification') {
        issues.add('sections[$index].items[$itemIndex].status 值不支持：$status');
      }
      final rawDetails = item['details'];
      Map<String, dynamic> details = const {};
      if (rawDetails != null) {
        if (rawDetails is Map) {
          details = Map<String, dynamic>.from(rawDetails);
        } else {
          issues.add('sections[$index].items[$itemIndex].details 必须是对象');
        }
      }
      items.add(StructuredArtifactItem(
        text: text.trim(),
        evidenceRefs: refs,
        missingProof: missingProof,
        status: status is String ? status.trim() : null,
        details: details,
      ));
    }
    sections.add(StructuredArtifactSection(
      id: id.trim(),
      title: title.trim(),
      items: items,
    ));
  }
  final requiredSectionIds = switch (artifactType) {
    ArtifactType.resume => const ['resumeBullets', 'evidenceBasis', 'missingEvidence'],
    ArtifactType.weekly => const [
        'completed',
        'inProgress',
        'risks',
        'verifiedOutcomes',
        'nextSuggestions',
      ],
    ArtifactType.interview => const [
        'overall',
        'itemFeedback',
        'learningDirections',
        'topThree',
      ],
  };
  for (final requiredId in requiredSectionIds) {
    if (!sectionIds.contains(requiredId)) {
      issues.add('缺少产物专属必需章节：$requiredId');
    }
  }

  final evidenceRefs =
      _requiredStringList(json, 'evidenceRefs', issues);
  final missingEvidence =
      _requiredStringList(json, 'missingEvidence', issues);
  final risks = _requiredStringList(json, 'risks', issues);
  final allRefs = <String>{...evidenceRefs};
  for (final section in sections) {
    for (final item in section.items) {
      allRefs.addAll(item.evidenceRefs);
    }
  }
  final unknownRefs = allRefs.difference(allowedEvidenceRefs);
  if (unknownRefs.isNotEmpty) {
    issues.add('存在未选中的记录引用：${unknownRefs.toList()..sort()}');
  }
  final itemOnlyRefs = allRefs.difference(evidenceRefs.toSet());
  if (itemOnlyRefs.isNotEmpty) {
    issues.add('顶层 evidenceRefs 缺少条目引用：${itemOnlyRefs.toList()..sort()}');
  }

  final title = _optionalString(json['title'], issues, 'title');
  final summary = _optionalString(json['summary'], issues, 'summary');
  final referenceDate =
      _optionalString(json['referenceDate'], issues, 'referenceDate');
  final promptVersion =
      _optionalString(json['promptVersion'], issues, 'promptVersion');

  return StructuredArtifactParseResult(
    document: StructuredArtifactDocument(
      schemaVersion: schemaVersion is String
          ? schemaVersion
          : structuredArtifactSchemaVersion,
      artifactType: artifactType,
      title: title,
      summary: summary,
      sections: sections,
      evidenceRefs: evidenceRefs,
      missingEvidence: missingEvidence,
      risks: risks,
      referenceDate: referenceDate,
      promptVersion: promptVersion,
    ),
    issues: List.unmodifiable(issues),
  );
}

String? _extractJsonSource(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('```')) {
    final firstNewline = trimmed.indexOf('\n');
    if (firstNewline < 0) return trimmed.substring(3).trim();
    var body = trimmed.substring(firstNewline + 1).trim();
    if (body.endsWith('```')) {
      body = body.substring(0, body.length - 3).trim();
    }
    return body;
  }
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return trimmed;
  return null;
}

List<String> _requiredStringList(
    Map<String, dynamic> json, String key, List<String> issues) {
  if (!json.containsKey(key)) {
    issues.add('缺少 $key 数组');
    return const [];
  }
  return _stringList(json[key], issues, key);
}

List<String> _stringList(Object? value, List<String> issues, String path) {
  if (value == null) return const [];
  if (value is! List) {
    issues.add('$path 必须是字符串数组');
    return const [];
  }
  final result = <String>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! String) {
      issues.add('$path[$index] 必须是字符串');
      continue;
    }
    final text = item.trim();
    if (text.isNotEmpty) result.add(text);
  }
  return result;
}

String? _optionalString(Object? value, List<String> issues, String path) {
  if (value == null) return null;
  if (value is! String) {
    issues.add('$path 必须是字符串');
    return null;
  }
  final text = value.trim();
  return text.isEmpty ? null : text;
}
