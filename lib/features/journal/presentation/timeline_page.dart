import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/cosmic_scaffold.dart';
import '../application/journal_controller.dart';

class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesState = ref.watch(journalControllerProvider);
    final formatter = DateFormat('MM月dd日 HH:mm');

    return CosmicScaffold(
      child: entriesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('读取记录失败：$error')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('记录池还是空的，先从“今日”存入第一条。'));
          }

          return ListView.separated(
            itemCount: entries.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  '记录池',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                );
              }
              final entry = entries[index - 1];
              return Dismissible(
                key: ValueKey(entry.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => ref.read(journalControllerProvider.notifier).deleteEntry(entry.id),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatter.format(entry.date), style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Text(entry.task, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if (entry.result.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('结果：${entry.result}'),
                      ],
                      if (entry.blocker.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('卡点：${entry.blocker}'),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
