/// 证据图谱：用网格时间带 + 卡片聚合表现记录频率、完整度、标签、待补充问题。
///
/// 非惩罚性：空的天显示中性色，不做断签清零，不渲染"连续打卡"焦虑。
library;

import 'package:flutter/material.dart';

import '../../evidence/evidence_service.dart';

class EvidenceGraph extends StatelessWidget {
  const EvidenceGraph({super.key, required this.metrics});

  final GraphMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('证据图谱',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _FreqStrip(recent: metrics.recentFreqByDay),
            const SizedBox(height: 16),
            Row(
              children: [
                _Metric(
                  color: theme.colorScheme.primary,
                  value: '${metrics.totalEntries}',
                  label: '证据总数',
                ),
                const SizedBox(width: 10),
                _Metric(
                  color: const Color(0xFFC98A2D),
                  value: '${metrics.averageCompleteness}%',
                  label: '平均完整度',
                ),
                const SizedBox(width: 10),
                _Metric(
                  color: const Color(0xFF2E6E7E),
                  value: '${metrics.openQuestionCount}',
                  label: '待补充问题',
                ),
              ],
            ),
            if (metrics.tagCounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('主题 / 标签',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.secondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: metrics.tagCounts.entries
                    .map((e) => Chip(
                          label: Text(
                              '#${e.key} ×${e.value}'),
                          labelStyle: theme.textTheme.labelSmall,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            if (metrics.contributionCount > 0) ...[
              const SizedBox(height: 12),
              Text('已捕捉 ${metrics.contributionCount} 次"个人贡献"陈述',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.secondary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 近 14 天记录频率时间带。
class _FreqStrip extends StatelessWidget {
  const _FreqStrip({required this.recent});
  final Map<DateTime, int> recent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = recent.keys.toList()..sort();
    final maxCount = recent.values.fold<int>(0, (m, v) => v > m ? v : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final d in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: _cellColor(theme, recent[d] ?? 0, maxCount),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: (recent[d] ?? 0) > 0
                            ? Text(
                                '${recent[d]}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _cellTextColor(theme, recent[d] ?? 0),
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.day}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('近 14 天记录频率',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.secondary)),
      ],
    );
  }

  Color _cellColor(ThemeData t, int count, int max) {
    if (count == 0) {
      return t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    }
    final ratio = max == 0 ? 0.2 : count / max;
    return t.colorScheme.primary.withValues(alpha: 0.25 + 0.55 * ratio);
  }

  Color _cellTextColor(ThemeData t, int count) =>
      count > 0 ? t.colorScheme.primary : t.colorScheme.onSurface;
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.color, required this.value, required this.label});
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w800)),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}