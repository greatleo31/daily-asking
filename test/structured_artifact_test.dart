import 'dart:convert';

import 'package:daily_asking/artifacts/structured_artifact.dart';
import 'package:daily_asking/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> validResumeJson() => {
        'schemaVersion': 'artifact.v1',
        'artifactType': 'resume',
        'title': '简历要点',
        'summary': '有真实行动记录，但结果证据仍需补充。',
        'sections': [
          {
            'id': 'resumeBullets',
            'title': '可直接使用',
            'items': [
              {
                'text': '优化周报脚本，帮助新同事跑通工作流。',
                'evidenceRefs': ['e1'],
                'missingProof': ['节省时间'],
                'status': 'needs_verification',
              },
            ],
          },
          {
            'id': 'evidenceBasis',
            'title': '逐条依据',
            'items': [
              {'text': '来自 e1 的周报脚本记录', 'evidenceRefs': ['e1']},
            ],
          },
          {
            'id': 'missingEvidence',
            'title': '缺失证据',
            'items': [
              {'text': '缺少量化结果', 'evidenceRefs': []},
            ],
          },
        ],
        'evidenceRefs': ['e1'],
        'missingEvidence': ['节省时间'],
        'risks': ['数字需要人工核对'],
        'referenceDate': '2026-08-26',
        'promptVersion': 'resume.v2',
      };

  group('parseStructuredArtifact', () {
    test('解析合法结构化结果并保留专属条目字段', () {
      final result = parseStructuredArtifact(
        jsonEncode(validResumeJson()),
        expectedType: ArtifactType.resume,
        allowedEvidenceRefs: const {'e1'},
      );

      expect(result.isStructured, isTrue);
      expect(result.isNeedsReview, isFalse);
      expect(result.document, isNotNull);
      expect(result.document!.sections.singleWhere((s) => s.id == 'resumeBullets').items.single.text,
          contains('周报脚本'));
      expect(
        result.document!.sections.singleWhere((s) => s.id == 'resumeBullets').items.single.missingProof,
        ['节省时间'],
      );
    });

    test('支持 ```json 围栏并归一化输出', () {
      final result = parseStructuredArtifact(
        '```json\n${jsonEncode(validResumeJson())}\n```',
        expectedType: ArtifactType.resume,
        allowedEvidenceRefs: const {'e1'},
      );

      expect(result.isStructured, isTrue);
      expect(result.document!.toJson()['schemaVersion'], 'artifact.v1');
    });

    test('缺少产物专属必需章节进入人工核对状态', () {
      final json = validResumeJson();
      (json['sections'] as List).removeWhere(
          (section) => section['id'] == 'missingEvidence');
      final result = parseStructuredArtifact(
        jsonEncode(json),
        expectedType: ArtifactType.resume,
        allowedEvidenceRefs: const {'e1'},
      );

      expect(result.isStructured, isTrue);
      expect(result.isNeedsReview, isTrue);
      expect(result.issues, contains(contains('missingEvidence')));
    });

    test('未知证据引用进入人工核对状态而不是静默通过', () {
      final json = validResumeJson();
      (json['sections'] as List).first['items'][0]['evidenceRefs'] = ['unknown'];
      final result = parseStructuredArtifact(
        jsonEncode(json),
        expectedType: ArtifactType.resume,
        allowedEvidenceRefs: const {'e1'},
      );

      expect(result.isStructured, isTrue);
      expect(result.isNeedsReview, isTrue);
      expect(result.issues, contains(contains('unknown')));
    });

    test('产物类型不匹配进入人工核对状态', () {
      final json = validResumeJson()..['artifactType'] = 'weekly';
      final result = parseStructuredArtifact(
        jsonEncode(json),
        expectedType: ArtifactType.resume,
        allowedEvidenceRefs: const {'e1'},
      );

      expect(result.isStructured, isTrue);
      expect(result.isNeedsReview, isTrue);
      expect(result.issues, contains(contains('产物类型')));
    });

    test('旧 Markdown 不被当作结构化结果，调用方可以回退原文', () {
      final result = parseStructuredArtifact(
        '# 简历要点\n\n## 可直接使用\n- 完成 A 项目',
        expectedType: ArtifactType.resume,
        allowedEvidenceRefs: const {'e1'},
      );

      expect(result.isStructured, isFalse);
      expect(result.document, isNull);
      expect(result.isLegacyContent, isTrue);
    });

    test('缺少必填字段返回解析问题而不是抛异常', () {
      final result = parseStructuredArtifact(
        jsonEncode({'schemaVersion': 'artifact.v1'}),
        expectedType: ArtifactType.resume,
        allowedEvidenceRefs: const {'e1'},
      );

      expect(result.isStructured, isFalse);
      expect(result.issues, isNotEmpty);
    });
  });
}
