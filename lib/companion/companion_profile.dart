/// 伙伴成长领域模型：本地晨昏伙伴的持久化资料。
///
/// 成长依据是「已计入的自然日日期集合」而不是单一计数器：
/// - 同一自然日只计入一次（集合天然去重）；
/// - 删除历史 Entry 不回退（集合不因删除而缩小）；
/// - 补写历史日期可计入（往集合加入旧日期）。
/// 日期统一为设备本地日历的 `yyyy-MM-dd` 字符串。
library;

/// 四个固定视觉阶段及其素材路径。
///
/// 首次记录前与第 1–6 天共用 day_01（小芽）素材；7–13 花苞；
/// 14–29 白花；30 天及以上粉花加蜜蜂。第 1 天素材底部藤蔓为有意设计。
enum CompanionStage {
  sprout('小芽', 'assets/companion/day_01.png'),
  bud('花苞', 'assets/companion/day_07.png'),
  bloom('白花', 'assets/companion/day_14.png'),
  fullBloom('粉花', 'assets/companion/day_30.png');

  const CompanionStage(this.label, this.assetPath);

  final String label;
  final String assetPath;
}

/// 成长节点（达到时展示一次阶段提示与节点语录）。
const companionMilestones = [1, 7, 14, 30];

/// 本地日期字符串的规范格式（分组便于解析）。
final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// 名称合法性：1–8 个中文或英文字符。
final _namePattern = RegExp(r'^[\u4e00-\u9fff\u3400-\u4dbfA-Za-z]{1,8}$');

/// 名称是否合法（1–8 个中文或英文字符）。
bool isValidCompanionName(String name) => _namePattern.hasMatch(name);

/// 是否为真实存在的本地日历日期（不仅格式正确，还拒绝 2026-02-30 之类）。
bool _isValidLocalDate(String s) {
  final match = _datePattern.firstMatch(s);
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return false;
  final d = DateTime(year, month, day);
  return d.year == year && d.month == month && d.day == day;
}

/// 伙伴资料：不可变快照，序列化到 `companion_v1`。
///
/// 公共构造只有 [CompanionProfile.sealed]（集合字段全部包装为不可变视图）
/// 与 [CompanionProfile.empty]；不存在可被外部 mutate 的公共构造。
/// 未知字段忽略、缺失字段按默认值兼容；错误容器类型（如本应是列表却存了
/// 字符串）不抛异常，按缺省处理；日期做真实日期校验。
class CompanionProfile {
  const CompanionProfile._({
    this.name,
    this.countedDates = const {},
    this.lastQuoteDate,
    this.quoteRerolls = const {},
    this.milestoneDates = const {},
  });

  /// 空资料：尚未开始成长。
  static const CompanionProfile empty = CompanionProfile._();

  /// 构造对外只读快照：集合字段全部包装为不可变视图。
  ///
  /// [CompanionService] 与 [CompanionProfile.fromJson] 都用本工厂产出，
  /// 避免 `final Set/List/Map` 字段被外部直接 mutate。
  factory CompanionProfile.sealed({
    String? name,
    Set<String> countedDates = const {},
    String? lastQuoteDate,
    Map<String, int> quoteRerolls = const {},
    Map<int, String?> milestoneDates = const {},
  }) {
    return CompanionProfile._(
      name: name,
      countedDates: Set.unmodifiable(countedDates),
      lastQuoteDate: lastQuoteDate,
      quoteRerolls: Map.unmodifiable(quoteRerolls),
      milestoneDates: Map.unmodifiable(milestoneDates),
    );
  }

  /// 伙伴名称（1–8 个中文或英文字符）；未命名时为 null。
  final String? name;

  /// 已计入成长的自然日（本地 `yyyy-MM-dd`）。
  final Set<String> countedDates;

  /// 最近一次产生语录的日期（旧版本兼容字段）。
  ///
  /// 普通语录换句次数按自然日独立记录在 [quoteRerolls]，本字段只用于
  /// 兼容旧版本读取；新版逻辑不依赖它判断换句次数。
  final String? lastQuoteDate;

  /// 每个日期已使用的普通语录换句次数。
  final Map<String, int> quoteRerolls;

  /// 节点 -> 触发日期（本地 `yyyy-MM-dd`）。
  ///
  /// 只有某次保存实际达到节点时才写入触发日期；补写历史日期触发节点时，
  /// 触发日期是补写的那一天。值为 null 表示旧版本数据迁移而来：
  /// 节点已庆祝（不重复提示）但触发日期未知，不构成任何「节点达成日」。
  final Map<int, String?> milestoneDates;

  /// 累计成长自然日。
  int get growthDays => countedDates.length;

  /// 已展示过提示的成长节点（升序）；同一节点只提示一次。
  List<int> get celebratedMilestones =>
      List.unmodifiable(milestoneDates.keys.toList()..sort());

  Map<String, dynamic> toJson() {
    final milestones = milestoneDates.keys.toList()..sort();
    return {
      'name': name,
      'countedDates': (countedDates.toList()..sort()),
      // 双写：新版读 milestoneDates，旧版本降级仍可读 celebratedMilestones，
      // 避免旧版本读取丢失「节点已庆祝」状态。
      'celebratedMilestones': milestones,
      'milestoneDates': {
        for (final m in milestones) '$m': milestoneDates[m],
      },
      'lastQuoteDate': lastQuoteDate,
      'quoteRerolls': quoteRerolls,
    };
  }

  factory CompanionProfile.fromJson(Map<String, dynamic> json) {
    final dates = <String>{};
    final rawDates = json['countedDates'];
    if (rawDates is List) {
      for (final d in rawDates) {
        if (d is String && _isValidLocalDate(d)) dates.add(d);
      }
    }

    final milestoneDates = <int, String?>{};
    final rawMilestones = json['milestoneDates'];
    if (rawMilestones is Map) {
      for (final e in rawMilestones.entries) {
        final key = e.key;
        final value = e.value;
        if (key is String) {
          final m = int.tryParse(key);
          if (m != null &&
              companionMilestones.contains(m) &&
              (value == null || (value is String && _isValidLocalDate(value)))) {
            milestoneDates[m] = value as String?;
          }
        }
      }
    }
    // 兼容旧版本数据：celebratedMilestones 只有节点列表、无触发日期。
    final legacy = json['celebratedMilestones'];
    if (legacy is List) {
      for (final m in legacy) {
        if (m is int && companionMilestones.contains(m)) {
          milestoneDates.putIfAbsent(m, () => null);
        }
      }
    }

    final rerolls = <String, int>{};
    final rawRerolls = json['quoteRerolls'];
    if (rawRerolls is Map) {
      for (final e in rawRerolls.entries) {
        final key = e.key;
        final value = e.value;
        if (key is String &&
            _isValidLocalDate(key) &&
            value is num &&
            value >= 0) {
          rerolls[key] = value.toInt();
        }
      }
    }

    final rawName = json['name'];
    return CompanionProfile.sealed(
      name: rawName is String && isValidCompanionName(rawName)
          ? rawName
          : null,
      countedDates: dates,
      lastQuoteDate:
          json['lastQuoteDate'] is String && _isValidLocalDate(json['lastQuoteDate'] as String)
              ? json['lastQuoteDate'] as String
              : null,
      quoteRerolls: rerolls,
      milestoneDates: milestoneDates,
    );
  }
}
