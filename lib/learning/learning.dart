import 'package:flutter/material.dart';
import 'learning_vocab_block.dart';
import '../types/language_choose.dart';
import 'learning_dialog.dart';
import '../database/database_helper.dart' as dbHelper;
import '../model/model_response.dart';
import '../base/base_conversation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../chatbot/chatbot_suggestions.dart';

class Learning extends StatefulWidget {
  final List<LearningVocabBlock>? learningBlocks;
  final int? sessionId;
  final VoidCallback? onNewSession;
  final ValueChanged<int>? onSessionCreated;
  final void Function(String text, {ChatbotSuggestion? suggestion})? onSendToChatbot;

  const Learning({
    super.key,
    this.learningBlocks,
    this.sessionId,
    this.onNewSession,
    this.onSessionCreated,
    this.onSendToChatbot,
  });

  @override
  State<Learning> createState() => _LearningState();
}

class _LearningState extends BaseConversationScreenState<Learning> {
  bool _isGenerating = false;
  final ModelResponse _modelResponse = ModelResponse();

  int? _currentSessionId;
  String? _topic;
  static const _pLang = 'default_source_language';
  static const _pConvLang = 'default_target_language';
  LanguageChoose? _language;
  LanguageChoose? _convLanguage;

  bool get _hasCurrentSession =>
      _currentSessionId != null &&
      _topic != null &&
      _language != null &&
      _convLanguage != null;

  String _buildSessionDescription(int count, LanguageChoose lang, LanguageChoose convLang) {
    final unit = count == 1 ? 'word' : 'words';
    return '${lang.label} -> ${convLang.label} · $count $unit';
  }

  Future<void> _refreshSessionDescription() async {
    final sessionId = _currentSessionId;
    final lang = _language;
    final convLang = _convLanguage;
    if (sessionId == null || lang == null || convLang == null) return;

    final db = dbHelper.DatabaseHelper.instance;
    final count = await db.getSessionLength(sessionId, 'learning');
    await db.updateSessionContent(
      sessionId,
      'learning',
      _buildSessionDescription(count, lang, convLang),
    );
  }

  @override
  void initState() {
    _currentSessionId = widget.sessionId;
    final blocks = widget.learningBlocks;
    if (blocks != null && blocks.isNotEmpty) {
      _language = blocks.first.language;
      _convLanguage = blocks.first.convLanguage;
    }
    super.initState();
    if (_currentSessionId != null) {
      _loadSessionTopic(_currentSessionId!);
    }
    _loadPrefs();
  }
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString(_pLang);
    final savedConvLang = prefs.getString(_pConvLang);
    if (!mounted) return;
    setState(() {
      _language ??= LanguageChoose.tryParse(savedLang) ?? LanguageChoose.english;
      _convLanguage ??= LanguageChoose.tryParse(savedConvLang) ?? LanguageChoose.chineseTraditional;
    });
  }
  Future<void> _loadSessionTopic(int sessionId) async {
    final session = await dbHelper.DatabaseHelper.instance.getLearningSession(sessionId);
    if (session != null && mounted) {
      setState(() => _topic = session['Title'] as String?);
    }
  }

  @override
  bool get needsInitialBlock => false;

  @override
  bool hasHistory() =>
      widget.learningBlocks != null && widget.learningBlocks!.isNotEmpty;

  @override
  List<Widget> createHistoryBlocks() {
    final blocks = widget.learningBlocks;
    if (blocks == null) return [];
    return blocks
        .map(
          (b) => LearningVocabBlock(
            blockId: b.blockId,
            text: b.text,
            language: b.language,
            convLanguage: b.convLanguage,
            convText: b.convText,
            example: b.example,
            entryType: b.entryType,
            onDelete: () async {
              await dbHelper.DatabaseHelper.instance.deleteLearningItem(b.blockId);
              deleteBlock(b.blockId);
              await _refreshSessionDescription();
            },
            onSendToChatbot: widget.onSendToChatbot,
          ),
        )
        .toList();
  }

  @override
  Widget createNewBlock({required int blockId}) => const SizedBox.shrink();

  @override
  bool get createBlockOnEmpty => false;

  @override
  Future<void> onBlockReplied({
    required int blockId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> onBlocksEmpty() async {
    final sessionId = _currentSessionId;
    if (sessionId != null) {
      await dbHelper.DatabaseHelper.instance.deleteSession(sessionId, 'learning');
    }
    if (mounted) {
      setState(() {
        _currentSessionId = null;
        _topic = null;
      });
    }
    widget.onNewSession?.call();
  }

  @override
  Widget buildBody() {
    final hasVocabBlocks = bodyBlocks.any((w) => w is LearningVocabBlock);
    if (!hasVocabBlocks && !_isGenerating) {
      return GestureDetector(
        onTap: () => Scaffold.of(context).openDrawer(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No learning session loaded',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap here or open the drawer to pick a session,\n'
                'or press + to create a new one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        super.buildBody(),
        if (_isGenerating)
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.purple)),
                      SizedBox(width: 12),
                      Text('Generating vocabulary…'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget buildFloatingActionButton() {
    if (_isGenerating) {
      return FloatingActionButton(
        onPressed: null,
        tooltip: 'Generating…',
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
        ),
      );
    }

    if (!_hasCurrentSession) {
      return FloatingActionButton(
        onPressed: _showLearningDialog,
        tooltip: 'Tap to create new learning session',
        child: const Icon(Icons.add),
      );
    }

    return buildLongPressFab(
      onTap: _generateMoreWords,
      onLongPress: _showLearningDialog,
      tooltip: 'Tap to generate words · Long press for new session',
      icon: Icons.add,
    );
  }

  void _showLearningDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LearningDialog(
        language: _language ?? LanguageChoose.english,
        convLanguage: _convLanguage ?? LanguageChoose.japanese,
        onConfirm: (topic, lang, convLang) {
          Navigator.of(context).pop();
          _startNewSession(topic, lang, convLang);
        },
      ),
    );
  }

  Future<void> _generateMoreWords() async {
    await _generateVocab(
      _topic!,
      _language!,
      _convLanguage!,
      _currentSessionId!,
    );
  }

  Future<void> _startNewSession(
      String topic, LanguageChoose lang, LanguageChoose convLang) async {
    final db = dbHelper.DatabaseHelper.instance;
    final sessionId = await db.createLearningSession(
      topic,
      _buildSessionDescription(0, lang, convLang),
    );
    widget.onSessionCreated?.call(sessionId);
    setState(() {
      bodyBlocks.clear();
      _currentSessionId = sessionId;
      _topic = topic;
      _language = lang;
      _convLanguage = convLang;
    });
    await _generateVocab(topic, lang, convLang, sessionId);
  }

  Future<void> _generateVocab(
    String topic,
    LanguageChoose lang,
    LanguageChoose convLang,
    int sessionId,
  ) async {
    final db = dbHelper.DatabaseHelper.instance;
    setState(() => _isGenerating = true);
    try {
      final sw = Stopwatch()..start();
      final vocabList =
          await _modelResponse.learningVocabResponse(topic, lang, convLang);
      sw.stop();
      debugPrint('[Timer] learningVocabResponse took ${sw.elapsedMilliseconds} ms (${vocabList.length} words)');

      final newBlocks = <LearningVocabBlock>[];
      for (final v in vocabList) {
        final itemId = await db.createLearningItem(
          sessionId: sessionId,
          lang: lang.label,
          convLang: convLang.label,
          text: v.text,
          convText: v.convText,
          example: v.example,
        );
        if (!mounted) break;
        newBlocks.add(LearningVocabBlock(
          blockId: itemId,
          text: v.text,
          language: lang,
          convLanguage: convLang,
          convText: v.convText,
          example: v.example,
          onDelete: () async {
            await db.deleteLearningItem(itemId);
            deleteBlock(itemId);
            await _refreshSessionDescription();
          },
          onSendToChatbot: widget.onSendToChatbot,
        ));
      }

      if (mounted && newBlocks.isNotEmpty) {
        setState(() {
          bodyBlocks.addAll(newBlocks);
        });
      }

      await _refreshSessionDescription();

      if (vocabList.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not parse vocabulary from model response. Please try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating vocabulary: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

}

