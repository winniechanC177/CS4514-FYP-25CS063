import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../base/app_bottom_sheet.dart';
import '../database/database_helper.dart' as dbHelper;
import '../benchmark/benchmark_screen.dart' as benchmark;
import '../types/language_choose.dart';
import '../utils/confirm_dialog.dart';

class Settings extends StatefulWidget {
  final Future<void> Function()? onDatabaseChanged;

  const Settings({super.key, this.onDatabaseChanged});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  static const _pLang = 'default_source_language';
  static const _pConvLang = 'default_target_language';

  LanguageChoose? _language = LanguageChoose.english;
  LanguageChoose _convLanguage = LanguageChoose.chineseTraditional;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSource = prefs.getString(_pLang);
    final savedTarget = prefs.getString(_pConvLang);

    if (!mounted) return;
    setState(() {
      _language = LanguageChoose.tryParse(savedSource);
      _convLanguage = LanguageChoose.tryParse(savedTarget) ?? LanguageChoose.chineseTraditional;
      _isLoading = false;
    });
  }


  Future<void> _saveDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    if (_language != null) {
      await prefs.setString(_pLang, _language!.name);
    } else {
      await prefs.remove(_pLang);
    }
    await prefs.setString(_pConvLang, _convLanguage.name);
  }

  Future<void> _pickSourceLanguage() async {
    final result = await showStyledBottomSheet<({bool selected, LanguageChoose? lang})>(
      context: context,
      builder: (_) => _SourceLangPickerSheet(current: _language),
    );
    if (result == null || !result.selected || !mounted) return;
    setState(() => _language = result.lang);
    await _saveDefaults();
  }

  Future<void> _pickTargetLanguage() async {
    final picked = await showStyledBottomSheet<LanguageChoose>(
      context: context,
      builder: (_) => _TargetLangPickerSheet(
        current: _convLanguage,
        title: 'Default target language',
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _convLanguage = picked);
    await _saveDefaults();
  }


  Future<void> _clearHistory(String type, String label) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear $label history?',
      content: 'This will remove all $label sessions.',
      confirmText: 'Clear',
    );
    if (confirmed != true) return;

    await dbHelper.DatabaseHelper.instance.deleteAllSessions(type);
    await widget.onDatabaseChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label history cleared')),
    );
  }

  Future<void> _resetDatabase({required bool hard}) async {
    final confirmed = await showConfirmDialog(
      context,
      title: hard ? 'Hard reset database?' : 'Soft reset database?',
      content: hard
          ? 'Hard reset drops and recreates all tables. IDs restart from 1.'
          : 'Soft reset deletes all data and keeps table structure.',
      confirmText: hard ? 'Hard Reset' : 'Soft Reset',
    );
    if (confirmed != true) return;

    if (hard) {
      await dbHelper.DatabaseHelper.instance.hardReset();
    } else {
      await dbHelper.DatabaseHelper.instance.softReset();
    }
    await widget.onDatabaseChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hard ? 'Hard reset completed' : 'Soft reset completed')),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const ListTile(
          title: Text('Defaults', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('Default source language'),
          subtitle: Text(_language?.label ?? 'Auto detect'),
          onTap: _pickSourceLanguage,
        ),
        ListTile(
          leading: const Icon(Icons.translate),
          title: const Text('Default target language'),
          subtitle: Text(_convLanguage.label),
          onTap: _pickTargetLanguage,
        ),
        const Divider(),
        const ListTile(
          title: Text('Benchmark', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('Translation Benchmark'),
          subtitle: const Text('BLEU score + latency on real model'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const benchmark.BenchmarkScreen(),
            ),
          ),
        ),
        const Divider(),
        const ListTile(
          title: Text('Database', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Clear Translation history'),
          onTap: () => _clearHistory('translation', 'Translation'),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Clear Learning history'),
          onTap: () => _clearHistory('learning', 'Learning'),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Clear Testing history'),
          onTap: () => _clearHistory('test', 'Testing'),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Clear Chatbot history'),
          onTap: () => _clearHistory('chatbot', 'Chatbot'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _resetDatabase(hard: false),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Soft Reset DB'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _resetDatabase(hard: true),
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Hard Reset DB'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _SourceLangPickerSheet extends StatelessWidget {
  final LanguageChoose? current;
  const _SourceLangPickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Default source language',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Auto detect'),
            trailing: current == null ? const Icon(Icons.check) : null,
            onTap: () =>
                Navigator.of(context).pop((selected: true, lang: null)),
          ),
          ...LanguageChoose.values.map(
            (lang) => ListTile(
              title: Text(lang.label),
              trailing: lang == current ? const Icon(Icons.check) : null,
              onTap: () =>
                  Navigator.of(context).pop((selected: true, lang: lang)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetLangPickerSheet extends StatelessWidget {
  final LanguageChoose current;
  final String title;
  const _TargetLangPickerSheet({required this.current, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: LanguageChoose.values
            .map(
              (lang) => ListTile(
                title: Text(lang.label),
                trailing: lang == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(lang),
              ),
            )
            .toList(),
      ),
    );
  }
}

