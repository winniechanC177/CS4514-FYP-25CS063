import 'package:flutter/material.dart';
import '../chatbot/chatbot_suggestions.dart';

enum _BlockMenuAction { delete, sendToChatbot }

abstract class BaseBlock extends StatefulWidget {
  final int blockId;
  final String? text;
  final void Function(int blockId, bool isBusy)? onBusyChanged;
  final VoidCallback? onDelete;
  final void Function(String text, {ChatbotSuggestion? suggestion})? onSendToChatbot;
  final bool autoSubmit;

  const BaseBlock({
    super.key,
    required this.blockId,
    this.text,
    this.onBusyChanged,
    this.onDelete,
    this.onSendToChatbot,
    this.autoSubmit = false,
  });
}

abstract class BaseBlockState<T extends BaseBlock> extends State<T> {
  late TextEditingController textController;
  bool isLoading = false;
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: widget.text ?? '');
    textController.addListener(_onTextChanged);
    onInitExtra();
    if (widget.autoSubmit && (widget.text ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        triggerResponse(textController.text);
      });
    }
  }

  @override
  void dispose() {
    textController.removeListener(_onTextChanged);
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  double dynamicFontSize(String text) {
    final len = text.length;
    if (len < 20) return 28;
    if (len < 40)  return 22;
    if (len < 100) return 18;
    if (len < 200) return 16;
    return 14;
  }

  bool get showTextField => true;

  bool get hasOutputContent => !showTextField;

  bool get hasMenuContent =>
      !showTextField ||
      textController.text.trim().isNotEmpty ||
      hasOutputContent;

  void onInitExtra() {}

  Future<void> fetchResponse(String text);

  String buildSendToChatbotText() => textController.text;

  Widget buildInputHeader();
  Widget buildInputFooter();
  Widget buildOutputContent();

  Widget _buildMenu() {
    final hasDelete = widget.onDelete != null;
    final hasSendToChatbot = widget.onSendToChatbot != null;
    if ((!hasDelete && !hasSendToChatbot) || !hasMenuContent) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_BlockMenuAction>(
      icon: const Icon(Icons.more_vert),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      iconSize: 20,
      splashRadius: 18,
      tooltip: 'Block options',
      onSelected: (action) {
        switch (action) {
          case _BlockMenuAction.delete:
            widget.onDelete?.call();
            break;
          case _BlockMenuAction.sendToChatbot:
            _handleSendToChatbot();
            break;
        }
      },
      itemBuilder: (_) => [
        if (hasDelete)
          const PopupMenuItem<_BlockMenuAction>(
            value: _BlockMenuAction.delete,
            child: Row(
              children: [
                Icon(Icons.delete),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        if (hasSendToChatbot)
          const PopupMenuItem<_BlockMenuAction>(
            value: _BlockMenuAction.sendToChatbot,
            child: Row(
              children: [
                Icon(Icons.auto_awesome),
                SizedBox(width: 8),
                Text('Ask Chatbot'),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleSendToChatbot() async {
    final text = buildSendToChatbotText().trim();
    if (text.isEmpty || !mounted) return;
    final result = await showSendToChatbotPicker(context, text);
    if (result != null && mounted) {
      widget.onSendToChatbot?.call(result.text, suggestion: result.suggestion);
    }
  }

  Future<void> triggerResponse(String text) async {
    if (text.trim().isEmpty) return;
    if (isLoading) return;
    widget.onBusyChanged?.call(widget.blockId, true);
    if (mounted) setState(() => isLoading = true);
    try {
      await fetchResponse(text);
    } finally {
      if (mounted) setState(() => isLoading = false);
      widget.onBusyChanged?.call(widget.blockId, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOutputSection = isLoading || hasOutputContent;

    return Container(
      margin: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: buildInputHeader(),
                      ),
                    ),
                  ),
                  _buildMenu(),
                ],
              ),
              if (showTextField)
                TextField(
                  controller: textController,
                  focusNode: focusNode,
                  onTapOutside: (e) {
                    focusNode.unfocus();
                    triggerResponse(textController.text);
                    FocusScope.of(context).unfocus();
                  },
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  style: TextStyle(fontSize: dynamicFontSize(textController.text)),
                  decoration: const InputDecoration.collapsed(hintText: 'Please enter text'),
                ),
              buildInputFooter(),
              if (showOutputSection) ...[
                const Divider(),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        height: 96,
                        width: 96,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                if (!isLoading) buildOutputContent(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
