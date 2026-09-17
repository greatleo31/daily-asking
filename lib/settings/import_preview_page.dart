import 'package:flutter/material.dart';

import '../core/transfer/import_plan.dart';

class ImportPreviewPage extends StatelessWidget {
  const ImportPreviewPage({super.key, required this.plan});

  final ImportPlan plan;

  static const markdownWarning = 'Markdown 是给人读的格式，导入会有信息损失；要完整迁移请用本机的「导出数据」。';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入预览')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(markdownWarning),
          const SizedBox(height: 20),
          Text(
            '将新增 ${plan.addedCount} 条 · 已存在跳过 ${plan.skippedCount} 条 · 无法导入 ${plan.invalidCount} 项',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('无法导入的项包含记录、文件或关联数据问题，不一定等于记录条数。'),
          const SizedBox(height: 16),
          ExpansionTile(
            title: Text('查看明细（共 ${plan.details.length} 项）'),
            children: [
              if (plan.details.length > 50)
                Text('仅显示前 50 项，共 ${plan.details.length} 项'),
              for (final detail in plan.details.take(50))
                ListTile(
                  title: Text(
                    '${_label(detail.disposition)} · ${detail.label}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${detail.source}${detail.index > 0 ? ' · 第 ${detail.index} 项' : ' · 文件'}'
                    '${detail.reason.isEmpty ? '' : '\n${detail.reason}'}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认导入'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  String _label(ImportDisposition disposition) => switch (disposition) {
    ImportDisposition.added => '新增',
    ImportDisposition.skipped => '跳过',
    ImportDisposition.invalid => '无法导入',
  };
}
