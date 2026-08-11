/// 通用工具：ID 生成与日期工具。
library;

import 'dart:math';

final _random = Random.secure();
const _chars =
    'abcdefghijklmnopqrstuvwxyz0123456789';

/// 生成一个局部唯一 ID（本应用无后端，无需全局唯一）。
String genId({String prefix = ''}) {
  final buf = StringBuffer(prefix);
  while (buf.length < (prefix.isEmpty ? 16 : 20)) {
    buf.write(_chars[_random.nextInt(_chars.length)]);
  }
  return buf.toString();
}

/// 把 DateTime 规整为"当天"（本地时区零点），用于按天聚类。
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// 判断两个日期是否同一天。
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 最近 N 天的日期列表（含今天），从旧到新。
List<DateTime> lastNDays(int n) {
  final today = dayOf(DateTime.now());
  return List.generate(n, (i) => today.subtract(Duration(days: n - 1 - i)));
}

extension DateLabel on DateTime {
  /// 中文日期标签，如「8月11日 · 周二」。
  String get cnLabel {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '$month月$day日 · ${weekdays[weekday - 1]}';
  }
}