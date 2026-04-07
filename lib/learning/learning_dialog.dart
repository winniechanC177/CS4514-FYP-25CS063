import 'package:flutter/material.dart';
import '../types/language_choose.dart';
import '../base/app_bottom_sheet.dart';

class LearningDialog extends StatefulWidget {
  final LanguageChoose language;
  final LanguageChoose convLanguage;
  final Function(String, LanguageChoose, LanguageChoose) onConfirm;

  const LearningDialog({
    super.key,
    required this.language,
    required this.convLanguage,
    required this.onConfirm,
  });

  @override
  State<LearningDialog> createState() => _LearningDialogState();
}

class _LearningDialogState extends State<LearningDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  late LanguageChoose _selectedLanguage;
  late LanguageChoose _selectedConvLanguage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _selectedLanguage = widget.language;
    _selectedConvLanguage = widget.convLanguage;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onConfirm() {
    if (_formKey.currentState!.validate()) {
      widget.onConfirm(
        _controller.text.trim(),
        _selectedLanguage,
        _selectedConvLanguage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Add Learning Topic',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Input your learning topic',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please input your learning topic';
                }
                return null;
              },
              onFieldSubmitted: (_) => _onConfirm(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<LanguageChoose>(
              initialValue: _selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Used Language',
                border: OutlineInputBorder(),
              ),
              items: LanguageChoose.values
                  .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedLanguage = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<LanguageChoose>(
              initialValue: _selectedConvLanguage,
              decoration: const InputDecoration(
                labelText: 'Translated Language',
                border: OutlineInputBorder(),
              ),
              items: LanguageChoose.values
                  .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedConvLanguage = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _onConfirm,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
