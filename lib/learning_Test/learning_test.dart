import 'dart:math';
import 'package:flutter/material.dart';
import 'learning_test_block.dart';
import '../learning/vocab_entry.dart';
import '../database/database_helper.dart' as dbHelper;
import '../model/model_response.dart';
import '../base/base_conversation_screen.dart';
import '../chatbot/chatbot_suggestions.dart';
import '../types/language_choose.dart';

class LearningTest extends StatefulWidget {
  final List<LearningTestBlock>? testBlocks;
  final ValueChanged<int>? onSessionCreated;
  final void Function(String text, {ChatbotSuggestion? suggestion})? onSendToChatbot;
  final int? autoGenerateFromSessionId;
  final String? autoGenerateTitle;
  final int? testSessionId;
  final int? sourceLearningSessionId;

  const LearningTest({
    super.key,
    this.testBlocks,
    this.onSessionCreated,
    this.onSendToChatbot,
    this.autoGenerateFromSessionId,
    this.autoGenerateTitle,
    this.testSessionId,
    this.sourceLearningSessionId,
  });

  @override
  State<LearningTest> createState() => _LearningTestState();
}

class _LearningTestState extends BaseConversationScreenState<LearningTest> {
  bool _isGenerating = false;
  int _generatingCurrent = 0;
  int _generatingTotal = 0;
  final ModelResponse _modelResponse = ModelResponse();

  int? _currentTestSessionId;
  int? _sourceLearningSessionId;
  bool get _hasSession =>
      _currentTestSessionId != null && _sourceLearningSessionId != null;

  @override
  void initState() {
    _currentTestSessionId = widget.testSessionId;
    _sourceLearningSessionId = widget.sourceLearningSessionId;
    super.initState();
    if (widget.autoGenerateFromSessionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateFromLearningSession(
          widget.autoGenerateFromSessionId!,
          widget.autoGenerateTitle ?? 'Vocab Test',
        );
      });
    }
  }

  @override
  bool get needsInitialBlock => false;

  @override
  bool hasHistory() =>
      widget.testBlocks != null && widget.testBlocks!.isNotEmpty;

  @override
  List<Widget> createHistoryBlocks() {
    final blocks = widget.testBlocks;
    if (blocks == null) return [];
    return blocks
        .map(
          (b) => LearningTestBlock(
            blockId: b.blockId,
            question: b.question,
            options: b.options,
            correctIndex: b.correctIndex,
            onDelete: () async {
              await dbHelper.DatabaseHelper.instance.deleteTestItem(b.blockId);
              deleteBlock(b.blockId);
              if (_currentTestSessionId != null) {
                await _refreshTestDescription(_currentTestSessionId!);
              }
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
    final sessionId = _currentTestSessionId;
    if (sessionId != null) {
      await dbHelper.DatabaseHelper.instance.deleteSession(sessionId, 'test');
    }
    if (mounted) {
      setState(() {
        _currentTestSessionId = null;
        _sourceLearningSessionId = null;
      });
    }
  }

  @override
  Widget buildBody() {
    if (bodyBlocks.isEmpty && !_isGenerating) {
      return GestureDetector(
        onTap: () => Scaffold.of(context).openDrawer(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.quiz_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No test loaded',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap here or open the drawer\nto select a vocabulary session',
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
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      Text(
                          'Generating question $_generatingCurrent / $_generatingTotal…'),
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
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
        ),
      );
    }
    if (!_hasSession) return const SizedBox.shrink();

    return FloatingActionButton(
      onPressed: _addMoreQuestions,
      tooltip: 'Add more questions',
      child: const Icon(Icons.add),
    );
  }

  Future<void> _refreshTestDescription(int sessionId) async {
    final db = dbHelper.DatabaseHelper.instance;
    final count = await db.getSessionLength(sessionId, 'test');
    final unit = count == 1 ? 'question' : 'questions';

    String langPair = '';
    final srcId = _sourceLearningSessionId;
    if (srcId != null) {
      final items = await db.getLearningSessionItems(srcId);
      if (items.isNotEmpty) {
        final rawLang = items.first['Lang'] as String? ?? '';
        final rawConvLang = items.first['ConvLang'] as String? ?? '';
        final lang = LanguageChoose.tryParse(rawLang)?.label ?? rawLang;
        final convLang = LanguageChoose.tryParse(rawConvLang)?.label ?? rawConvLang;
        if (lang.isNotEmpty && convLang.isNotEmpty) {
          langPair = '$lang -> $convLang';
        }
      }
    }

    final content =
        langPair.isNotEmpty ? '$langPair · $count $unit' : '$count $unit';
    await db.updateSessionContent(sessionId, 'test', content);
  }

  Future<void> _addMoreQuestions() async {
    final db = dbHelper.DatabaseHelper.instance;
    final items = await db.getLearningSessionItems(_sourceLearningSessionId!);
    final vocab = items.map((item) => VocabEntry.fromMap(item)).toList();
    if (vocab.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Need at least 4 vocabulary items to generate questions.'),
        ));
      }
      return;
    }
    await _generateFromVocab(
      vocab,
      '',
      existingSessionId: _currentTestSessionId,
    );
  }

  Future<void> _generateFromLearningSession(
      int learningSessionId, String title) async {
    final db = dbHelper.DatabaseHelper.instance;
    final items = await db.getLearningSessionItems(learningSessionId);
    final vocab = items.map((item) => VocabEntry.fromMap(item)).toList();
    if (vocab.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Need at least 4 vocabulary items to generate a test.'),
        ));
      }
      return;
    }
    await _generateFromVocab(vocab, title,
        sourceLearningSessionId: learningSessionId);
  }

  Future<void> _generateFromVocab(
    List<VocabEntry> vocab,
    String topic, {
    int? sourceLearningSessionId,
    int? existingSessionId,
  }) async {
    final db = dbHelper.DatabaseHelper.instance;

    final int sessionId;
    if (existingSessionId != null) {
      sessionId = existingSessionId;
    } else {
      sessionId = await db.createTestSession(topic, '0 questions',
          sourceLearningSessionId: sourceLearningSessionId);
      widget.onSessionCreated?.call(sessionId);
      if (mounted) {
        setState(() {
          _currentTestSessionId = sessionId;
          _sourceLearningSessionId = sourceLearningSessionId;
        });
      }
    }

    vocab.shuffle();
    final questionCount = min(5, vocab.length);

    setState(() {
      _isGenerating = true;
      _generatingCurrent = 0;
      _generatingTotal = questionCount;
    });

    try {
      for (int q = 0; q < questionCount; q++) {
        final correct = vocab[q];
        final n = vocab.length;
        final distractors = [
          vocab[(q + 1) % n],
          vocab[(q + 2) % n],
          vocab[(q + 3) % n],
        ];

        if (mounted) setState(() => _generatingCurrent = q + 1);

        final type = QuizQuestionType.values[q % QuizQuestionType.values.length];

        final useSourceOptions = type == QuizQuestionType.sourceWord;
        final optionsList = (useSourceOptions
                ? [correct.text, ...distractors.map((d) => d.text)]
                : [correct.convText, ...distractors.map((d) => d.convText)])
            ..shuffle(Random());
        final correctIndex = optionsList
            .indexOf(useSourceOptions ? correct.text : correct.convText);

        final question = await _modelResponse.generateQuizQuestion(
          correctWord: correct.text,
          correctTranslation: correct.convText,
          distractorOptions: useSourceOptions
              ? distractors.map((d) => d.text).toList()
              : distractors.map((d) => d.convText).toList(),
          language: LanguageChoose.tryParse(correct.lang)?.label ??
              (correct.lang.isNotEmpty ? correct.lang : 'English'),
          convLanguage: LanguageChoose.tryParse(correct.convLang)?.label ??
              (correct.convLang.isNotEmpty ? correct.convLang : 'Japanese'),
          type: type,
        );

        final itemId = await db.createTestItemWithOptions(
          sessionId: sessionId,
          question: question,
          options: List.generate(
              optionsList.length,
              (i) => {
                    'option': optionsList[i],
                    'isCorrect': i == correctIndex,
                    'explanation': null,
                  }),
        );

        if (!mounted) break;
        setState(() {
          bodyBlocks.add(LearningTestBlock(
            blockId: itemId,
            question: question,
            options: optionsList,
            correctIndex: correctIndex,
            onDelete: () async {
              await db.deleteTestItem(itemId);
              deleteBlock(itemId);
              await _refreshTestDescription(sessionId);
            },
            onSendToChatbot: widget.onSendToChatbot,
          ));
        });

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

      await _refreshTestDescription(sessionId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating questions: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatingCurrent = 0;
          _generatingTotal = 0;
        });
      }
    }
  }
}
