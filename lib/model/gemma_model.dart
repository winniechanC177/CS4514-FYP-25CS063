import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../types/language_choose.dart';
import '../types/quiz_question_type.dart';
import '../learning/vocab_entry.dart';


abstract class PromptBuilder {
  String build();
}

class TranslationPromptBuilder extends PromptBuilder {
  final String? translationMemory;
  final String textToTranslate;
  final String convLanguage;
  final String? language;

  TranslationPromptBuilder({
    required this.textToTranslate,
    required this.convLanguage,
    this.language,
    this.translationMemory,
  });

  @override
  String build() {
    final from = language != null
        ? 'from $language'
        : 'detecting the source language automatically';
    final buffer = StringBuffer();
    buffer.writeln('System: You are a professional translator.');
    buffer.writeln('System: Follow the terminology and tone exactly.');
    if (translationMemory != null && translationMemory!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
          'Translation memory (reusable glossary, names, tone/style notes only — not full-sentence examples):\n${translationMemory!.trim()}');
    }
    buffer.writeln();
    buffer.writeln(
        'Instructions:\n'
        '- Translate $from to $convLanguage.\n'
        '- Follow the translation memory exactly for known terms, names, and style rules.\n'
        '- Do NOT copy a whole previous translation unless the current source text is effectively the same content.\n'
        '- Output ONLY the $convLanguage translation — no labels, no "Translation:", no preamble, no explanations, no notes, no surrounding quotes.');
    buffer.writeln();
    buffer.writeln('Text:\n$textToTranslate');
    return buffer.toString().trim();
  }
}

class TranslationMemoryBuilder extends PromptBuilder {
  final String? existingMemory;
  final String text;
  final String convText;
  final String? language;
  final String convLanguage;

  TranslationMemoryBuilder({
    required this.text,
    required this.convText,
    required this.convLanguage,
    this.language,
    this.existingMemory,
  });

  @override
  String build() {
    final buffer = StringBuffer();
    buffer.writeln('You are a translation memory assistant.');
    buffer.writeln('Maintain a concise translation memory from past translations.');
    buffer.writeln('Store only reusable glossary, names, and tone/style rules.');
    buffer.writeln('Do NOT store full sentence-to-sentence mappings.');
    buffer.writeln();
    if (existingMemory != null && existingMemory!.trim().isNotEmpty) {
      buffer.writeln('Existing memory:');
      buffer.writeln(existingMemory!.trim());
      buffer.writeln();
    }
    final lang = language ?? 'auto-detected';
    buffer.writeln('New translation:');
    buffer.writeln('Source ($lang): $text');
    buffer.writeln('Translation ($convLanguage): $convText');
    buffer.writeln();
    buffer.writeln('Update the memory to include:');
    buffer.writeln('- Key terms and their preferred $convLanguage translations');
    buffer.writeln('- Names (people, places, entities) and their translations');
    buffer.writeln('- Writing tone and style notes');
    buffer.writeln('- If there is no reusable term, keep the memory unchanged or only update style notes');
    buffer.writeln();
    buffer.writeln('Output only the updated memory in plain text, max 60 words.');
    buffer.writeln('Be concise. Omit anything not useful for future translations.');
    return buffer.toString().trim();
  }
}

class LearningVocabFirstPromptBuilder extends PromptBuilder {
  final String topic;
  final String language;

  LearningVocabFirstPromptBuilder({
    required this.topic,
    required this.language,
  });

  @override
  String build() {
    return '''You are a language teacher.
List exactly 10 vocabulary words or grammar patterns in $language for the topic: "$topic".

Output ONLY 10 lines. Each line must begin with V (vocabulary) or G (grammar):
  V|WORD_OR_PHRASE
  G|GRAMMAR_PATTERN

Rules:
- V lines: a $language word or short phrase relevant to the topic.
- G lines: a $language grammar pattern or sentence structure relevant to the topic.
- Include at least 2 G (grammar) lines.
- No translations, no explanations, no examples — $language only.
- No numbering, no bullets, no blank lines, no extra text.

Example lines:
V|apple
G|to be + adjective'''.trim();
  }
}

class LearningVocabNextPromptBuilder extends PromptBuilder {
  final String convLanguage;
  final String language;
  final List<String> firstLines;

  LearningVocabNextPromptBuilder({
    required this.convLanguage,
    required this.language,
    required this.firstLines,
  });

  @override
  String build() {
    final itemBlock = firstLines.isNotEmpty
        ? '\nItems to translate (keep WORD/PATTERN exactly as written):\n'
            '${firstLines.join('\n')}\n'
        : '';
    return '''Now translate each $language item below into $convLanguage and add a short example sentence.$itemBlock
Output exactly ${firstLines.isEmpty ? 10 : firstLines.length} lines in the same order, keeping the V|/G| prefix:
  V|WORD|TRANSLATION|SHORT_EXAMPLE
  G|PATTERN|EXPLANATION|SHORT_EXAMPLE

Rules:
- WORD/PATTERN must be copied EXACTLY from the list above — do NOT translate or change it.
- V lines: TRANSLATION is the $convLanguage equivalent of the $language WORD.
- G lines: EXPLANATION is the meaning of the grammar PATTERN in $language.
- SHORT_EXAMPLE: one short $convLanguage sentence using this item (max 12 words).
- Separate fields with | only. No numbering, no bullets, no blank lines, no extra text.

Example lines:
V|apple|りんご|りんごが好きです。
G|to be + adjective|〜は〜です|これは大きいです。'''.trim();
  }
}


class QuizQuestionPromptBuilder extends PromptBuilder {
  final String correctWord;
  final String correctTranslation;
  final List<String> distractorOptions;
  final String language;
  final String convLanguage;
  final QuizQuestionType type;

  QuizQuestionPromptBuilder({
    required this.correctWord,
    required this.correctTranslation,
    required this.distractorOptions,
    required this.language,
    required this.convLanguage,
    this.type = QuizQuestionType.targetWord,
  });

  @override
  String build() {
    switch (type) {
      case QuizQuestionType.targetWord:
        return '''You are a creative language quiz generator.
The student is learning $convLanguage. Their interface language is $language.

Correct pair: "$correctWord" ($language) = "$correctTranslation" ($convLanguage)
Wrong $convLanguage options: ${distractorOptions.join(', ')}

Write ONE original question stem written ENTIRELY IN $language.
The question must test which $convLanguage option correctly translates "$correctWord".
"$correctTranslation" must be the only acceptable answer.

Use a VARIED phrasing each time. Possible styles (do not copy word-for-word):
  • Direct translation ask: "What is the $convLanguage word for '$correctWord'?"
  • Reverse prompt: "How would you say '$correctWord' in $convLanguage?"
  • Fill-in: "The $convLanguage translation of '$correctWord' is ___."
  • Multiple-choice lead-in: "Which $convLanguage word best expresses '$correctWord'?"
  • Context hint: "When speaking $convLanguage, which word means '$correctWord'?"
Do NOT reuse the same sentence structure every time.

Rules:
- Written in $language only. No $convLanguage characters in the question.
- Do NOT include the answer options or explanation.
- Output exactly one line ending with a question mark or a blank (___).'''.trim();

      case QuizQuestionType.sourceWord:
        return '''You are a creative language quiz generator.
The student is learning $convLanguage. Their interface language is $language.

Correct pair: "$correctTranslation" ($convLanguage) = "$correctWord" ($language)
Wrong $language options: ${distractorOptions.join(', ')}

Write ONE original question stem written ENTIRELY IN $language.
The question must test which $language word is the correct meaning of "$correctTranslation".
"$correctWord" must be the only acceptable answer.

Use a VARIED phrasing each time. Possible styles (do not copy word-for-word):
  • Direct ask: "Which $language word means '$correctTranslation'?"
  • Reading context: "You see '$correctTranslation' in a $convLanguage text. What does it mean?"
  • Conversation context: "A $convLanguage speaker says '$correctTranslation'. What are they referring to?"
  • Fill-in: "The $language meaning of '$correctTranslation' is ___."
  • Definition prompt: "How would you translate '$correctTranslation' into $language?"
Do NOT reuse the same sentence structure every time.

Rules:
- Written in $language only.
- Do NOT include the answer options or explanation.
- Output exactly one line ending with a question mark or a blank (___).'''.trim();

      case QuizQuestionType.travelConversation:
        return '''You are a creative language quiz generator.
The student is learning $convLanguage travel vocabulary. Their interface language is $language.

Correct pair: "$correctWord" ($language) = "$correctTranslation" ($convLanguage)
Wrong $convLanguage options: ${distractorOptions.join(', ')}

Write ONE short, imaginative travel-scenario question written ENTIRELY IN $language.
Pick a realistic travel setting that fits "$correctWord" naturally — choose from:
  hotel check-in, airport, restaurant, train/bus station, taxi, pharmacy,
  souvenir shop, museum, beach, emergency, asking for directions.
Describe a specific mini-scene, then ask which $convLanguage word the traveller needs.
"$correctTranslation" must be the only correct answer.

Vary the scenario and sentence structure each time. Possible styles:
  • "You have just landed and need to ask for a ___. Which $convLanguage word do you use?"
  • "At the restaurant the waiter asks what you want. You want a ___. What do you say in $convLanguage?"
  • "Your bag is lost at the airport. You need to find the ___. Which $convLanguage word describes it?"
Do NOT reuse the same opening sentence every time.

Rules:
- Written in $language only. No $convLanguage characters in the question.
- Do NOT include the answer options or explanation.
- Output exactly one line ending with a question mark.'''.trim();
    }
  }
}

class ChatbotPromptBuilder extends PromptBuilder {
  final String userMessage;

  ChatbotPromptBuilder({required this.userMessage});

  @override
  String build() {
    return 'You are a helpful language assistant. '
        'Rules: reply in plain text only — no markdown, no asterisks, '
        'no bullet symbols, no headers. Be concise. '
        'Answer only what is asked, nothing more.\n\n'
        '$userMessage';
  }
}


abstract class AbstractGemmaModel {
  Future<String> chatbotResponse(String prompt, Uint8List? image);
  Future<String> translateResponse(
    LanguageChoose? language,
    LanguageChoose convLanguage,
    String translation, {
    String? translationMemory,
  });
  Future<String> updateTranslationMemory({
    required String text,
    required String convText,
    required String convLanguage,
    String? language,
    String? existingMemory,
  });
  Future<List<VocabEntry>> learningVocabResponse(
      String topic, LanguageChoose language, LanguageChoose convLanguage);
  Future<String> generateQuizQuestion({
    required String correctWord,
    required String correctTranslation,
    required List<String> distractorOptions,
    required String language,
    required String convLanguage,
    QuizQuestionType type,
  });
  Future<void> resetChat();
  Future<void> reinitialize();
  Future<void> dispose();
}

class GemmaModel implements AbstractGemmaModel {
  static InferenceModel? _activeModel;
  static InferenceChat? _activeChat;
  static bool _supportImage = true;

  static Future<void> _queue = Future.value();

  Future<T> _enqueue<T>(Future<T> Function() fn) {
    final task = _queue.then<T>((_) => fn());
    _queue = task.then<void>((_) {}).catchError((_) {}).whenComplete(() {});
    return task;
  }

  static const int _maxTokens = 1536;
  static const int _compressionThreshold = 1000;
  static const int _tokenOverheadBuffer = 150;
  static const int _maxHistorySnapshotChars = 1500;

  Future<InferenceModel> get model async {
    if (_activeModel != null) return _activeModel!;
    _activeModel = await FlutterGemma.getActiveModel(
      maxTokens: _maxTokens,
      preferredBackend: PreferredBackend.cpu,
      supportImage: true,
    );
    return _activeModel!;
  }

  Future<InferenceChat> get chat async {
    if (_activeChat != null) return _activeChat!;
    try {
      _activeChat = await _activeModel!.createChat(
        temperature: 0.1,
        topK: 40,
        topP: 0.8,
        supportImage: _supportImage,
      );
      return _activeChat!;
    } on PlatformException catch (e) {
      if (!_supportImage) rethrow;
      debugPrint('[GemmaModel] createChat(supportImage=true) failed: $e. '
          'Falling back to text-only mode.');
      _supportImage = false;
      try { _activeModel?.close(); } catch (_) {}
      _activeModel = null;
      await model;
      _activeChat = await _activeModel!.createChat(
        temperature: 0.1,
        topK: 40,
        topP: 0.8,
        supportImage: false,
      );
      return _activeChat!;
    }
  }

  Future<void> _resetChatInternal() async {
    if (_activeChat != null) {
      try {
        await _activeChat!.session.close();
      } catch (_) {}
      _activeChat = null;
    }
  }

  @override
  Future<void> resetChat() => _enqueue(_resetChatInternal);
  Future<void> _reinitializeInternal() async {
    if (_activeChat != null) {
      try { await _activeChat!.session.close(); } catch (_) {}
      _activeChat = null;
    }
    try { _activeModel?.close(); } catch (_) {}
    _activeModel = null;
    _supportImage = true;
  }

  @override
  Future<void> reinitialize() => _enqueue(_reinitializeInternal);

  @override
  Future<void> dispose() => _enqueue(() async {
        final m = _activeModel;
        try {
          m?.close();
        } catch (_) {}
      });

  Future<int> _estimateTokens() async {
    int totalTokens = 0;
    for (final t in _activeChat!.fullHistory) {
      totalTokens += await _activeChat!.session.sizeInTokens(t.text);
      if (t.hasImage) {
        totalTokens += 256;
      }
    }
    return totalTokens + _tokenOverheadBuffer;
  }

  Future<void> _maybeCompressHistory({
    String? pendingPrompt,
    int pendingImageTokens = 0,
  }) async {
    if (_activeChat == null) return;

    int tokens = await _estimateTokens();
    if (pendingPrompt != null && pendingPrompt.isNotEmpty) {
      tokens += await _activeChat!.session.sizeInTokens(pendingPrompt);
    }
    tokens += pendingImageTokens;

    if (tokens < _compressionThreshold) return;

    final rawHistory = _activeChat!.fullHistory
        .map((m) => '${m.isUser ? "User" : "Assistant"}: ${m.text}')
        .join('\n\n');
    final historyText = rawHistory.length > _maxHistorySnapshotChars
        ? '[…earlier messages omitted…]\n\n'
            '${rawHistory.substring(rawHistory.length - _maxHistorySnapshotChars)}'
        : rawHistory;

    await _activeChat!.clearHistory();

    await _activeChat!.addQueryChunk(
      Message.text(
        text: 'Summarize the following conversation in under 80 words. '
            'Preserve all key facts, names, terms, and context. '
            'Reply with ONLY the summary, no preamble:\n\n$historyText',
        isUser: true,
      ),
    );
    final resp = await _activeChat!.generateChatResponse();

    final summaryToken = (resp is TextResponse) ? resp.token : '';
    if (summaryToken.isEmpty) {
      await _activeChat!.clearHistory();
      return;
    }
    final summary = summaryToken.trim();

    await _activeChat!.clearHistory(
      replayHistory: [
        Message.text(
          text: '[Conversation summary – treat as established prior context, '
              'do not reference this message directly]\n$summary',
          isUser: false,
        ),
      ],
    );
  }

  Future<String> _gemmaResponse({
    required String prompt,
    Uint8List? image,
    Future<InferenceChat> Function()? chatFactory,
  }) async {
    try {
      final needsImage = image != null;

      if (needsImage && !_supportImage) {
        debugPrint('[GemmaModel] Image requested but model lacks image support. Recreating model.');
        _supportImage = true;
        try { await _activeChat?.session.close(); } catch (_) {}
        _activeChat = null;
        try { _activeModel?.close(); } catch (_) {}
        _activeModel = null;
      }

      await model;
      final c = _activeChat != null ? _activeChat! : await chat;
      try {
        if (image == null) {
          await c.addQueryChunk(Message.text(text: prompt, isUser: true));
        } else {
          await c.addQueryChunk(
              Message.withImage(text: prompt, isUser: true, imageBytes: image));
        }
      } catch (e) {
        debugPrint('[GemmaModel] addQueryChunk failed ($e). Reinitializing and retrying.');
        await _reinitializeInternal();
        await model;
        final freshChat = chatFactory != null ? await chatFactory() : await chat;
        if (image == null) {
          await freshChat.addQueryChunk(Message.text(text: prompt, isUser: true));
        } else {
          await freshChat.addQueryChunk(
              Message.withImage(text: prompt, isUser: true, imageBytes: image));
        }
        final retry = await freshChat.generateChatResponse();
        final retryToken = (retry is TextResponse) ? retry.token : '';
        if (retryToken.isEmpty) {
          return "error: Model could not generate a response. Please try a shorter prompt.";
        }
        return retryToken;
      }

      final raw = await c.generateChatResponse();
      final token = (raw is TextResponse) ? raw.token : '';

      if (token.isEmpty) {
        await _reinitializeInternal();
        await model;
        final freshChat = chatFactory != null ? await chatFactory() : await chat;
        if (image == null) {
          await freshChat.addQueryChunk(Message.text(text: prompt, isUser: true));
        } else {
          await freshChat.addQueryChunk(
              Message.withImage(text: prompt, isUser: true, imageBytes: image));
        }
        final retry = await freshChat.generateChatResponse();
        final retryToken = (retry is TextResponse) ? retry.token : '';
        if (retryToken.isEmpty) {
          return "error: Model could not generate a response. Please try a shorter prompt.";
        }
        return retryToken;
      }
      return token;
    } catch (e) {
      try {
        await _reinitializeInternal();
      } catch (_) {
        _activeChat = null;
        _activeModel = null;
        _supportImage = false;
      }
      return "error: $e";
    }
  }


  @override
  Future<String> translateResponse(
    LanguageChoose? language,
    LanguageChoose convLanguage,
    String translation, {
    String? translationMemory,
  }) =>
      _enqueue(() async {
        final builder = TranslationPromptBuilder(
          textToTranslate: translation,
          convLanguage: convLanguage.label,
          language: language?.label,
          translationMemory: translationMemory,
        );
        final builtPrompt = builder.build();
        await _maybeCompressHistory(pendingPrompt: builtPrompt);
        final raw = await _gemmaResponse(prompt: builtPrompt);
        if (raw.startsWith('error:')) return raw;
        return _parseTranslation(raw);
      });

  static String _parseTranslation(String raw) {
    if (raw.trim().isEmpty) return raw;
    var text = raw.trim();

    final prefixPatterns = [
      RegExp(r'^translation\s*:\s*', caseSensitive: false),
      RegExp(r'^translated\s*:\s*', caseSensitive: false),
      RegExp(r'^output\s*:\s*', caseSensitive: false),
      RegExp(r'^result\s*:\s*', caseSensitive: false),
      RegExp(r"^here'?s?\s+(the\s+)?translation\s*:\s*", caseSensitive: false),
      RegExp(r'^the\s+\w+\s+(translation|equivalent)\s+(is\s*:?|:)\s*',
          caseSensitive: false),
    ];
    for (final p in prefixPatterns) {
      text = text.replaceFirst(p, '');
    }
    text = text.trim();

    final lines = text.split('\n');
    if (lines.length > 1) {
      final first = lines.first.trim();
      if (first.endsWith(':') ||
          RegExp(r'^(translation|here|output|result)',
                  caseSensitive: false)
              .hasMatch(first)) {
        text = lines.skip(1).join('\n').trim();
      }
    }

    final cleanLines = <String>[];
    for (final line in text.split('\n')) {
      final lower = line.trim().toLowerCase();
      if (lower.startsWith('note:') ||
          lower.startsWith('*note') ||
          lower.startsWith('(note') ||
          lower.startsWith('[note') ||
          lower.startsWith('explanation:') ||
          lower.startsWith('comment:') ||
          lower.startsWith('remark:')) {
        break;
      }
      cleanLines.add(line);
    }
    text = cleanLines.join('\n').trim();

    if (text.length >= 2) {
      if ((text.startsWith('"') && text.endsWith('"')) ||
          (text.startsWith("'") && text.endsWith("'")) ||
          (text.startsWith('\u300c') && text.endsWith('\u300d')) ||
          (text.startsWith('\u300e') && text.endsWith('\u300f'))) {
        text = text.substring(1, text.length - 1).trim();
      }
    }

    return text.isEmpty ? raw.trim() : text;
  }

  @override
  Future<String> updateTranslationMemory({
    required String text,
    required String convText,
    required String convLanguage,
    String? language,
    String? existingMemory,
  }) =>
      _enqueue(() async {
        final builder = TranslationMemoryBuilder(
          text: text,
          convText: convText,
          convLanguage: convLanguage,
          language: language,
          existingMemory: existingMemory,
        );
        final builtPrompt = builder.build();
        await _maybeCompressHistory(pendingPrompt: builtPrompt);
        return await _gemmaResponse(prompt: builtPrompt);
      });


  @override
  Future<String> chatbotResponse(String prompt, Uint8List? image) =>
      _enqueue(() async {
        await _maybeCompressHistory(
          pendingPrompt: prompt,
          pendingImageTokens: image != null ? 256 : 0,
        );
        final isFirstTurn =
            _activeChat == null || _activeChat!.fullHistory.isEmpty;
        final effectivePrompt = isFirstTurn
            ? ChatbotPromptBuilder(userMessage: prompt).build()
            : prompt;
        final response = await _gemmaResponse(prompt: effectivePrompt, image: image);
        await _maybeCompressHistory();
        return response;
      });

  @override
  Future<List<VocabEntry>> learningVocabResponse(
          String topic, LanguageChoose language, LanguageChoose convLanguage) =>
      _enqueue(() async {
        await _resetChatInternal();

        final first = LearningVocabFirstPromptBuilder(
          topic: topic,
          language: language.label,
        );
        final firstRaw = await _gemmaResponse(prompt: first.build());

        final firstItems = _parseFirstItems(firstRaw);
        final firstLines = firstItems
            .map((e) => '${e.type == EntryType.grammar ? 'G' : 'V'}|${e.word}')
            .toList();

        final next = LearningVocabNextPromptBuilder(
          convLanguage: convLanguage.label,
          language: language.label,
          firstLines: firstLines,
        );
        final nextRaw = await _gemmaResponse(prompt: next.build());

        final entries = VocabEntry.parseModelResponse(nextRaw);
        return _applyFirstWords(entries, firstItems);
      });

  static List<({EntryType type, String word})> _parseFirstItems(String raw) {
    final result = <({EntryType type, String word})>[];
    for (final rawLine in raw.split('\n')) {
      final line = rawLine
          .trim()
          .replaceFirst(RegExp(r'^\d+[.)]\s*'), '')
          .replaceFirst(RegExp(r'^[-*•]\s*'), '');
      if (!line.contains('|')) continue;
      final parts = line.split('|');
      if (parts.length < 2) continue;
      final prefix = parts[0].trim().toUpperCase();
      final word = parts[1].trim();
      if (word.isEmpty) continue;
      if (prefix == 'G') {
        result.add((type: EntryType.grammar, word: word));
      } else {
        result.add((type: EntryType.vocab, word: word));
      }
      if (result.length >= 10) break;
    }
    return result;
  }

  static List<VocabEntry> _applyFirstWords(
    List<VocabEntry> entries,
    List<({EntryType type, String word})> firstItems,
  ) {
    return List.generate(entries.length, (i) {
      final entry = entries[i];
      if (i >= firstItems.length) return entry;
      final s1 = firstItems[i];
      return VocabEntry(
        text: s1.word,
        convText: entry.convText,
        lang: entry.lang,
        convLang: entry.convLang,
        example: entry.example,
        entryType: s1.type,
      );
    });
  }


  @override
  Future<String> generateQuizQuestion({
    required String correctWord,
    required String correctTranslation,
    required List<String> distractorOptions,
    required String language,
    required String convLanguage,
    QuizQuestionType type = QuizQuestionType.targetWord,
  }) =>
      _enqueue(() async {
        await _resetChatInternal();
        await model;

        Future<InferenceChat> quizChatFactory() async {
          _activeChat = await _activeModel!.createChat(
            temperature: 0.7,
            topK: 40,
            topP: 0.80,
            supportImage: false,
          );
          return _activeChat!;
        }

        await quizChatFactory();

        final builder = QuizQuestionPromptBuilder(
          correctWord: correctWord,
          correctTranslation: correctTranslation,
          distractorOptions: distractorOptions,
          language: language,
          convLanguage: convLanguage,
          type: type,
        );
        final raw = await _gemmaResponse(
          prompt: builder.build(),
          chatFactory: quizChatFactory,
        );
        await _resetChatInternal();
        return _parseQuizQuestion(raw, correctWord, convLanguage);
      });

  String _parseQuizQuestion(String raw, String correctWord, String convLanguage) {
    const skipPrefixes = [
      'you are', 'correct', 'wrong', 'output', 'choose', 'write',
      'generate', 'here', 'the question', 'format', 'example',
    ];
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (skipPrefixes.any((p) => lower.startsWith(p))) continue;
      if (line.endsWith('?') || line.contains('___') || line.length > 15) {
        return line;
      }
    }
    return 'What is the $convLanguage word for "$correctWord"?';
  }

  @visibleForTesting
  static String parseTranslationForTest(String raw) => _parseTranslation(raw);

  @visibleForTesting
  static List<({EntryType type, String word})> parseFirstItemsForTest(String raw) =>
      _parseFirstItems(raw);

  @visibleForTesting
  static List<VocabEntry> applyFirstWordsForTest(
    List<VocabEntry> entries,
    List<({EntryType type, String word})> firstItems,
  ) =>
      _applyFirstWords(entries, firstItems);

  @visibleForTesting
  String parseQuizQuestionForTest(String raw, String correctWord, String convLanguage) =>
      _parseQuizQuestion(raw, correctWord, convLanguage);
}
