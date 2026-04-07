import 'package:flutter/material.dart';
import 'history_tile.dart';

class HistoryDrawer extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final ValueChanged<String>? onItemTap;
  final VoidCallback? onClear;
  final void Function(int id)? onSelect;
  final void Function(int id)? onDelete;
  final int? activeSessionId;

  const HistoryDrawer({
    super.key,
    this.history = const [],
    this.onItemTap,
    this.onClear,
    this.onSelect,
    this.onDelete,
    this.activeSessionId,
  });
  @override
  State<HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<HistoryDrawer> {

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Text(
                    'History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: 'Clear all',
                    onPressed: () => widget.onClear?.call(),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.history.isEmpty
                ? const Center(child: Text('history is empty'))
                : SafeArea(
              top: false,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.history.length,
                itemBuilder: (context, index) {
                  final item = widget.history[index];
                  final id = item['Id'] ?? -1;
                  final title = item['Title']?.toString() ?? 'No title';
                  final content = item['Content']?.toString() ?? 'No content';
                  return HistoryTile(
                    id: id,
                    title: title,
                    content: content,
                    isHighlighted: id == widget.activeSessionId,
                    onTap: () => widget.onSelect?.call(id),
                    onDelete: () => widget.onDelete?.call(id),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
