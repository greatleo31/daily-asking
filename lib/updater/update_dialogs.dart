/// 更新弹窗（强制 / 非强制）共用实现：启动自动检查与「关于」页手动检查复用同一份。
library;

import 'package:flutter/material.dart';

import 'update_info.dart';

/// 非强制更新：可关闭；点「立即更新」先关闭弹窗，再回调 [onUpdate]。
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  UpdateInfo info, {
  required Future<void> Function() onUpdate,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('发现新版本 ${info.versionName}'),
      content: SingleChildScrollView(
        child: Text(
          info.changelog.isNotEmpty ? info.changelog : '新版本已发布，建议更新。',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('暂不更新'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            onUpdate();
          },
          child: const Text('立即更新'),
        ),
      ],
    ),
  );
}

/// 强制更新：不可关闭（返回键/外部点击均无效），仅「立即更新」。
///
/// 点击后按钮进入「正在下载…」并禁用，避免重复拉起下载；[onUpdate] 结束后若弹窗
/// 仍在（下载失败时不会被关闭），恢复可点状态以便重试。
Future<void> showMandatoryUpdateDialog(
  BuildContext context,
  UpdateInfo info, {
  required Future<void> Function() onUpdate,
}) {
  var downloading = false;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('需要更新到 ${info.versionName}'),
          content: SingleChildScrollView(
            child: Text(
              info.changelog.isNotEmpty ? info.changelog : '当前版本需要更新后才能继续使用。',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: downloading
                  ? null
                  : () async {
                      setDialogState(() => downloading = true);
                      await onUpdate();
                      if (ctx.mounted) {
                        setDialogState(() => downloading = false);
                      }
                    },
              child: Text(downloading ? '正在下载…' : '立即更新'),
            ),
          ],
        ),
      ),
    ),
  );
}
