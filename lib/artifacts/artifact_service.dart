/// 产物生成服务：基于选中的证据，用本地模板生成三种产物。
///
/// 职责：
/// - 只使用已有事实，绝不编造。
/// - 标注缺失证据（gaps）与风险提示（risks）。
/// - 无 AI 时也能生成可编辑的本地模板产物。
library;

import '../core/models.dart';
import '../core/utils.dart';

class ArtifactService {
  /// 用本地模板生成一份产物。sourceEntries 为选中的证据。
  Artifact generateLocal({
    required ArtifactType type,
    required List<Entry> sourceEntries,
  }) {
    final now = DateTime.now();
    final gaps = _collectGaps(sourceEntries);
    final risks = _collectRisks(sourceEntries, type);

    final content = switch (type) {
      ArtifactType.resume => _resumeTemplate(sourceEntries, risks, gaps),
      ArtifactType.weekly => _weeklyTemplate(sourceEntries, risks, gaps),
      ArtifactType.interview => _interviewTemplate(sourceEntries, risks, gaps),
    };

    return Artifact(
      id: genId(),
      type: type,
      content: content,
      sourceEntryIds: sourceEntries.map((e) => e.id).toList(),
      risks: risks,
      gaps: gaps,
      createdAt: now,
      updatedAt: now,
    );
  }

  String _resumeTemplate(List<Entry> es, List<String> risks, List<String> gaps) {
    final b = StringBuffer('【简历要点 · 草稿】\n\n');
    for (var i = 0; i < es.length; i++) {
      final e = es[i];
      b.write('${i + 1}. ${e.action.trim().isEmpty ? e.task.trim() : e.action.trim()}');
      if (e.context.trim().isNotEmpty) {
        b.write('（背景：${e.context.trim()}）');
      }
      if (e.result.trim().isNotEmpty) {
        b.write('，实现${e.result.trim()}');
      }
      b.write('\n');
    }
    b.write('\n说明：以上仅整合你已记录的事实，未做任何夸大或补全。');
    return b.toString();
  }

  String _weeklyTemplate(List<Entry> es, List<String> risks, List<String> gaps) {
    final b = StringBuffer('【周报要点 · 草稿】\n\n');
    for (var i = 0; i < es.length; i++) {
      final e = es[i];
      b.write('${i + 1}. 事项：${e.task.trim()}\n');
      if (e.action.trim().isNotEmpty) {
        b.write('   做了什么：${e.action.trim()}\n');
      }
      if (e.result.trim().isNotEmpty) {
        b.write('   结果：${e.result.trim()}\n');
      }
      if (e.blocker.trim().isNotEmpty) {
        b.write('   难点/待跟进：${e.blocker.trim()}\n');
      }
      b.write('\n');
    }
    b.write('说明：仅据已有记录整理，缺失项请核对后补充。');
    return b.toString();
  }

  String _interviewTemplate(List<Entry> es, List<String> risks, List<String> gaps) {
    final b = StringBuffer('【面试追问卡 · 草稿】\n\n');
    for (var i = 0; i < es.length; i++) {
      final e = es[i];
      b.write('${i + 1}. 事件：${e.task.trim()}\n');
      b.write('   - 背景：${e.context.trim().isEmpty ? "（未记录）" : e.context.trim()}\n');
      b.write('   - 我的动作：${e.action.trim().isEmpty ? "（未记录）" : e.action.trim()}\n');
      b.write('   - 结果：${e.result.trim().isEmpty ? "（未记录）" : e.result.trim()}\n');
      b.write('   - 难点：${e.blocker.trim().isEmpty ? "（未记录）" : e.blocker.trim()}\n');
      b.write('\n');
    }
    b.write('可追问：对每个事件追问"你个人负责的部分"与"量化指标"。\n');
    return b.toString();
  }

  List<String> _collectGaps(List<Entry> es) {
    final gaps = <String>[];
    for (var i = 0; i < es.length; i++) {
      final e = es[i];
      final missing = <String>[
        if (e.context.trim().isEmpty) '背景',
        if (e.action.trim().isEmpty) '具体行动',
        if (e.result.trim().isEmpty) '结果/验证',
        if (e.blocker.trim().isEmpty) '难点/取舍',
      ];
      if (missing.isNotEmpty) {
        gaps.add('证据 #${i + 1}「${e.task.trim()}」缺失：${missing.join('、')}');
      }
    }
    return gaps;
  }

  List<String> _collectRisks(List<Entry> es, ArtifactType type) {
    final risks = <String>[];
    var quantified = 0;
    for (final e in es) {
      final text =
          '${e.task} ${e.context} ${e.action} ${e.result} ${e.blocker}';
      if (RegExp(r'\d+|\d+\.\d+%').hasMatch(text)) quantified++;
    }
    if (quantified == 0) {
      risks.add('缺少数字/量化指标，成果可能显得空泛。');
    }
    if (es.isNotEmpty &&
        es.every((e) => e.result.trim().isEmpty)) {
      risks.add('未记录任何可验证结果，请勿对外宣称"完成/达成"。');
    }
    if (type == ArtifactType.resume) {
      risks.add('草稿未包含公司名、项目名与具体规模，投递前请自行核对。');
    }
    return risks;
  }
}