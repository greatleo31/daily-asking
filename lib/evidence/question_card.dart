/// 追问卡片：针对一条本地追问，提供"回答 / 稍后 / 跳过"。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/models.dart';

class QuestionCard extends StatefulWidget {
  const QuestionCard({super.key, required this.question});

  final EvidenceQuestion question;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _act(
      BuildContext context, Future<void> Function(AppState) op,
      {bool close = true}) async {
    final state = context.read<AppState>();
    setState(() => _busy = true);
    await op(state);
    if (mounted && close) Navigator.of(this.context).pop();
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.question;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('本地追问 · ${q.kind.label}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.tertiary)),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(q.prompt,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('为什么问：${q.reason}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.secondary)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '补充你的回答…'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _act(context,
                        (s) => s.setQuestionStatus(q.id, QuestionStatus.skip)),
                child: const Text('跳过'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _act(context,
                        (s) => s.setQuestionStatus(q.id, QuestionStatus.later)),
                child: const Text('稍后'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : _controller.text.trim().isEmpty
                        ? null
                        : () => _act(
                            context,
                            (s) => s.answerQuestion(
                                q.id, _controller.text),
                            close: true,
                          ),
                icon: const Icon(Icons.check),
                label: const Text('回答'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}