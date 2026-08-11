// 解析归一化测试：覆盖 content 为 String、多模态数组、responses 风格、异常等形态。
import 'dart:convert';

import 'package:daily_asking/core/llm/llm_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenAiClient.parseResponseBytes', () {
    test('标准 OpenAI content 字符串', () {
      final body = utf8.encode(jsonEncode({
        'choices': [
          {
            'message': {'content': ' 你好，这是正文。 '}
          }
        ]
      }));
      final r = OpenAiClient.parseResponseBytes(body);
      expect(r.isError, isFalse);
      expect(r.content, '你好，这是正文。');
    });

    test('content 为多模态数组时拼接 text 块', () {
      final body = utf8.encode(jsonEncode({
        'choices': [
          {
            'message': {
              'content': [
                {'type': 'text', 'text': '第一段。'},
                {'type': 'text', 'text': '第二段。'}
              ]
            }
          }
        ]
      }));
      final r = OpenAiClient.parseResponseBytes(body);
      expect(r.isError, isFalse);
      expect(r.content, '第一段。\n第二段。');
    });

    test('content 为空但 message 平铺有正文（responses 风格兜底）', () {
      final body = utf8.encode(jsonEncode({
        'message': {
          'content': [
            {'type': 'output_text', 'text': '响应的最终文本。'}
          ]
        }
      }));
      final r = OpenAiClient.parseResponseBytes(body);
      expect(r.isError, isFalse);
      expect(r.content, '响应的最终文本。');
    });

    test('无有效正文时返回错误而非崩溃', () {
      final body =
          utf8.encode(jsonEncode({'choices': [{'message': {'content': ''}}]}));
      final r = OpenAiClient.parseResponseBytes(body);
      expect(r.isError, isTrue);
      expect(r.content, '');
    });

    test('非 JSON 时返回错误', () {
      final r = OpenAiClient.parseResponseBytes(utf8.encode('not-json'));
      expect(r.isError, isTrue);
    });

    test('空 body 返回错误', () {
      final r = OpenAiClient.parseResponseBytes(const []);
      expect(r.isError, isTrue);
    });
  });
}