/// 伙伴成长纯领域服务。
///
/// 规则全部本地、固定、可复现：不依赖 Flutter / Provider / SharedPreferences /
/// 网络，直接用 Dart 测试。语录为静态文案池，按日期与换句次数确定性选择，
/// 不读取、不复述记录正文，满足敏感内容隔离。
library;

import 'companion_profile.dart';

/// 一次「记录成长」的纯函数结果：新资料 + 本次事件信息。
class CompanionGrowthResult {
  const CompanionGrowthResult({
    required this.profile,
    required this.counted,
    required this.growthBefore,
    required this.growthAfter,
    required this.milestone,
    required this.quote,
    required this.quoteIsNode,
  });

  /// 需要持久化的新资料（未计入时与输入相同）。
  final CompanionProfile profile;

  /// 本次是否新增了一个自然日（同一天重复保存为 false）。
  final bool counted;

  final int growthBefore;
  final int growthAfter;

  /// 本次保存首次达到的节点（1/7/14/30）；非节点日为 null。
  final int? milestone;

  /// 本次需要展示的语录：节点语录或普通日首条语录；同日重复为 null。
  final String? quote;

  final bool quoteIsNode;
}

/// 一次「换句」的纯函数结果。
class CompanionRerollResult {
  const CompanionRerollResult({
    required this.profile,
    required this.quote,
    required this.changed,
    required this.canReroll,
    required this.isNodeQuote,
  });

  final CompanionProfile profile;
  final String quote;
  final bool changed;

  /// 是否还能继续换句（普通日每自然日有限次数，节点日不可换句）。
  final bool canReroll;

  /// 当前语录是否为节点语录（节点语录不提供替换操作）。
  final bool isNodeQuote;
}

/// 伙伴成长规则服务。
class CompanionService {
  const CompanionService();

  /// 首次记录前的引导文案（已人工确认）。
  static const preRecordCopy = '还没留下第一个晨昏，先记下一件真实小事吧';

  /// 每个自然日允许的普通语录换句次数上限。
  static const maxRerollsPerDay = 2;

  /// 普通日语录池（静态、诗性、克制，不包含任何记录内容）。
  static const _normalQuotes = [
    '把今天的一件小事安放进夜色，它会自己发芽。',
    '没有白走的路，只有还没被记下的脚步。',
    '晨昏交替之处，恰好是证据生长的地方。',
    '今天留下的句子，是明天看得见的根。',
    '认真记下的一天，不会在时间里走丢。',
    '一点真实，胜过许多设想。',
    '把模糊的担忧写成具体的小事，天就亮了一些。',
    '每一次落笔，都是给未来的自己留一盏灯。',
  ];

  /// 节点语录：首次达到 1 / 7 / 14 / 30 天时各展示一次。
  static const _nodeQuotes = {
    1: '第一粒种子落下了。从今天起，你的每一天都有迹可循。',
    7: '第七天，芽尖探出土壤。坚持不是一次用力，是每天一点点。',
    14: '第十四天，花苞合拢着等待。积累到一定程度，答案自己会开。',
    30: '第三十天，花开见蜂。你已为自己攒下一整个月的证据。',
  };

  /// 本地日期规范化为 `yyyy-MM-dd`（设备本地日历，补零）。
  String normalizeDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 由累计成长日计算阶段：0–6 小芽，7–13 花苞，14–29 白花，30+ 粉花。
  CompanionStage stageFor(int growthDays) {
    if (growthDays >= 30) return CompanionStage.fullBloom;
    if (growthDays >= 14) return CompanionStage.bloom;
    if (growthDays >= 7) return CompanionStage.bud;
    return CompanionStage.sprout;
  }


  /// 最小派生月度章节编号：第 1–30 天为第 1 章，31–60 天为第 2 章，
  /// 依此类推；尚未记录（0 天）为 0。仅派生标识，不产生章节状态字段。
  int chapterFor(int growthDays) =>
      growthDays <= 0 ? 0 : ((growthDays - 1) ~/ 30) + 1;

  /// 下一个成长节点；已达 30 天后为 null。
  int? nextMilestone(int growthDays) {
    for (final m in companionMilestones) {
      if (growthDays < m) return m;
    }
    return null;
  }

  bool isMilestone(int growthDays) => companionMilestones.contains(growthDays);

  /// date 是否命中任一节点的触发日期（节点达成日）。
  ///
  /// 达到更高节点后，之前节点（如第 7 天）的触发日仍是节点日，会展示
  /// 对应节点语录；非触发日期（如第 8 天）不误判为节点日。
  bool isCelebrationDay(CompanionProfile p, String date) =>
      milestoneForDate(p, date) != null;

  /// 返回 date 作为触发日期对应的节点（1/7/14/30）；非节点日返回 null。
  int? milestoneForDate(CompanionProfile p, String date) {
    for (final e in p.milestoneDates.entries) {
      if (e.value == date) return e.key;
    }
    return null;
  }

  /// 今日卡片语录：尚未记录返回引导文案；节点日返回节点语录；
  /// 其余按「日期 + 已用换句次数」确定性选择普通语录。换句次数按自然日
  /// 独立记录在 [CompanionProfile.quoteRerolls]，跨日期补写不影响。
  String quoteForDay(CompanionProfile p, String date) {
    if (p.growthDays == 0) return preRecordCopy;
    final milestone = milestoneForDate(p, date);
    if (milestone != null) return _nodeQuotes[milestone]!;
    final rerolls = p.quoteRerolls[date] ?? 0;
    return _normalQuote(date, rerolls);
  }

  /// 今日是否仍可换句：该日期已计入（先记录后换句）、普通日且未用尽次数；
  /// 未记录或节点日不可换句。次数按自然日独立计算。
  bool canRerollToday(CompanionProfile p, String date) {
    if (p.growthDays == 0 || !p.countedDates.contains(date)) return false;
    if (isCelebrationDay(p, date)) return false;
    final rerolls = p.quoteRerolls[date] ?? 0;
    return rerolls < maxRerollsPerDay;
  }

  /// 把一次有效记录的日期幂等计入伙伴成长（纯函数，不落盘）。
  ///
  /// 同一天重复保存不计入、不产生新语录；补写历史日期按普通成长日计入；
  /// 首次达到节点时记录节点语录并标记已庆祝。
  CompanionGrowthResult record(CompanionProfile p, DateTime entryDate) {
    final date = normalizeDate(entryDate);
    if (p.countedDates.contains(date)) {
      return CompanionGrowthResult(
        profile: p,
        counted: false,
        growthBefore: p.growthDays,
        growthAfter: p.growthDays,
        milestone: null,
        quote: null,
        quoteIsNode: false,
      );
    }
    final newDates = {...p.countedDates, date};
    final growthAfter = newDates.length;
    final milestone =
        isMilestone(growthAfter) && !p.milestoneDates.containsKey(growthAfter)
            ? growthAfter
            : null;
    String? quote;
    var lastQuoteDate = p.lastQuoteDate;
    var quoteRerolls = p.quoteRerolls;
    var quoteIsNode = false;
    if (milestone != null) {
      quote = _nodeQuotes[milestone];
      quoteIsNode = true;
      lastQuoteDate = date;
      quoteRerolls = {...p.quoteRerolls}..remove(date);
    } else {
      // 新计入的日期此前必然未换句（换句要求日期已计入），普通语录从 0 次起。
      quote = _normalQuote(date, 0);
      lastQuoteDate = date;
      quoteRerolls = {...p.quoteRerolls, date: 0};
    }
    final updated = CompanionProfile.sealed(
      name: p.name,
      countedDates: newDates,
      lastQuoteDate: lastQuoteDate,
      quoteRerolls: quoteRerolls,
      milestoneDates: milestone == null
          ? p.milestoneDates
          : {...p.milestoneDates, milestone: date},
    );
    return CompanionGrowthResult(
      profile: updated,
      counted: true,
      growthBefore: p.growthDays,
      growthAfter: growthAfter,
      milestone: milestone,
      quote: quote,
      quoteIsNode: quoteIsNode,
    );
  }

  /// 普通日语录换句（每自然日有限次数）；未记录日 / 节点日拒绝。
  CompanionRerollResult reroll(CompanionProfile p, String date) {
    if (p.growthDays == 0 ||
        !p.countedDates.contains(date) ||
        isCelebrationDay(p, date)) {
      return CompanionRerollResult(
        profile: p,
        quote: quoteForDay(p, date),
        changed: false,
        canReroll: false,
        isNodeQuote: isCelebrationDay(p, date),
      );
    }
    final rerolls = p.quoteRerolls[date] ?? 0;
    if (rerolls >= maxRerollsPerDay) {
      return CompanionRerollResult(
        profile: p,
        quote: _normalQuote(date, rerolls),
        changed: false,
        canReroll: false,
        isNodeQuote: false,
      );
    }
    final next = rerolls + 1;
    final updated = CompanionProfile.sealed(
      name: p.name,
      countedDates: p.countedDates,
      lastQuoteDate: date,
      quoteRerolls: {...p.quoteRerolls, date: next},
      milestoneDates: p.milestoneDates,
    );
    return CompanionRerollResult(
      profile: updated,
      quote: _normalQuote(date, next),
      changed: true,
      canReroll: next < maxRerollsPerDay,
      isNodeQuote: false,
    );
  }

  /// 校验伙伴名称：1–8 个中文或英文字符；返回错误文案，合法返回 null。
  String? validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '名称不能为空';
    if (!isValidCompanionName(trimmed)) return '名称需为 1–8 个中文或英文字符';
    return null;
  }

  /// 与运行平台无关的稳定字符串哈希（避免 String.hashCode 跨运行不稳定）。
  static int _stableHash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  String _normalQuote(String date, int rerolls) {
    final base = _stableHash(date) % _normalQuotes.length;
    return _normalQuotes[(base + rerolls) % _normalQuotes.length];
  }
}
