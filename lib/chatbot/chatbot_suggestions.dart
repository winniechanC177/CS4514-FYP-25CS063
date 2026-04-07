import 'package:flutter/material.dart';
import '../base/app_bottom_sheet.dart';
import '../types/chatbot_suggestion.dart';
export '../types/chatbot_suggestion.dart';


ChatbotSuggestion? detectSuggestion(String text) {
  final normalized = text.trim().toLowerCase();
  for (final suggestion in ChatbotSuggestion.values) {
    if (normalized.startsWith(suggestion.prompt.toLowerCase())) {
      return suggestion;
    }
  }
  return null;
}

class ChatbotSuggestionsBar extends StatelessWidget {
  final ChatbotSuggestion? selected;
  final void Function(ChatbotSuggestion? suggestion) onChanged;

  const ChatbotSuggestionsBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: ChatbotSuggestion.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final s = ChatbotSuggestion.values[i];
          final isSelected = selected == s;

          final buttonStyle = (isSelected
                  ? FilledButton.styleFrom()
                  : OutlinedButton.styleFrom())
              .copyWith(
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10)),
            minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle:
                const WidgetStatePropertyAll(TextStyle(fontSize: 12)),
          );

          final label = Text(s.label);
          void onPress() => onChanged(isSelected ? null : s);

          return isSelected
              ? FilledButton(
                  style: buttonStyle, onPressed: onPress, child: label)
              : OutlinedButton(
                  style: buttonStyle, onPressed: onPress, child: label);
        },
      ),
    );
  }
}

typedef ChatbotPickerResult = ({String text, ChatbotSuggestion? suggestion});

Future<ChatbotPickerResult?> showSendToChatbotPicker(
    BuildContext context, String text) {
  return showStyledBottomSheet<ChatbotPickerResult>(
    context: context,
    builder: (_) => _SendToChatbotSheet(text: text),
  );
}

class _SendToChatbotSheet extends StatefulWidget {
  final String text;
  const _SendToChatbotSheet({required this.text});

  @override
  State<_SendToChatbotSheet> createState() => _SendToChatbotSheetState();
}

class _SendToChatbotSheetState extends State<_SendToChatbotSheet> {
  ChatbotSuggestion? _selected;

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Ask Chatbot',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Text(
                '"${widget.text}"',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Add a suggestion (optional):'),
          const SizedBox(height: 8),
          ChatbotSuggestionsBar(
            selected: _selected,
            onChanged: (s) => setState(() => _selected = s),
          ),
        ],
      ),
      footer: FilledButton.icon(
        onPressed: () => Navigator.of(context)
            .pop((text: widget.text, suggestion: _selected)),
        icon: const Icon(Icons.send),
        label: const Text('Send to Chatbot'),
      ),
    );
  }
}
