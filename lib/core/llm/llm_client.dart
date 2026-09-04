/// core/llm：可选 AI 客户端（OpenAI 兼容）。
///
/// 隐私与安全约束：
/// - 只发送当前用户选中的最小字段（见 [OutboundPayload]）。
/// - 每次真实调用前，调用方必须先用 [OutboundPayload.toDisclosure] 给用户确认。
/// - 日志不记录 API Key、记录正文、提示词全文。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../../settings/settings_repository.dart';
import 'prompts.dart';

/// 一次出站调用的最小载荷：只包含选中的记录字段，用于披露与发送。
class OutboundPayload {
  OutboundPayload({required this.entries, required this.artifactType});

  final List<Entry> entries;
  final ArtifactType artifactType;

  /// 出站确认只说明即将访问已配置的 AI 服务，不泄露实现细节。
  String toDisclosure() => '将访问已配置的 AI 服务生成内容，是否确认？';

  /// 组装发送给模型的 Markdown-first 系统提示词。
  String buildSystemPrompt(ArtifactType type) => systemPromptFor(type);

  /// 组装发送给模型的用户消息（带稳定记录 id，便于结果回溯）。
  String buildUserMessage({DateTime? referenceDate}) {
    final date = referenceDate ?? DateTime.now();
    final b = StringBuffer(
      '请基于以下记录生成产物。当前参考日期：${date.toIso8601String().substring(0, 10)}。\n',
    );
    b.writeln('每条输出 item 的 evidenceRefs 必须使用下面的真实记录 id；不得使用序号。');
    for (final e in entries) {
      b.writeln('记录 id=${e.id}:');
      b.writeln('  日期: ${e.date.toIso8601String().substring(0, 10)}');
      b.writeln('  任务: ${e.task.trim()}');
      b.writeln('  背景: ${e.context.trim()}');
      b.writeln('  行动: ${e.action.trim()}');
      b.writeln('  结果: ${e.result.trim()}');
      b.writeln('  难点: ${e.blocker.trim()}');
    }
    return b.toString();
  }
}

/// 真实 AI 调用结果。
class LlmResult {
  LlmResult({required this.content, this.error});
  final String content;
  final String? error;
  bool get isError => error != null;
}

/// DNS 预检结果。
class DnsLookupResult {
  const DnsLookupResult({required this.resolved, this.host});
  final bool resolved;
  final String? host;
}

/// OpenAI 兼容客户端。零日志策略：不打印 Key / 正文 / 提示词。
class OpenAiClient {
  OpenAiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 解析失败时对同一请求的有限重试次数（仅针对网络/DNS 瞬时故障，不针对业务结果）。
  static const int _maxNetworkRetries = 1;

  /// 完整请求超时：覆盖整个 body 读取。
  static const Duration _requestTimeout = Duration(seconds: 60);

  Future<LlmResult> complete({
    required LlmSettings settings,
    required String apiKey,
    required String system,
    required String user,
  }) async {
    final endpoint = _chatEndpoint(settings.baseUrl);
    final uri = Uri.parse(endpoint);

    // 发送前 DNS 预检：提前暴露解析失败，给出可操作提示，而非裸抛 Failed host lookup。
    final dns = await _tryDnsLookup(uri);
    if (!dns.resolved) {
      if (dns.host == null || dns.host!.trim().isEmpty) {
        return LlmResult(content: '', error: '模型地址无效，请检查 Base URL。');
      }
      return LlmResult(
        content: '',
        error: '无法解析模型服务商地址（${dns.host}），请检查网络或服务商域名。',
      );
    }

    final body = jsonEncode({
      'model': settings.model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': 0.4,
    });

    for (var attempt = 0; attempt <= _maxNetworkRetries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_retryDelay(attempt));
      }
      try {
        final resp = await _client
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: body,
            )
            .timeout(_requestTimeout);
        if (resp.statusCode != 200) {
          return LlmResult(
            content: '',
            error: '请求失败（HTTP ${resp.statusCode}），请检查 Base URL / Key / 模型。',
          );
        }
        return parseResponseBytes(resp.bodyBytes);
      } on TimeoutException {
        // 只有网络层超时属于可重试的瞬时故障。
        if (attempt < _maxNetworkRetries) continue;
        return LlmResult(content: '', error: '模型服务响应超时，请稍后重试。');
      } on SocketException {
        if (attempt < _maxNetworkRetries) continue;
        return LlmResult(content: '', error: '无法连接模型服务商，请检查网络。');
      } on http.ClientException {
        if (attempt < _maxNetworkRetries) continue;
        return LlmResult(content: '', error: '无法连接模型服务商，请检查网络。');
      } on FormatException {
        return LlmResult(content: '', error: '模型返回内容无法解析，请重试。');
      } catch (_) {
        return LlmResult(content: '', error: 'AI 调用出错，请稍后重试。');
      }
    }
    // 防御：理论上不可达。
    return LlmResult(content: '', error: 'AI 调用出错，请稍后重试。');
  }

  /// 网络失败重试的退避间隔（秒）。
  Duration _retryDelay(int attempt) => Duration(milliseconds: 500 * attempt);

  /// 尝试解析主机名。resolved=false 时可携带 host 用于提示。
  Future<DnsLookupResult> _tryDnsLookup(Uri uri) async {
    final host = uri.host.trim();
    if (host.isEmpty) {
      return const DnsLookupResult(resolved: false);
    }
    try {
      await InternetAddress.lookup(host).timeout(const Duration(seconds: 8));
      return const DnsLookupResult(resolved: true);
    } catch (_) {
      return DnsLookupResult(resolved: false, host: host);
    }
  }

  /// 健壮解析：兼容 content 为 String、多模态 content 数组、thinking 内容等形态。
  @visibleForTesting
  static LlmResult parseResponseBytes(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) {
      return LlmResult(content: '', error: '模型返回内容为空，请重试。');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bodyBytes));
    } on FormatException {
      return LlmResult(content: '', error: '响应格式异常：不是合法 JSON。');
    }
    if (decoded is! Map<String, dynamic>) {
      return LlmResult(content: '', error: '响应格式异常：不是 JSON 对象。');
    }
    // OpenAI 兼容标准路径。
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = extractText(message['content']);
          if (content != null && content.trim().isNotEmpty) {
            return LlmResult(content: content.trim());
          }
        }
      }
    }
    // 部分网关 / responses 风格：从 message 平铺字段兜底。
    var fallback = extractText(decoded['message']);
    if (fallback == null && decoded['message'] is Map<String, dynamic>) {
      fallback = extractText(
        (decoded['message'] as Map<String, dynamic>)['content'],
      );
    }
    if (fallback != null && fallback.trim().isNotEmpty) {
      return LlmResult(content: fallback.trim());
    }
    return LlmResult(content: '', error: '模型返回内容无有效正文，请重试。');
  }

  /// 从 content 字段提取纯文本：兼容 String 与多模态 content 块列表。
  @visibleForTesting
  static String? extractText(Object? content) {
    if (content == null) return null;
    if (content is String) {
      if (content.trim().isEmpty) return null;
      return content;
    }
    if (content is List) {
      final parts = <String>[];
      for (final item in content) {
        if (item is String) {
          parts.add(item);
        } else if (item is Map<String, dynamic>) {
          final type = item['type'];
          if (type == 'text') {
            final t = item['text'];
            if (t is String) parts.add(t);
          } else if (type == 'output_text' || type == 'output') {
            final t = item['text'];
            if (t is String) parts.add(t);
          }
        }
      }
      final joined = parts.join('\n');
      return joined.trim().isEmpty ? null : joined;
    }
    return null;
  }

  String _chatEndpoint(String baseUrl) {
    final b = baseUrl.trim();
    if (b.endsWith('/chat/completions')) return b;
    final s = b.endsWith('/') ? b.substring(0, b.length - 1) : b;
    return '$s/chat/completions';
  }
}
