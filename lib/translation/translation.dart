import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translation_block.dart';
import '../types/language_choose.dart';
import '../database/database_helper.dart' as dbHelper;
import '../base/base_conversation_screen.dart';
import '../chatbot/chatbot_suggestions.dart';

class Translation extends StatefulWidget {
  final int? sessionId;
  final List<Map<String, dynamic>>? translationHistory;
  final VoidCallback? onNewSession;
  final void Function(int sessionId)? onSessionCreated;
  final void Function(String text, {ChatbotSuggestion? suggestion})? onSendToChatbot;

  const Translation({
    super.key,
    this.sessionId,
    this.translationHistory,
    this.onNewSession,
    this.onSessionCreated,
    this.onSendToChatbot,
  });

  @override
  State<Translation> createState() => _TranslationState();
}

class _TranslationState extends BaseConversationScreenState<Translation> {
  static const _pLang     = 'default_source_language';
  static const _pConvLang = 'default_target_language';

  @override
  int get maxTitleLength => 80;

  LanguageChoose? _language;
  LanguageChoose _convLanguage = LanguageChoose.english;
  int? _sessionId;
  final Map<int, int> _blockItemIds = {};

  @override
  bool get needsInitialBlock => false;

  @override
  void initState() {
    _sessionId = widget.sessionId;
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSource = prefs.getString(_pLang);
    final savedTarget = prefs.getString(_pConvLang);
    if (!mounted) return;
    setState(() {
      _language = LanguageChoose.tryParse(savedSource);
      _convLanguage =
          LanguageChoose.tryParse(savedTarget) ?? LanguageChoose.chineseTraditional;
    });

    if (bodyBlocks.isEmpty || hasHistory()) {
      onAddBlockPressed();
    }
  }

  Future<void> _savePrefs(LanguageChoose? lang, LanguageChoose convLang) async {
    setState(() {
      _language = lang;
      _convLanguage = convLang;
    });
    final prefs = await SharedPreferences.getInstance();
    if (lang != null) {
      await prefs.setString(_pLang, lang.label);
    } else {
      await prefs.remove(_pLang);
    }
    await prefs.setString(_pConvLang, convLang.label);
  }


  String _buildHistoryTitleFromItems(List<Map<String, dynamic>> items) {
    final texts = items.reversed
        .map((i) => (i['Text'] as String? ?? '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (texts.isEmpty) return 'Translation';
    return ellipsis(texts.join(' | '), maxTitleLength);
  }

  String _buildHistoryDescription({
    required String lang,
    required String convLang,
    required int count,
  }) {
    final suffix = count == 1 ? 'translation' : 'translations';
    return 'Current:\n$lang -> $convLang · $count $suffix';
  }

  Future<void> _refreshSessionMetadata({
    required int sessionId,
    required String lang,
    required String convLang,
  }) async {
    final db = dbHelper.DatabaseHelper.instance;
    final items = await db.getTranslationSessionItems(sessionId);
    final title = _buildHistoryTitleFromItems(items);
    final description = _buildHistoryDescription(
      lang: lang,
      convLang: convLang,
      count: items.length,
    );
    await db.updateSessionTitle(sessionId, 'translation', title);
    await db.updateSessionContent(sessionId, 'translation', description);
  }


  @override
  bool hasHistory() => widget.translationHistory?.isNotEmpty ?? false;

  @override
  Widget createNewBlock({required int blockId}) {
    return TranslationBlock(
      blockId: blockId,
      language: _language,
      convLanguage: _convLanguage,
      onBusyChanged: onBlockBusyChanged,
      onDelete: () async {
        final itemId = _blockItemIds[blockId];
        if (itemId != null) {
          await dbHelper.DatabaseHelper.instance.deleteTranslationItem(itemId);
          _blockItemIds.remove(blockId);
        }
        deleteBlock(blockId);
        if (_sessionId != null) {
          await _refreshSessionMetadata(
            sessionId: _sessionId!,
            lang: _language?.label ?? 'English',
            convLang: _convLanguage.label,
          );
        }
      },
      onSendToChatbot: widget.onSendToChatbot,
      onLanguageChanged: (lang, convLang) => _savePrefs(lang, convLang),
      onReplied: ({
        required int blockId,
        required String text,
        required String convText,
        required LanguageChoose lang,
        required LanguageChoose convLang,
      }) async {
        updateLatestBlockReply(blockId: blockId, hasReply: convText.trim().isNotEmpty);
        await onBlockReplied(
          blockId: blockId,
          data: {
            'text': text,
            'convText': convText,
            'lang': lang.label,
            'convLang': convLang.label,
          },
        );
      },
    );
  }

  @override
  List<Widget> createHistoryBlocks() {
    return widget.translationHistory!.map((item) {
      final id = nextBlockId++;
      final itemId = item['TranslationItemID'] as int?;
      if (itemId != null) _blockItemIds[id] = itemId;
      return TranslationBlock(
        blockId: id,
        language: LanguageChoose.tryParse(item['Lang'] as String?),
        convLanguage: LanguageChoose.tryParse(item['ConvLang'] as String?) ??
            LanguageChoose.chineseTraditional,
        text: item['Text'] as String?,
        convText: item['ConvText'] as String?,
        onBusyChanged: onBlockBusyChanged,
        onDelete: () async {
          if (itemId != null) {
            await dbHelper.DatabaseHelper.instance.deleteTranslationItem(itemId);
          }
          deleteBlock(id);
          if (_sessionId != null) {
            final rowLang = item['Lang'] as String? ?? 'English';
            final rowConvLang = item['ConvLang'] as String? ?? 'Chinese';
            await _refreshSessionMetadata(
              sessionId: _sessionId!,
              lang: rowLang,
              convLang: rowConvLang,
            );
          }
        },
        onSendToChatbot: widget.onSendToChatbot,
        onLanguageChanged: (lang, convLang) => _savePrefs(lang, convLang),
        onReplied: ({
          required int blockId,
          required String text,
          required String convText,
          required LanguageChoose lang,
          required LanguageChoose convLang,
        }) async {
          updateLatestBlockReply(blockId: blockId, hasReply: convText.trim().isNotEmpty);
          await onBlockReplied(
            blockId: blockId,
            data: {
              'text': text,
              'convText': convText,
              'lang': lang.label,
              'convLang': convLang.label,
            },
          );
        },
      );
    }).toList();
  }

  @override
  Future<void> onBlockReplied({
    required int blockId,
    required Map<String, dynamic> data,
  }) async {
    final existingItemId = _blockItemIds[blockId];
    if (existingItemId == null && blockId != latestBlockId) return;

    final text     = data['text']     as String;
    final convText = data['convText'] as String;
    final lang     = data['lang']     as String;
    final convLang = data['convLang'] as String;

    if (convText.trim().isEmpty) return;

    final db = dbHelper.DatabaseHelper.instance;
    final isNew = _sessionId == null;

    if (isNew) {
      _sessionId = await db.createTranslationSession(
        ellipsis(text, maxTitleLength),
        _buildHistoryDescription(lang: lang, convLang: convLang, count: 0),
      );
      widget.onSessionCreated?.call(_sessionId!);
    }

    if (existingItemId != null) {
      await db.updateTranslationItem(
        itemId: existingItemId,
        text: text,
        convText: convText,
        lang: lang,
        convLang: convLang,
      );
    } else {
      final newItemId = await db.createTranslationItem(
        sessionId: _sessionId!,
        text: text,
        convText: convText,
        lang: lang,
        convLang: convLang,
      );
      _blockItemIds[blockId] = newItemId;
    }

    await _refreshSessionMetadata(
      sessionId: _sessionId!,
      lang: lang,
      convLang: convLang,
    );
  }

  @override
  VoidCallback? get onNewSession => widget.onNewSession;

  @override
  Future<void> onBlocksEmpty() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      await dbHelper.DatabaseHelper.instance.deleteSession(sessionId, 'translation');
      _sessionId = null;
    }
    widget.onNewSession?.call();
  }
}
