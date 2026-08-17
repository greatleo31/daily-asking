/// 产物内容解析：把 AI 输出的 Markdown 字符串解析成结构化视图。
///
/// 设计原则：
/// - 只做稳定、可回退的解析：解析不出结构时页面回退展示原文。
/// - 绝不虚构字段：评级、置信度、证据来源等当前数据中不存在的内容，
///   一律不生成；「待补充 / 偏浅」数量只统计内容里真实出现的标记。
/// - Markdown 只是数据格式，UI 的信息架构由解析结果决定。
library;

/// 一个 `## ` 章节。
class ArtifactSection {
  const ArtifactSection({
    required this.heading,
    required this.lines,
    this.subsections = const [],
  });

  final String heading;
  final List<String> lines;
  final List<ArtifactSubsection> subsections; // `### ` 小节

  bool get hasBody => lines.isNotEmpty || subsections.isNotEmpty;
}

/// 章节内的 `### ` 小节。
class ArtifactSubsection {
  const ArtifactSubsection({required this.title, required this.lines});
  final String title;
  final List<String> lines;
}

/// 通用解析结果。
class ParsedArtifactContent {
  const ParsedArtifactContent({
    this.title,
    this.preamble = const [],
    required this.sections,
  });

  /// `# ` 一级标题。
  final String? title;
  final List<String> preamble;
  final List<ArtifactSection> sections;

  bool get hasStructure => sections.any((s) => s.hasBody);
}

/// 逐条点评中的单个条目（对应证据）。
class InterviewItem {
  const InterviewItem({
    required this.title,
    this.effective,
    this.highlight,
    this.shallow,
    this.expand,
    this.rawLines = const [],
  });

  final String title;

  /// 有效性：这条经历在面试中的价值。
  final String? effective;

  /// 亮点：能体现能力或差异的点。
  final String? highlight;

  /// 偏浅处：哪些层面太浅。
  final String? shallow;

  /// 扩展建议：如何往深挖。
  final String? expand;

  final List<String> rawLines;

  bool get hasAny =>
      effective != null ||
      highlight != null ||
      shallow != null ||
      expand != null ||
      rawLines.isNotEmpty;
}

/// 面试反馈专用视图（只含真实出现的内容）。
class InterviewFeedbackView {
  const InterviewFeedbackView({
    this.overall,
    this.items = const [],
    this.hotspots = const [],
    this.topThree = const [],
    this.pendingCount = 0,
    this.shallowCount = 0,
    this.otherSections = const [],
  });

  /// 一、总体评价。
  final String? overall;

  /// 二、逐条点评。
  final List<InterviewItem> items;

  /// 三、热点与学习方向。
  final List<String> hotspots;

  /// 四、最该优先补强的三件事。
  final List<String> topThree;

  /// 内容中真实出现的「（待补充：……）」占位数量。
  final int pendingCount;

  /// 内容中真实出现的「偏浅处：」标记数量。
  final int shallowCount;

  /// 未能识别的章节（按通用结构兜底展示）。
  final List<ArtifactSection> otherSections;

  bool get isStructured =>
      overall != null || items.isNotEmpty || hotspots.isNotEmpty || topThree.isNotEmpty;
}

/// 把 `cur` 章节收集进 `sections`（若其有正文）。
void _collect(ArtifactSection? cur, List<ArtifactSection> sections) {
  if (cur != null && cur.hasBody) {
    sections.add(cur);
  }
}

/// 按 `# / ## / ###` 标题解析 Markdown 结构。
ParsedArtifactContent parseArtifactContent(String content) {
  final preamble = <String>[];
  final sections = <ArtifactSection>[];
  String? title;
  ArtifactSection? cur;
  ArtifactSubsection? sub;

  for (final raw in content.split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) continue;
    if (line.startsWith('### ')) {
      sub = ArtifactSubsection(
          title: line.substring(4).trim(), lines: <String>[]);
      (cur ??= ArtifactSection(
          heading: '', lines: <String>[], subsections: <ArtifactSubsection>[]))
          .subsections
          .add(sub);
      continue;
    }
    if (line.startsWith('## ')) {
      _collect(cur, sections);
      cur = ArtifactSection(
          heading: line.substring(3).trim(),
          lines: <String>[],
          subsections: <ArtifactSubsection>[]);
      sub = null;
      continue;
    }
    if (line.startsWith('# ')) {
      _collect(cur, sections);
      title = line.substring(2).trim();
      continue;
    }
    // 普通行。
    if (cur == null) {
      preamble.add(line);
    } else if (sub != null) {
      sub.lines.add(line);
      cur.lines.add(line);
    } else {
      cur.lines.add(line);
    }
  }
  _collect(cur, sections);
  return ParsedArtifactContent(
      title: title, preamble: preamble, sections: sections);
}

String _stripBullet(String line) {
  final t = line.trim();
  if (t.isEmpty) return t;
  final m = RegExp(r'^[-*•·]\s+').firstMatch(t);
  if (m != null) return t.substring(m.end);
  final n = RegExp(r'^\d+[\.、\)]\s*').firstMatch(t);
  if (n != null) return t.substring(n.end);
  return t;
}

/// 解析面试反馈（仅当产物类型为面试反馈时使用）。
///
/// 依据提示词固定的四个章节标题做关键字匹配；标题变了就回退到通用结构，
/// 不崩溃、不猜测内容含义。
InterviewFeedbackView buildInterviewFeedbackView(String content) {
  final parsed = parseArtifactContent(content);
  String? overall;
  List<InterviewItem> items = [];
  final hotspots = <String>[];
  final topThree = <String>[];
  final other = <ArtifactSection>[];

  for (final s in parsed.sections) {
    if (s.heading.contains('总体评价')) {
      overall = s.lines.map(_stripBullet).where((l) => l.isNotEmpty).join('\n');
      if (overall.isEmpty) overall = null;
    } else if (s.heading.contains('逐条点评')) {
      items = _parseItems(s);
    } else if (s.heading.contains('热点')) {
      hotspots.addAll(s.lines.map(_stripBullet).where((l) => l.isNotEmpty));
    } else if (s.heading.contains('补强')) {
      topThree.addAll(s.lines.map(_stripBullet).where((l) => l.isNotEmpty));
    } else {
      other.add(s);
    }
  }

  return InterviewFeedbackView(
    overall: overall,
    items: items,
    hotspots: hotspots,
    topThree: topThree,
    pendingCount: RegExp(r'（待补充(?:：|）)').allMatches(content).length,
    shallowCount: '偏浅处：'.allMatches(content).length,
    otherSections: other,
  );
}

/// 从「逐条点评」章节中解析条目（`### ` 小节）。
List<InterviewItem> _parseItems(ArtifactSection section) {
  final result = <InterviewItem>[];
  for (final sub in section.subsections) {
    String? effective;
    String? highlight;
    String? shallow;
    String? expand;
    final raw = <String>[];
    for (final line in sub.lines) {
      final text = _stripBullet(line);
      if (text.isEmpty) continue;
      final idx = text.indexOf('：');
      if (idx > 0) {
        final label = text.substring(0, idx);
        final value = text.substring(idx + 1).trim();
        switch (label) {
          case '有效性':
            effective = value;
            continue;
          case '亮点':
            highlight = value;
            continue;
          case '偏浅处':
            shallow = value;
            continue;
          case '扩展建议':
            expand = value;
            continue;
        }
      }
      raw.add(text);
    }
    result.add(InterviewItem(
      title: sub.title,
      effective: effective,
      highlight: highlight,
      shallow: shallow,
      expand: expand,
      rawLines: raw,
    ));
  }
  return result;
}