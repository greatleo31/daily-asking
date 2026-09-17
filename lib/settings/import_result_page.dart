import 'package:flutter/material.dart';

import '../core/transfer/data_transfer_service.dart';

class ImportResultPage extends StatelessWidget {
  const ImportResultPage({super.key, required this.result});

  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入结果')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '已导入 ${result.importedCount} 条 · 跳过 ${result.skippedCount} 条 · 失败 ${result.failedCount} 项',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text('其中 ${result.incompleteCount} 条为不完整解析，缺 id / 追问状态等，已用默认值补齐'),
          Text('其中 ${result.legacyCount} 条来自旧格式'),
          const SizedBox(height: 8),
          const Text('失败项包含记录、文件或关联数据问题，不一定等于记录条数。'),
          if (result.storageWarning != null) ...[
            const SizedBox(height: 16),
            Text(
              result.storageWarning!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('查看导入的记录'),
          ),
          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '失败原因（${result.issues.length} 项）',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final issue in result.issues)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(issue.reason),
                subtitle: Text(
                  '${issue.source}${issue.index > 0 ? ' · 第 ${issue.index} 项' : ' · 文件'}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
