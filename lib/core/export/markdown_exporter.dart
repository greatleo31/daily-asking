/// Markdown 导出：把证据（单条 / 全部）组装为规范 Markdown，
/// 并通过原生 MethodChannel 唤起 Android 系统分享（也可保存到本机）。
///
/// 导出位置说明（Android 上"导入到哪里"取决于用户选择的分享目标）：
/// - 默认写入应用外部目录 `Android/data/<pkg>/files/Download/`（无需存储权限），
/// - 然后唤起系统分享面板，用户可选择发送到 微信 / QQ / 邮件 / 笔记 App /
///   网盘 / 文件管理器（复制到 Download 后任意 MD 阅读器可打开）。
library;

import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../models.dart';

/// 导出文件名时间戳：`20260814-2140`。
String _stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}';
}

/// 单条导出文件名。
String singleFileName(DateTime now) => 'daily-asking-${_stamp(now)}.md';

/// 全部导出文件名。
String allFileName(DateTime now) => 'daily-asking-all-${_stamp(now)}.md';

String _dateLabel(DateTime d) =>
    '${d.year}年${d.month}月${d.day}日';

String _statusLabel(QuestionStatus s) => switch (s) {
      QuestionStatus.pending => '待补充',
      QuestionStatus.answered => '已答',
      QuestionStatus.later => '稍后',
      QuestionStatus.skip => '已跳过',
    };

/// 单条证据 → Markdown（纯函数，可测试）。
String entryToMarkdown(
  Entry e,
  List<EvidenceQuestion> questions,
  Map<String, List<EvidenceAnswer>> answers,
) {
  final buf = StringBuffer();
  buf.writeln('## ${_dateLabel(e.date)}');
  buf.writeln();
  buf.writeln('**任务**：${e.task.trim()}');
  buf.writeln();
  buf.writeln('**完整度**：${e.completenessPercent()}%');
  buf.writeln();
  void field(String label, String v) {
    final t = v.trim();
    if (t.isNotEmpty) {
      buf.writeln('- **$label**：$t');
    }
  }

  field('背景', e.context);
  field('具体行动', e.action);
  field('结果 / 验证', e.result);
  field('难点 / 取舍', e.blocker);
  if (e.tags.isNotEmpty) {
    buf.writeln('- **标签**：${e.tags.map((t) => '#$t').join(' ')}');
  }
  if (questions.isNotEmpty) {
    buf.writeln();
    buf.writeln('### 追问与回答');
    for (final q in questions) {
      final as = answers[q.id] ?? const <EvidenceAnswer>[];
      final answerText = as.map((a) => a.content.trim()).where((s) => s.isNotEmpty).join('；');
      if (answerText.isNotEmpty) {
        buf.writeln('- 【${q.kind.label}】${q.prompt.trim()} → **已答**：$answerText');
      } else {
        buf.writeln('- 【${q.kind.label}】${q.prompt.trim()}（${_statusLabel(q.status)}）');
      }
    }
  }
  return buf.toString();
}

/// 全部证据 → Markdown（纯函数，可测试）。
String allEntriesToMarkdown(
  List<Entry> entries,
  Map<String, List<EvidenceQuestion>> questionsByEntry,
  Map<String, Map<String, List<EvidenceAnswer>>> answersByQuestion,
) {
  final buf = StringBuffer();
  buf.writeln('# 晨昏证据图谱 · 全部证据导出');
  buf.writeln();
  buf.writeln('> 导出时间：${_dateLabel(DateTime.now())}（${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}）');
  buf.writeln('> 共 ${entries.length} 条证据');
  buf.writeln();
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    buf.writeln('## 证据 ${i + 1} · ${_dateLabel(e.date)}');
    buf.writeln();
    final qs = questionsByEntry[e.id] ?? const <EvidenceQuestion>[];
    buf.write(entryToMarkdown(e, qs, answersByQuestion[e.id] ?? const {}));
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
  }
  return buf.toString();
}

/// 供页面直接调用：读取全部证据与追问/回答后组装 Markdown。
Future<String> buildAllMarkdown(AppState state) async {
  final entries = state.allEntries;
  final qsByEntry = <String, List<EvidenceQuestion>>{};
  final answersByQ = <String, Map<String, List<EvidenceAnswer>>>{};
  for (final e in entries) {
    final qs = await state.questionsFor(e.id);
    qsByEntry[e.id] = qs;
    final amap = <String, List<EvidenceAnswer>>{};
    for (final q in qs) {
      amap[q.id] = await state.answersFor(q.id);
    }
    answersByQ[e.id] = amap;
  }
  return allEntriesToMarkdown(entries, qsByEntry, answersByQ);
}

/// 原生分享通道：写文件 + 唤起系统分享面板。
class MarkdownShare {
  static const MethodChannel _channel =
      MethodChannel('com.dailyasking.daily_asking/export');

  /// 返回 true 表示已成功写文件并唤起分享；false 表示失败。
  static Future<bool> share({
    required String fileName,
    required String content,
  }) async {
    try {
      await _channel.invokeMethod<void>('shareMarkdown', <String, Object?>{
        'fileName': fileName,
        'content': content,
      });
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}