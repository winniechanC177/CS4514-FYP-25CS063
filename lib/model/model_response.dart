import 'dart:async';
import 'dart:typed_data';
import 'gemma_model.dart';
import 'tts_model.dart';
import 'stt_model.dart';
import 'package:flutter/foundation.dart';
import '../types/language_choose.dart';
import '../types/quiz_question_type.dart';
import '../learning/vocab_entry.dart';

export 'gemma_model.dart';
export 'tts_model.dart';
export 'stt_model.dart';
export '../types/quiz_question_type.dart';

class TranslationMemoryEntry {
  final String text;
  final String convText;
  final String? language;
  final String convLanguage;

  const TranslationMemoryEntry({
    required this.text,
    required this.convText,
    this.language,
    required this.convLanguage,
  });
}

class ModelResponse {
  static const String translationContextKey = 'translation';
  static ModelResponse? _sharedInstance;

  final AbstractGemmaModel _gemmaModel;
  final AbstractTTSModel _ttsModel;
  final AbstractSTTModel _sttModel;
  final Map<String, String> _translationMemoryByContext = {};

  Future<void> _memoryUpdateQueue = Future.value();
  String _activeContextKey = translationContextKey;

  factory ModelResponse({
    AbstractGemmaModel? gemmaModel,
    AbstractTTSModel? ttsModel,
    AbstractSTTModel? sttModel,
  }) {
    final hasInjectedModel =
        gemmaModel != null || ttsModel != null || sttModel != null;
    if (hasInjectedModel) {
      return ModelResponse._internal(
        gemmaModel: gemmaModel,
        ttsModel: ttsModel,
        sttModel: sttModel,
      );
    }
    return _sharedInstance ??= ModelResponse._internal();
  }

  ModelResponse._internal({
    AbstractGemmaModel? gemmaModel,
    AbstractTTSModel? ttsModel,
    AbstractSTTModel? sttModel,
  })  : _gemmaModel = gemmaModel ?? GemmaModel(),
        _ttsModel = ttsModel ?? TTSModel(),
        _sttModel = sttModel ?? STTModel();

  String get activeContextKey => _activeContextKey;

  String? get translationMemory => _resolveTranslationMemory(_activeContextKey);

  Future<String?> latestTranslationMemory({String? contextKey}) async {
    await _memoryUpdateQueue;
    return _resolveTranslationMemory(contextKey ?? _activeContextKey);
  }

  String? _resolveTranslationMemory(String contextKey) {
    final direct = _translationMemoryByContext[contextKey]?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final shared = _translationMemoryByContext[translationContextKey]?.trim();
    if (shared != null && shared.isNotEmpty) return shared;
    return null;
  }

  Future<void> switchContext(String contextKey) async {
    if (_activeContextKey == contextKey) return;
    _activeContextKey = contextKey;
    await _gemmaModel.resetChat();
  }

  Future<void> clearContext(String contextKey, {bool resetActiveChat = false}) async {
    _translationMemoryByContext.remove(contextKey);
    if (resetActiveChat && _activeContextKey == contextKey) {
      await _gemmaModel.resetChat();
    }
  }

  Future<void> importTranslationMemoryEntries(
    List<TranslationMemoryEntry> entries, {
    bool replaceExisting = false,
    String contextKey = translationContextKey,
  }) async {
    final normalizedEntries = entries
        .where((entry) =>
            entry.text.trim().isNotEmpty && entry.convText.trim().isNotEmpty)
        .toList();
    if (normalizedEntries.isEmpty) {
      if (replaceExisting) {
        _translationMemoryByContext.remove(contextKey);
      }
      return;
    }

    final existing = replaceExisting ? null : _translationMemoryByContext[contextKey];
    final merged = _composeTranslationMemory(normalizedEntries, existingMemory: existing);
    if (merged.isEmpty) return;

    _translationMemoryByContext[contextKey] = merged;
  }

  String _composeTranslationMemory(
    List<TranslationMemoryEntry> entries, {
    String? existingMemory,
  }) {
    final glossary = <String, String>{};
    final names = <String>{};
    final styleNotes = <String>{};
    String? latestTargetLanguage;

    void rememberPair(String source, String target) {
      final key = source.toLowerCase();
      glossary.remove(key);
      glossary[key] = '$source → $target';
      if (RegExp(r'^[A-Z][\p{L}\-\s]+$', unicode: true).hasMatch(source)) {
        names.add('$source → $target');
      }
    }

    for (final entry in entries) {
      final source = entry.text.trim();
      final target = entry.convText.trim();
      if (source.isEmpty || target.isEmpty) continue;
      latestTargetLanguage = entry.convLanguage.trim().isEmpty
          ? latestTargetLanguage
          : entry.convLanguage.trim();
      rememberPair(source, target);
      final lowerTarget = target.toLowerCase();
      if (target.endsWith('!')) {
        styleNotes.add('Keep emphatic tone when appropriate.');
      }
      if (lowerTarget.contains('please') || lowerTarget.contains('thank')) {
        styleNotes.add('Keep a polite tone.');
      }
    }

    final buffer = StringBuffer();
    final trimmedExisting = existingMemory?.trim();
    if (trimmedExisting != null && trimmedExisting.isNotEmpty) {
      buffer.writeln(trimmedExisting);
      buffer.writeln();
    }
    if (latestTargetLanguage != null && latestTargetLanguage.isNotEmpty) {
      buffer.writeln('Target language: $latestTargetLanguage');
    }
    if (glossary.isNotEmpty) {
      buffer.writeln('Glossary:');
      for (final line in glossary.values.toList().reversed.take(12).toList().reversed) {
        buffer.writeln('- $line');
      }
    }
    if (names.isNotEmpty) {
      buffer.writeln('Names:');
      for (final line in names.take(6)) {
        buffer.writeln('- $line');
      }
    }
    if (styleNotes.isNotEmpty) {
      buffer.writeln('Tone/style rules:');
      for (final line in styleNotes.take(4)) {
        buffer.writeln('- $line');
      }
    }
    return buffer.toString().trim();
  }

  void _scheduleTranslationMemoryUpdate({
    required String contextKey,
    required String text,
    required String convText,
    required String convLanguage,
    String? language,
  }) {
    _memoryUpdateQueue = _memoryUpdateQueue.then((_) async {
      try {
        final updated = await _gemmaModel.updateTranslationMemory(
          text: text,
          convText: convText,
          convLanguage: convLanguage,
          language: language,
          existingMemory: _resolveTranslationMemory(contextKey),
        );
        final trimmed = updated.trim();
        if (trimmed.isEmpty || trimmed.startsWith('error:')) return;
        _translationMemoryByContext[contextKey] = trimmed;
      } catch (_) {}
    });
  }

  String _prepareChatbotPrompt(String prompt) {
    final memory = _resolveTranslationMemory(_activeContextKey);
    if (memory == null || memory.isEmpty) return prompt;
    return 'Reference memory for glossary, names, and tone:\n'
        '$memory\n\n'
        'Use this only when relevant to the user request below.\n\n'
        '$prompt';
  }

  Future<String> chatbotResponse(String prompt, Uint8List? image) async {
    await _memoryUpdateQueue;
    return _gemmaModel.chatbotResponse(_prepareChatbotPrompt(prompt), image);
  }

  Future<String> translateResponse(
      LanguageChoose? language,
      LanguageChoose convLanguage,
      String translation, {
        String? translationMemory,
      }) async {
    await _memoryUpdateQueue;
    final effectiveMemory = translationMemory ?? _resolveTranslationMemory(_activeContextKey);
    final response = await _gemmaModel.translateResponse(
      language,
      convLanguage,
      translation,
      translationMemory: effectiveMemory,
    );

    final trimmed = response.trim();
    if (trimmed.isNotEmpty && !trimmed.startsWith('error:')) {
      _scheduleTranslationMemoryUpdate(
        contextKey: _activeContextKey,
        text: translation,
        convText: trimmed,
        convLanguage: convLanguage.name,
        language: language?.name,
      );
    }
    return response;
  }

  Future<List<VocabEntry>> learningVocabResponse(
      String topic, LanguageChoose language, LanguageChoose convLanguage) =>
      _gemmaModel.learningVocabResponse(topic, language, convLanguage);


  Future<String> generateQuizQuestion({
    required String correctWord,
    required String correctTranslation,
    required List<String> distractorOptions,
    required String language,
    required String convLanguage,
    QuizQuestionType type = QuizQuestionType.targetWord,
  }) =>
      _gemmaModel.generateQuizQuestion(
        correctWord: correctWord,
        correctTranslation: correctTranslation,
        distractorOptions: distractorOptions,
        language: language,
        convLanguage: convLanguage,
        type: type,
      );

  Future<void> resetChat() => _gemmaModel.resetChat();

  Future<void> safeResetChat() async {
    try {
      await _gemmaModel.resetChat();
    } catch (_) {}
  }

  Future<Int16List> pronunciationResponse(
      String word, LanguageChoose language) async {
    final stopwatch = Stopwatch()..start();
    try {
      final audio = await _ttsModel.pronunciationResponse(word, language);
      if (kDebugMode) {
        final wordPreview = word.replaceAll('\n', ' ').trim();
        debugPrint(
          '[ModelResponse][TTS] pronunciationResponse'
          ' word="${wordPreview.length > 80 ? "${wordPreview.substring(0, 80)}..." : wordPreview}"'
          ' generatedSamples=${audio.length}'
          ' totalMs=${stopwatch.elapsedMilliseconds}ms',
        );
      }
      return audio;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ModelResponse][TTS] ERROR after ${stopwatch.elapsedMilliseconds}ms: $e');
        debugPrint('$st');
      }
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  static Future<void> initTtsOnce() => TTSModel.initTtsOnce();

  Future<String?> transcribeAudio(String audioPath,
      {LanguageChoose? language}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final text = await _sttModel.transcribeAudio(audioPath, language: language);
      if (kDebugMode) {
        debugPrint(
          '[ModelResponse][STT] transcribeAudio'
          ' path="$audioPath"'
          ' totalMs=${stopwatch.elapsedMilliseconds}ms'
          ' resultPresent=${text != null}'
          ' textLength=${text?.length ?? 0}',
        );
      }
      return text;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ModelResponse][STT] ERROR after ${stopwatch.elapsedMilliseconds}ms path="$audioPath": $e');
        debugPrint('$st');
      }
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  Future<void> initWhisper({dynamic model}) =>
      _sttModel.initWhisper(model: model);

  Future<void> dispose() async {
    await _memoryUpdateQueue;
    await _gemmaModel.dispose();
  }
}
