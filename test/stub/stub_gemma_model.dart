import 'dart:typed_data';
import 'package:SLMTranslator/model/gemma_model.dart';
import 'package:SLMTranslator/types/language_choose.dart';
import 'package:SLMTranslator/types/quiz_question_type.dart';
import 'package:SLMTranslator/learning/vocab_entry.dart';

class StubGemmaModel implements AbstractGemmaModel {
  String? overrideChatbotResponse;
  String? overrideTranslateResponse;
  String? overrideTranslationMemoryResponse;
  Exception? throwOnNextCall;
  final List<String> receivedChatPrompts = [];
  final List<({String text, String lang})> receivedTranslations = [];
  final List<String?> receivedTranslationMemories = [];
  final List<({
    String text,
    String convText,
    String convLanguage,
    String? language,
    String? existingMemory,
  })> receivedTranslationMemoryUpdates = [];

  int resetChatCallCount = 0;

  final List<Map<String, String>> _history = [];


  @override
  Future<String> chatbotResponse(String prompt, Uint8List? image) async {
    _checkThrow();
    receivedChatPrompts.add(prompt);
    final reply = overrideChatbotResponse ?? '[stub] response to: $prompt';
    _history.add({'role': 'user', 'text': prompt});
    _history.add({'role': 'assistant', 'text': reply});
    return reply;
  }


  @override
  Future<String> translateResponse(
    LanguageChoose? language,
    LanguageChoose convLanguage,
    String translation, {
    String? translationMemory,
  }) async {
    _checkThrow();
    receivedTranslations.add((text: translation, lang: convLanguage.name));
    receivedTranslationMemories.add(translationMemory);
    return overrideTranslateResponse ??
        '[stub ${convLanguage.name}] $translation';
  }

  @override
  Future<String> updateTranslationMemory({
    required String text,
    required String convText,
    required String convLanguage,
    String? language,
    String? existingMemory,
  }) async {
    _checkThrow();
    receivedTranslationMemoryUpdates.add((
      text: text,
      convText: convText,
      convLanguage: convLanguage,
      language: language,
      existingMemory: existingMemory,
    ));
    return overrideTranslationMemoryResponse ??
        [
          if (existingMemory != null && existingMemory.trim().isNotEmpty)
            existingMemory.trim(),
          'Glossary:',
          '- $text → $convText',
        ].join('\n');
  }



  @override
  Future<List<VocabEntry>> learningVocabResponse(
    String topic,
    LanguageChoose language,
    LanguageChoose convLanguage,
  ) async {
    _checkThrow();
    return [
      VocabEntry(
        text: 'stub_word_1',
        convText: '[stub 1] $topic',
        lang: language.name,
        convLang: convLanguage.name,
        example: 'Example sentence for stub_word_1.',
        entryType: EntryType.vocab,
      ),
      VocabEntry(
        text: 'stub_word_2',
        convText: '[stub 2] $topic',
        lang: language.name,
        convLang: convLanguage.name,
        entryType: EntryType.vocab,
      ),
      VocabEntry(
        text: 'stub_grammar_1',
        convText: '[stub grammar] $topic',
        lang: language.name,
        convLang: convLanguage.name,
        example: 'Grammar example sentence.',
        entryType: EntryType.grammar,
      ),
    ];
  }


  @override
  Future<String> generateQuizQuestion({
    required String correctWord,
    required String correctTranslation,
    required List<String> distractorOptions,
    required String language,
    required String convLanguage,
    QuizQuestionType type = QuizQuestionType.targetWord,
  }) async {
    _checkThrow();
    switch (type) {
      case QuizQuestionType.targetWord:
        return 'What is the $convLanguage word for "$correctWord"?';
      case QuizQuestionType.sourceWord:
        return 'Which $language word means "$correctTranslation"?';
      case QuizQuestionType.travelConversation:
        return 'You are travelling. Which $convLanguage word means "$correctWord"?';
    }
  }

  @override
  Future<void> resetChat() async {
    _history.clear();
    resetChatCallCount++;
  }

  int reinitializeCallCount = 0;

  @override
  Future<void> reinitialize() async {
    _history.clear();
    reinitializeCallCount++;
  }

  @override
  Future<void> dispose() async {
  }

  List<Map<String, String>> get chatHistory => List.unmodifiable(_history);

  void _checkThrow() {
    if (throwOnNextCall != null) {
      final ex = throwOnNextCall!;
      throwOnNextCall = null;
      throw ex;
    }
  }
}

