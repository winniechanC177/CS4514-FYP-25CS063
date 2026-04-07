import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class HistoryTile extends StatelessWidget {
  final int id;
  final String title;
  final String content;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const HistoryTile({
    super.key,
    required this.id,
    required this.title,
    required this.content,
    this.isHighlighted = false,
    this.onTap,
    this.onDelete,
  });

  Future<void> _popThenRun(BuildContext context, VoidCallback? fn) async {
    await Navigator.of(context).maybePop();
    await Future<void>.delayed(Duration.zero);
    while (SchedulerBinding.instance.transientCallbackCount > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    fn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final parts = content.split('·').map((s) => s.trim()).toList();
    final line1 = parts.isNotEmpty ? parts[0] : '';
    final line2 = parts.length > 1 ? parts.sublist(1).join(' · ') : '';

    return ListTile(
      tileColor: isHighlighted
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      onTap: () => _popThenRun(context, onTap),
      title: Text(
        title,
        style: isHighlighted
            ? TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              )
            : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line1.isNotEmpty)
            Text(
              line1,
              style: const TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          if (line2.isNotEmpty)
            Text(
              line2,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
        ],
      ),
      trailing: ElevatedButton(
        onPressed: onDelete,
        child: const Icon(Icons.delete),
      ),
    );
  }
}
